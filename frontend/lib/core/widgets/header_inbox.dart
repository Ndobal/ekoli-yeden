/// THE BELL AND THE CHAT ICON.
///
/// ---------------------------------------------------------------------------
/// WHY THEY ARE SEPARATE COUNTS
/// ---------------------------------------------------------------------------
///
/// A notification is something that happened to you; a message is somebody
/// waiting for an answer. Folding them into one number tells you that five
/// things need you and nothing about whether anybody is waiting — and the two
/// are answered in completely different ways.
///
/// So: 🔔 5 💬 3, each opening its own panel, each clearing its own count.
///
/// ---------------------------------------------------------------------------
/// AND WHY REPLYING HAPPENS HERE
/// ---------------------------------------------------------------------------
///
/// Somebody halfway through writing a news item who is asked a question should
/// be able to answer it without losing what they were doing. The panel sends
/// the reply itself and stays where it is; "Open Messages" is there for the
/// conversation that needs more than a line.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/member.dart';
import '../../models/message.dart';
import '../../repositories/member_repository.dart';
import '../../repositories/message_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';
import '../errors/app_exception.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// Both icons together, for a header.
class HeaderInbox extends StatelessWidget {
  const HeaderInbox({this.onDark = false, super.key});

  /// True in the navy member sidebar and the public header, where the icons
  /// sit on a dark ground.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthController>().isSignedIn) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _NotificationBell(onDark: onDark),
        const SizedBox(width: 2),
        _MessagesButton(onDark: onDark),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class _NotificationBell extends StatefulWidget {
  const _NotificationBell({required this.onDark});

  final bool onDark;

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || !context.read<AuthController>().isSignedIn) return;
    try {
      final PaginatedResult<MemberNotification> result =
          await context.read<MemberRepository>().notifications(perPage: 1, unreadOnly: true);
      if (mounted) setState(() => _unread = result.total);
    } catch (_) {
      // A badge is not worth an error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IconWithCount(
      icon: Icons.notifications_none,
      count: _unread,
      tooltip: 'Notifications',
      onDark: widget.onDark,
      onTap: () async {
        await showDialog<void>(
          context: context,
          builder: (BuildContext context) => const _Panel(child: _NotificationList()),
        );
        _refresh();
      },
    );
  }
}

