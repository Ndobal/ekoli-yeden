import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/message.dart';
import '../../repositories/message_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';
import 'person_panel.dart';

/// MESSAGES.
///
/// ---------------------------------------------------------------------------
/// ONE SCREEN, THREE SHAPES
/// ---------------------------------------------------------------------------
///
/// The same widget serves a phone, a laptop and a desktop, because they are not
/// three products:
///
///   **Wide (1100+)** — three panes: the conversations, the thread, and who you
///   are talking to. Nothing is hidden behind navigation.
///   **Medium (760–1100)** — two panes: conversations and thread. The person
///   panel folds into the thread header, which is where the same information
///   goes when there is no room beside it.
///   **Phone (under 760)** — one pane. `/messages` is the list, `/messages/:id`
///   is the thread with a back arrow. Two real URLs rather than one screen with
///   a hidden state, so the browser's back button does what it looks like it
///   does and a conversation can be linked to.
///
/// ---------------------------------------------------------------------------
/// THE SEARCH BOX IS THE FEATURE
/// ---------------------------------------------------------------------------
///
/// One field. It filters the conversations you already have AND finds members
/// you have never spoken to, in the same list, because "message Riya" is one
/// intention and should not require deciding first whether Riya is somebody you
/// have written to before.
///
/// **A person found this way arrives with a name, a handle and a headline, and
/// no way to contact them anywhere else.** That is the whole design: reaching
/// somebody and being handed their phone number are different things, and this
/// module gives you the first without the second. Asking for the second is a
/// separate, explicit act — the "Ask for their details" button in the person
/// panel — and the answer belongs to them.
class MessagesPage extends StatefulWidget {
  const MessagesPage({this.conversationId, super.key});

  /// Set when a particular conversation is open. On a phone this decides which
  /// of the two panes is shown at all.
  final String? conversationId;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _search = TextEditingController();

  List<Conversation> _conversations = const <Conversation>[];
  List<MessagePerson> _people = const <MessagePerson>[];
  String _query = '';
  bool _loading = true;
  bool _searching = false;
  String? _error;

  Timer? _debounce;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadConversations();