class _NotificationList extends StatefulWidget {
  const _NotificationList();

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList> {
  late Future<PaginatedResult<MemberNotification>> _future = _load();

  Future<PaginatedResult<MemberNotification>> _load() =>
      context.read<MemberRepository>().notifications(perPage: 20);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Text('Notifications', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await context.read<MemberRepository>().markAllRead();
                  _reload();
                },
                child: const Text('Mark all as read'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: FutureBuilder<PaginatedResult<MemberNotification>>(
            future: _future,
            builder: (
              BuildContext context,
              AsyncSnapshot<PaginatedResult<MemberNotification>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final List<MemberNotification> items = snapshot.data?.items ?? const <MemberNotification>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    'Nothing yet. When somebody replies to you, approves you into a forum or '
                    'announces something, it appears here.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) =>
                    _NotificationRow(notification: items[index], onChanged: _reload),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onChanged});

  final MemberNotification notification;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = notification.isUnread;

    return InkWell(
      onTap: () async {
        final MemberRepository repository = context.read<MemberRepository>();
        final String? path = notification.linkPath;
        if (unread) await repository.markRead(notification.id);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        if (path != null && path.isNotEmpty) context.go(path);
      },
      child: Container(
        color: unread ? AppColors.navy.withValues(alpha: 0.04) : null,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The unread dot, which is the whole reason somebody scans this
            // list rather than reading it.
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unread ? AppColors.navy : theme.colorScheme.outlineVariant,
              ),
            ),
            const Gap.hMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    notification.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if ((notification.body ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      notification.body!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    Formatters.relative(notification.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

class _MessagesButton extends StatefulWidget {
  const _MessagesButton({required this.onDark});

  final bool onDark;

  @override
  State<_MessagesButton> createState() => _MessagesButtonState();
}

class _MessagesButtonState extends State<_MessagesButton> {
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || !context.read<AuthController>().isSignedIn) return;
    try {
      final int unread = await context.read<MessageRepository>().unread();
      if (mounted) setState(() => _unread = unread);
    } catch (_) {
      // A badge is not worth an error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IconWithCount(
      icon: Icons.chat_bubble_outline,
      count: _unread,
      tooltip: 'Messages',
      onDark: widget.onDark,
      onTap: () async {
        await showDialog<void>(
          context: context,
          builder: (BuildContext context) => const _Panel(child: _ConversationList()),
        );
        _refresh();
      },
    );
  }
}

class _ConversationList extends StatefulWidget {
  const _ConversationList();

  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  late Future<PaginatedResult<Conversation>> _future = _load();
  String? _replyingTo;

  Future<PaginatedResult<Conversation>> _load() =>
      context.read<MessageRepository>().conversations(perPage: 12);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Text('Messages', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.messages);
                },
                child: const Text('Open Messages'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: FutureBuilder<PaginatedResult<Conversation>>(
            future: _future,
            builder: (
              BuildContext context,
              AsyncSnapshot<PaginatedResult<Conversation>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final List<Conversation> items = snapshot.data?.items ?? const <Conversation>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    'No conversations yet. You can find anybody in the directory and write to '
                    'them without being given their number.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) => _ConversationRow(
                  conversation: items[index],
                  replying: _replyingTo == items[index].id,
                  onToggleReply: () => setState(
                    () => _replyingTo = _replyingTo == items[index].id ? null : items[index].id,
                  ),
                  onSent: _reload,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConversationRow extends StatefulWidget {
  const _ConversationRow({
    required this.conversation,
    required this.replying,
    required this.onToggleReply,
    required this.onSent,
  });

  final Conversation conversation;
  final bool replying;
  final VoidCallback onToggleReply;
  final VoidCallback onSent;

  @override
  State<_ConversationRow> createState() => _ConversationRowState();
}

class _ConversationRowState extends State<_ConversationRow> {
  final TextEditingController _reply = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String body = _reply.text.trim();
    if (body.isEmpty) return;

    final MessageRepository repository = context.read<MessageRepository>();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await repository.send(widget.conversation.id, body);
      _reply.clear();
      widget.onSent();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Conversation conversation = widget.conversation;
    final bool unread = conversation.unreadCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: widget.onToggleReply,
          child: Container(
            color: unread ? AppColors.navy.withValues(alpha: 0.04) : null,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.navy,
                  backgroundImage: (conversation.other.avatarUrl ?? '').isEmpty
                      ? null
                      : NetworkImage(conversation.other.avatarUrl!),
                  child: (conversation.other.avatarUrl ?? '').isEmpty
                      ? Text(
                          conversation.other.name.isEmpty
                              ? '?'
                              : conversation.other.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const Gap.hMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        conversation.other.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if ((conversation.lastMessageText ?? '').isNotEmpty)
                        Text(
                          conversation.lastMessageText!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Gap.hSm(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (conversation.lastMessageAt != null)
                      Text(
                        Formatters.relative(conversation.lastMessageAt!),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    if (unread) ...<Widget>[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          '${conversation.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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
        ),

        // The quick reply, so an answer does not cost somebody the page they
        // were on.
        if (widget.replying)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  const Gap.sm(),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        autofocus: true,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Type a reply…',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const Gap.hSm(),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send, size: 18),
                      tooltip: 'Send',
                    ),
                  ],
                ),
                const Gap.sm(),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.conversation(conversation.id));
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View the full conversation'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chrome
// ---------------------------------------------------------------------------

class _IconWithCount extends StatelessWidget {
  const _IconWithCount({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
    required this.onDark,
  });

  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color colour = onDark ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return IconButton(
      tooltip: count > 0 ? '$tooltip ($count unread)' : tooltip,
      onPressed: onTap,
      icon: count > 0
          ? Badge.count(count: count, child: Icon(icon, color: colour))
          : Icon(icon, color: colour),
    );
  }
}

/// A panel anchored to the top-right, the way a header menu behaves — rather
/// than a dialog in the middle of the screen, which would read as an
/// interruption instead of a drawer.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool narrow = size.width < 560;

    return Align(
      alignment: narrow ? Alignment.center : Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(
          top: narrow ? 0 : 72,
          right: narrow ? 0 : AppSpacing.xl,
          left: narrow ? AppSpacing.lg : 0,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgAll,
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: size.height * 0.72,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