    // Light polling rather than sockets. A community archive does not need
    // real-time delivery to be useful, and a page that quietly refreshes every
    // twenty seconds feels live enough while costing one request.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _query.isEmpty) _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      final PaginatedResult<Conversation> result = await context
          .read<MessageRepository>()
          .conversations(perPage: 100);
      if (mounted) {
        setState(() {
          _conversations = result.items;
          _error = null;
          _loading = false;
        });
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  /// Searching people is debounced; filtering conversations is not.
  ///
  /// The conversations are already here, so filtering them is instant and
  /// should feel it. Finding members is a request, and firing one per keystroke
  /// would be rude to a phone on a slow connection.
  void _onQueryChanged(String value) {
    setState(() => _query = value.trim());
    _debounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _people = const <MessagePerson>[];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final List<MessagePerson> people = await context
            .read<MessageRepository>()
            .findPeople(value.trim());
        if (mounted) {
          setState(() {
            _people = people;
            _searching = false;
          });
        }
      } on AppException {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  /// Opens the conversation with somebody and goes to it.
  ///
  /// The server finds an existing thread rather than making a second one, so
  /// this is safe to press twice.
  Future<void> _messagePerson(MessagePerson person) async {
    try {
      final Conversation conversation = await context.read<MessageRepository>().open(
        userId: person.userId.isEmpty ? null : person.userId,
        handle: person.handle,
      );
      if (!mounted) return;

      _search.clear();
      setState(() {
        _query = '';
        _people = const <MessagePerson>[];
      });

      await _loadConversations(silent: true);
      if (mounted) context.go(AppRoutes.conversation(conversation.id));
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  List<Conversation> get _filtered {
    if (_query.isEmpty) return _conversations;
    final String needle = _query.toLowerCase();
    return _conversations
        .where(
          (Conversation conversation) =>
              conversation.title.toLowerCase().contains(needle) ||
              (conversation.lastMessageText ?? '').toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    if (!auth.isSignedIn) return const _SignedOut();

    final double width = context.screenWidth;
    final bool wide = width >= 1100;
    final bool split = width >= 760;
    final bool showThread = widget.conversationId != null;

    final Widget list = _ConversationList(
      conversations: _filtered,
      people: _people,
      query: _query,
      loading: _loading,
      searching: _searching,
      error: _error,
      search: _search,
      selectedId: widget.conversationId,
      onQueryChanged: _onQueryChanged,
      onMessagePerson: _messagePerson,
      onRetry: _loadConversations,
    );

    final Widget thread = widget.conversationId == null
        ? const _NothingSelected()
        : ConversationView(
            key: ValueKey<String>(widget.conversationId!),
            conversationId: widget.conversationId!,
            showBack: !split,
            showPersonPanel: !wide,
            onSent: () => _loadConversations(silent: true),
          );

    return AppScaffold(
      currentPath: AppRoutes.messages,
      seo: const SeoMetadata(
        title: 'Messages',
        description: 'Write to anybody in the community without needing their phone number.',
        noIndex: true,
      ),
      child: PageSection(
        child: SizedBox(
          // Tall enough to work as an application pane, and bounded so the
          // thread scrolls inside itself instead of stretching the page.
          height: (context.screenHeight - 260).clamp(460.0, 900.0),
          child: split
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(width: wide ? 320 : 300, child: list),
                    const Gap.hLg(),
                    Expanded(child: thread),
                    if (wide && widget.conversationId != null) ...<Widget>[
                      const Gap.hLg(),
                      SizedBox(
                        width: 280,
                        child: PersonPanel(conversationId: widget.conversationId!),
                      ),
                    ],
                  ],
                )
              // One pane on a phone: the list, or the conversation.
              : (showThread ? thread : list),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The conversations, and the people you could write to
// ---------------------------------------------------------------------------

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.people,
    required this.query,
    required this.loading,
    required this.searching,
    required this.error,
    required this.search,
    required this.selectedId,
    required this.onQueryChanged,
    required this.onMessagePerson,
    required this.onRetry,
  });

  final List<Conversation> conversations;
  final List<MessagePerson> people;
  final String query;
  final bool loading;
  final bool searching;
  final String? error;
  final TextEditingController search;
  final String? selectedId;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function(MessagePerson person) onMessagePerson;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('Messages', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Requests for your details',
                      icon: const Icon(Icons.key_outlined, size: 20),
                      onPressed: () => context.go(AppRoutes.accountRequests),
                    ),
                  ],
                ),
                const Gap.md(),
                TextField(
                  controller: search,
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    // One field for both jobs. "Message Riya" is one intention
                    // and should not require deciding first whether Riya is
                    // somebody you have written to before.
                    hintText: 'Search people, or your chats',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              search.clear();
                              onQueryChanged('');
                            },
                          ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? _ListError(message: error!, onRetry: onRetry)
                : ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      if (conversations.isEmpty && people.isEmpty && !searching)
                        _EmptyList(query: query),

                      if (conversations.isNotEmpty) ...<Widget>[
                        _SectionLabel(
                          label: query.isEmpty ? 'Your conversations' : 'In your conversations',
                        ),
                        ...conversations.map(
                          (Conversation conversation) => _ConversationRow(
                            conversation: conversation,
                            selected: conversation.id == selectedId,
                          ),
                        ),
                      ],

                      if (searching)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),

                      if (people.isNotEmpty) ...<Widget>[
                        const _SectionLabel(label: 'People you can write to'),
                        ...people.map(
                          (MessagePerson person) =>
                              _PersonRow(person: person, onMessage: onMessagePerson),
                        ),
                        const _SearchNote(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.selected});

  final Conversation conversation;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: () => context.go(AppRoutes.conversation(conversation.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              MemberAvatar(person: conversation.other, size: 44),
              const Gap.hMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            conversation.title,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: conversation.hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (conversation.lastMessageAt != null)
                          Text(
                            Formatters.relative(conversation.lastMessageAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const Gap.xs(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            conversation.isEmpty
                                ? 'Say hello'
                                : '${conversation.lastMessageIsMine ? 'You: ' : ''}'
                                      '${conversation.lastMessageText ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: conversation.hasUnread
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                              fontStyle: conversation.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (conversation.isMuted)
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        if (conversation.hasUnread) ...<Widget>[
                          const Gap.hSm(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 1,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: AppRadius.pillAll,
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Somebody found by name, who can be written to in one press.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onMessage});

  final MessagePerson person;
  final Future<void> Function(MessagePerson person) onMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      leading: MemberAvatar(person: person, size: 40),
      title: Text(person.name, style: theme.textTheme.titleSmall),
      subtitle: Text(
        <String?>[
          person.headline,
          person.from,
        ].whereType<String>().join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: person.acceptsMessages
          ? IconButton(
              tooltip: 'Write to ${person.name}',
              icon: const Icon(Icons.send_outlined, size: 18),
              onPressed: () => onMessage(person),
            )
          : Tooltip(
              message: 'Not receiving messages',
              child: Icon(
                Icons.do_not_disturb_on_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: person.acceptsMessages ? () => onMessage(person) : null,
    );
  }
}

/// Said under the search results, once, where somebody has just found a person
/// and is wondering what they are allowed to do with that.
class _SearchNote extends StatelessWidget {
  const _SearchNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const Gap.hSm(),
          Expanded(
            child: Text(
              'You can write to anybody here without their phone number. Nobody’s number or '
              'email is shown unless they have shared it with you.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const Gap.xl(),
          Icon(
            query.isEmpty ? Icons.forum_outlined : Icons.person_search_outlined,
            size: 36,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const Gap.lg(),
          Text(
            query.isEmpty ? 'No conversations yet' : 'Nobody by that name',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const Gap.sm(),
          Text(
            query.isEmpty
                ? 'Search for somebody’s name above and write to them. You do not need their '
                      'phone number.'
                : 'Try part of the name. Some members have chosen not to be findable.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const Gap.lg(),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const Gap.lg(),
              Text('Choose a conversation', style: theme.textTheme.titleMedium),
              const Gap.sm(),
              Text(
                'Or search for somebody’s name and write to them. Everybody in the community '
                'can be reached here, and nobody has to publish a phone number to be reachable.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentPath: AppRoutes.messages,
      seo: const SeoMetadata(title: 'Messages', noIndex: true),
      child: PageSection(
        reading: true,
        eyebrow: 'Yakoli',
        title: 'Sign in to see your messages',
        description:
            'Members can write to each other here without exchanging phone numbers. Your own '
            'number and email stay hidden unless you choose to share them.',
        child: Row(
          children: <Widget>[
            FilledButton(
              onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.messages)),
              child: const Text('Sign in'),
            ),
            const Gap.hLg(),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.join),
              child: const Text('Become a member'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One conversation
// ---------------------------------------------------------------------------

/// The thread: header, messages, composer.
class ConversationView extends StatefulWidget {
  const ConversationView({
    required this.conversationId,
    required this.onSent,
    this.showBack = false,
    this.showPersonPanel = false,
    super.key,
  });

  final String conversationId;
  final VoidCallback onSent;

  /// On a phone, the thread is its own screen and needs a way back.
  final bool showBack;

  /// Where there is no room for the person panel beside the thread, its
  /// contents fold into the header instead of disappearing.
  final bool showPersonPanel;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _composerFocus = FocusNode();

  ConversationThread? _thread;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _composerFocus.dispose();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      final ConversationThread thread = await context
          .read<MessageRepository>()
          .thread(widget.conversationId);
      if (!mounted) return;

      final bool grew = (_thread?.messages.length ?? 0) != thread.messages.length;
      setState(() {
        _thread = thread;
        _loading = false;
        _error = null;
      });

      // Only jump when something arrived. Scrolling somebody to the bottom
      // while they are reading back through the conversation is maddening.
      if (grew) _jumpToLatest();
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final String body = _composer.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await context.read<MessageRepository>().send(widget.conversationId, body);
      _composer.clear();
      await _load(silent: true);
      _jumpToLatest();
      widget.onSent();
      // Kept where it was, so a reply can follow immediately without reaching
      // for the mouse.
      _composerFocus.requestFocus();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _ThreadHeader(
            thread: _thread,
            showBack: widget.showBack,
            showDetails: widget.showPersonPanel,
            conversationId: widget.conversationId,
            onChanged: () => _load(silent: true),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : _MessageStream(thread: _thread, controller: _scroll),
          ),
          const Divider(height: 1),
          _Composer(
            controller: _composer,
            focusNode: _composerFocus,
            sending: _sending,
            blocked: _thread?.isBlocked ?? false,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.thread,
    required this.showBack,
    required this.showDetails,
    required this.conversationId,
    required this.onChanged,
  });

  final ConversationThread? thread;
  final bool showBack;
  final bool showDetails;
  final String conversationId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MessagePerson? person = thread?.with_;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'All conversations',
              onPressed: () => context.go(AppRoutes.messages),
            ),
          if (person != null) MemberAvatar(person: person, size: 40),
          const Gap.hMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  person?.name ?? 'Conversation',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (person?.headline != null)
                  Text(
                    person!.headline!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (showDetails && person != null)
            IconButton(
              tooltip: 'About ${person.name}',
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (BuildContext sheetContext) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: PersonPanel(conversationId: conversationId, embedded: true),
                ),
              ),
            ),
          _ThreadMenu(
            conversationId: conversationId,
            muted: thread?.isMuted ?? false,
            blocked: thread?.isBlocked ?? false,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ThreadMenu extends StatelessWidget {
  const _ThreadMenu({
    required this.conversationId,
    required this.muted,
    required this.blocked,
    required this.onChanged,
  });

  final String conversationId;
  final bool muted;
  final bool blocked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'This conversation',
      icon: const Icon(Icons.more_horiz, size: 20),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'mute',
          child: Text(muted ? 'Turn notifications back on' : 'Mute this conversation'),
        ),
        const PopupMenuItem<String>(value: 'archive', child: Text('Put it away')),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'block',
          child: Text(blocked ? 'Allow messages again' : 'Stop messages from this person'),
        ),
      ],
      onSelected: (String action) async {
        final MessageRepository repository = context.read<MessageRepository>();
        try {
          switch (action) {
            case 'mute':
              await repository.update(conversationId, muted: !muted);
            case 'archive':
              await repository.update(conversationId, archived: true);
              if (context.mounted) context.go(AppRoutes.messages);
            case 'block':
              await repository.update(conversationId, blocked: !blocked);
          }
          onChanged();
        } on AppException catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
          }
        }
      },
    );
  }
}

/// The messages, oldest at the top, grouped by day.
class _MessageStream extends StatelessWidget {
  const _MessageStream({required this.thread, required this.controller});

  final ConversationThread? thread;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Message> messages = thread?.messages ?? const <Message>[];

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.waving_hand_outlined,
                size: 32,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const Gap.md(),
              Text(
                'Nothing here yet — say hello.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Day separators, so a conversation picked up after a week reads as one.
    final List<Widget> children = <Widget>[];
    String? lastDay;

    for (final Message message in messages) {
      final String day = _dayLabel(message.createdAt);
      if (day != lastDay) {
        children.add(_DaySeparator(label: day));
        lastDay = day;
      }
      children.add(_Bubble(message: message));
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      children: children,
    );
  }

  static String _dayLabel(String? iso) {
    final DateTime? at = DateTime.tryParse(iso ?? '')?.toLocal();
    if (at == null) return '';

    final DateTime now = DateTime.now();
    final int days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return Formatters.date(iso);
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
      ),
    );
  }
}

/// One message.
///
/// Mine on the right in the brand navy; theirs on the left on a light ground.
/// The asymmetric corner on the sender's side is what makes a long thread
/// scannable without reading any of it.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mine = message.isMine;

    if (message.isRemoved) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            'This message was removed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (context.screenWidth * 0.62).clamp(220.0, 520.0),
            ),
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.navy : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.lg),
                      topRight: const Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(mine ? AppRadius.lg : AppRadius.xs),
                      bottomRight: Radius.circular(mine ? AppRadius.xs : AppRadius.lg),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (message.mediaUrl != null && message.hasImage) ...<Widget>[
                        ClipRRect(
                          borderRadius: AppRadius.smAll,
                          child: Image.network(
                            message.mediaUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                        const Gap.sm(),
                      ],
                      SelectableText(
                        message.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mine ? Colors.white : theme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap.xs(),
                Text(
                  <String?>[
                    Formatters.relative(message.createdAt),
                    if (message.editedAt != null) 'edited',
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The composer.
///
/// Enter sends, Shift+Enter makes a new line — the convention every messaging
/// application uses, and the one people's hands already know.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.blocked,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool blocked;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (blocked) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Icon(Icons.block, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const Gap.hMd(),
            Expanded(
              child: Text(
                'You have stopped messages in this conversation. Turn it back on from the menu '
                'above to write again.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): onSend,
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 6,
                maxLength: 8000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message here',
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
          ),
          const Gap.hMd(),
          FilledButton(
            onPressed: sending ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            ),
            child: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[Text('Send'), Gap.hSm(), Icon(Icons.send, size: 16)],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A photograph if they have one, initials if they have not.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.person, this.size = 40, super.key});

  final MessagePerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (person.avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          person.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Initials(person: person, size: size),
        ),
      );
    }

    return _Initials(person: person, size: size);
  }

  static Color colourFor(String name) {
    const List<Color> palette = <Color>[
      AppColors.navy,
      AppColors.green,
      AppColors.goldDark,
      AppColors.navyLight,
      AppColors.greenDark,
    ];
    return palette[name.hashCode.abs() % palette.length];
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.person, required this.size});

  final MessagePerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color colour = MemberAvatar.colourFor(person.name);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        person.initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
