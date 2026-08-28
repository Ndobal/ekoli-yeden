import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/forum.dart';
import '../../repositories/forum_repository.dart';
import '../../services/auth/auth_controller.dart';
import 'forum_pages.dart' show ForumAvatar, showForumReportDialog;

/// ONE CONVERSATION.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS PAGE IS CAREFUL ABOUT
/// ---------------------------------------------------------------------------
///
/// **Replies are shown in the order they were written**, with one level of
/// nesting for a direct answer to somebody. Deeper nesting turns a conversation
/// into a tree that has to be explored rather than read, and on a phone it runs
/// out of horizontal room by the third level.
///
/// **An edit is stamped.** The server records when a reply was changed and this
/// page says so, because a conversation where posts change silently under the
/// people who replied to them is one nobody can follow.
///
/// **A moderator's controls are visible, labelled, and ask for a reason.** The
/// reason goes into an append-only log every moderator can read — "who removed
/// my post, and why?" has to have an answer somebody else can check.
class ForumTopicPage extends StatefulWidget {
  const ForumTopicPage({required this.space, required this.topic, super.key});

  final String space;
  final String topic;

  @override
  State<ForumTopicPage> createState() => _ForumTopicPageState();
}

class _ForumTopicPageState extends State<ForumTopicPage> {
  /// Bumped after anything that changes the conversation, which reissues the
  /// request rather than patching a local copy. A forum is the one place where
  /// what somebody else did matters as much as what you did.
  int _reloads = 0;

  void _reload() => setState(() => _reloads += 1);

  @override
  Widget build(BuildContext context) {
    final ForumRepository repository = context.read<ForumRepository>();

    return AsyncContent<ForumTopicView>(
      key: ValueKey<String>('${widget.space}/${widget.topic}:$_reloads'),
      load: () => repository.topic(widget.space, widget.topic),
      loadingMessage: 'Opening the conversation…',
      builder: (BuildContext context, ForumTopicView view) =>
          _Conversation(space: widget.space, view: view, onChanged: _reload),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.space, required this.view, required this.onChanged});

  final String space;
  final ForumTopicView view;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ForumTopic topic = view.topic;

    // One level of nesting: a reply to the conversation, and a reply to that
    // reply. Anything deeper is rendered against its grandparent rather than
    // disappearing.
    final List<ForumPost> roots = view.posts
        .where((ForumPost post) => post.parentPostId == null)
        .toList(growable: false);
    final Set<String> rootIds = roots.map((ForumPost post) => post.id).toSet();
    final List<ForumPost> orphans = view.posts
        .where(
          (ForumPost post) =>
              post.parentPostId != null && !rootIds.contains(post.parentPostId),
        )
        .toList(growable: false);

    return AppScaffold(
      currentPath: AppRoutes.forums,
      seo: SeoMetadata(
        title: topic.title,
        description: topic.excerpt.isEmpty ? 'A conversation in the Yakoli forums.' : topic.excerpt,
        canonicalPath: AppRoutes.forumTopic(space, topic.slug),
        // A conversation inherits the caution of the space it sits in, and the
        // client cannot see that flag from here — so a topic page is never
        // offered to a search engine. The index and the space pages are what
        // the archive wants found.
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Breadcrumb(space: space, categoryName: topic.categoryName),
            const Gap.lg(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (topic.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: AppSpacing.md),
                    child: Icon(
                      Icons.push_pin_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Expanded(child: SelectableText(topic.title, style: theme.textTheme.headlineMedium)),
              ],
            ),
            const Gap.md(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (topic.isAwaitingApproval) const StatusBadge('pending_review'),
                if (topic.isLocked)
                  const _Tag(
                    icon: Icons.lock_outline,
                    label: 'Closed to new replies',
                  ),
                if (topic.isHidden)
                  const _Tag(
                    icon: Icons.visibility_off_outlined,
                    label: 'Hidden — only moderators see this',
                    warn: true,
                  ),
              ],
            ),
            const Gap.xl(),

            // --- The opening post ---------------------------------------
            _PostCard(
              author: view.author,
              body: view.body,
              createdAt: topic.createdAt,
              isOpening: true,
              reactionCount: topic.reactionCount,
              youReacted: view.youReacted,
              onReact: () => _react(context, 'topic', topic.id, onChanged),
              onReport: () =>
                  showForumReportDialog(context, targetType: 'topic', targetId: topic.id),
              trailing: _TopicActions(
                view: view,
                space: space,
                onChanged: onChanged,
              ),
              moderatorMenu: view.viewer.isModerator
                  ? _ModeratorMenu(
                      targetType: 'topic',
                      targetId: topic.id,
                      isHidden: topic.isHidden,
                      isLocked: topic.isLocked,
                      isPinned: topic.isPinned,
                      isAwaitingApproval: topic.isAwaitingApproval,
                      onDone: onChanged,
                    )
                  : null,
            ),

            const Gap.xxl(),
            Row(
              children: <Widget>[
                Text(
                  view.posts.isEmpty
                      ? 'No replies yet'
                      : view.posts.length == 1
                      ? '1 reply'
                      : '${Formatters.number(view.posts.length)} replies',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                if (view.posts.isNotEmpty)
                  Text(
                    'Oldest first',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const Gap.lg(),

            // --- Replies -------------------------------------------------
            if (view.posts.isEmpty)
              _NoReplies(canPost: view.viewer.canPost && !topic.isLocked)
            else ...<Widget>[
              for (final ForumPost post in roots) ...<Widget>[
                _ReplyBlock(
                  space: space,
                  topic: topic,
                  post: post,
                  children: view.posts
                      .where((ForumPost child) => child.parentPostId == post.id)
                      .toList(growable: false),
                  viewer: view.viewer,
                  onChanged: onChanged,
                ),
              ],
              // A reply whose parent was removed still belongs to the
              // conversation. It is shown at the top level rather than
              // vanishing with the post it answered.
              for (final ForumPost post in orphans)
                _ReplyBlock(
                  space: space,
                  topic: topic,
                  post: post,
                  children: const <ForumPost>[],
                  viewer: view.viewer,
                  onChanged: onChanged,
                ),
            ],

            const Gap.xxl(),
            _ReplyComposer(
              space: space,
              topicSlug: topic.slug,
              viewer: view.viewer,
              isLocked: topic.isLocked,
              onPosted: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _react(
  BuildContext context,
  String targetType,
  String id,
  VoidCallback onChanged,
) async {
  try {
    await context.read<ForumRepository>().react(targetType, id);
    onChanged();
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.space, required this.categoryName});

  final String space;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.forumSpace(space)),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back to the space'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        if (categoryName != null) ...<Widget>[
          const Gap.hMd(),
          Text(
            '·  $categoryName',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A post — the opening one, or a reply.
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.author,
    required this.body,
    required this.createdAt,
    required this.reactionCount,
    required this.youReacted,
    required this.onReact,
    required this.onReport,
    this.isOpening = false,
    this.editedAt,
    this.status = 'published',
    this.trailing,
    this.moderatorMenu,
    this.onReply,
    this.onEdit,
    this.indented = false,
  });

  final ForumAuthor author;
  final String body;
  final String? createdAt;
  final String? editedAt;
  final String status;
  final int reactionCount;
  final bool youReacted;
  final VoidCallback onReact;
  final VoidCallback onReport;
  final bool isOpening;
  final Widget? trailing;
  final Widget? moderatorMenu;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool takenDown = status == 'hidden' || status == 'removed';

    return Container(
      margin: EdgeInsets.only(left: indented ? AppSpacing.xxl : 0, bottom: AppSpacing.md),
      padding: EdgeInsets.all(isOpening ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: isOpening ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: takenDown
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ForumAvatar(name: author.name, size: isOpening ? 44 : 36),
              const Gap.hMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            author.name,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // A handle only where the server sent one. In a youth
                        // space it never does, and nothing here links to a
                        // profile that was deliberately withheld.
                        if (author.handle != null) ...<Widget>[
                          const Gap.hSm(),
                          InkWell(
                            onTap: () => context.go(AppRoutes.memberProfile(author.handle!)),
                            child: Text(
                              '@${author.handle}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.navyLight,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      <String?>[
                        Formatters.relative(createdAt),
                        if (editedAt != null) 'edited ${Formatters.relative(editedAt)}',
                      ].whereType<String>().join('  ·  '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ?moderatorMenu,
            ],
          ),
          const Gap.lg(),
          if (takenDown)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                status == 'removed'
                    ? 'A moderator removed this.'
                    : 'A moderator has hidden this. Only moderators can see it.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (takenDown) const Gap.md(),
          SelectableText(
            body,
            style: isOpening ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium,
          ),
          const Gap.lg(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _ReactionButton(
                count: reactionCount,
                reacted: youReacted,
                onPressed: onReact,
              ),
              if (onReply != null)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
                ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Report'),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
              ),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }
}

/// One reply, and the replies to it.
class _ReplyBlock extends StatefulWidget {
  const _ReplyBlock({
    required this.space,
    required this.topic,
    required this.post,
    required this.children,
    required this.viewer,
    required this.onChanged,
    this.indented = false,
  });

  final String space;
  final ForumTopic topic;
  final ForumPost post;
  final List<ForumPost> children;
  final ForumViewer viewer;
  final VoidCallback onChanged;
  final bool indented;

  @override
  State<_ReplyBlock> createState() => _ReplyBlockState();
}

class _ReplyBlockState extends State<_ReplyBlock> {
  bool _replying = false;
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final ForumPost post = widget.post;
    final bool canReply = widget.viewer.canPost && !widget.topic.isLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PostCard(
          author: post.author,
          body: post.body,
          createdAt: post.createdAt,
          editedAt: post.editedAt,
          status: post.status,
          reactionCount: post.reactionCount,
          youReacted: post.youReacted,
          indented: widget.indented,
          onReact: () => _react(context, 'post', post.id, widget.onChanged),
          onReport: () =>
              showForumReportDialog(context, targetType: 'post', targetId: post.id),
          onReply: canReply && !widget.indented
              ? () => setState(() => _replying = !_replying)
              : null,
          onEdit: post.isMine ? () => setState(() => _editing = !_editing) : null,
          moderatorMenu: widget.viewer.isModerator
              ? _ModeratorMenu(
                  targetType: 'post',
                  targetId: post.id,
                  isHidden: post.isHidden,
                  onDone: widget.onChanged,
                )
              : null,
        ),

        if (_editing)
          Padding(
            padding: EdgeInsets.only(
              left: widget.indented ? AppSpacing.xxl : 0,
              bottom: AppSpacing.lg,
            ),
            child: _EditBox(
              initial: post.body,
              onCancel: () => setState(() => _editing = false),
              onSave: (String body) async {
                await context.read<ForumRepository>().editPost(post.id, body);
                if (mounted) setState(() => _editing = false);
                widget.onChanged();
              },
            ),
          ),

        for (final ForumPost child in widget.children)
          _ReplyBlock(
            space: widget.space,
            topic: widget.topic,
            post: child,
            children: const <ForumPost>[],
            viewer: widget.viewer,
            onChanged: widget.onChanged,
            indented: true,
          ),

        if (_replying)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxl, bottom: AppSpacing.lg),
            child: _ReplyComposer(
              space: widget.space,
              topicSlug: widget.topic.slug,
              viewer: widget.viewer,
              isLocked: widget.topic.isLocked,
              parentPostId: post.id,
              replyingTo: post.author.name,
              onPosted: () {
                setState(() => _replying = false);
                widget.onChanged();
              },
              onCancel: () => setState(() => _replying = false),
            ),
          ),
      ],
    );
  }
}

/// Reaction, as a count and a state — never as a score that orders anything.
class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.count, required this.reacted, required this.onPressed});

  final int count;
  final bool reacted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        reacted ? Icons.favorite : Icons.favorite_border,
        size: 16,
        color: reacted ? AppColors.green : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        count == 0 ? 'Thank you' : Formatters.number(count),
        style: theme.textTheme.labelMedium?.copyWith(
          color: reacted ? AppColors.green : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Following, and the moderator's way into the queue.
class _TopicActions extends StatefulWidget {
  const _TopicActions({required this.view, required this.space, required this.onChanged});

  final ForumTopicView view;
  final String space;
  final VoidCallback onChanged;

  @override
  State<_TopicActions> createState() => _TopicActionsState();
}

class _TopicActionsState extends State<_TopicActions> {
  late bool _following = widget.view.isFollowing;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    if (!auth.isSignedIn) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                final bool now = await context
                    .read<ForumRepository>()
                    .follow(widget.view.topic.id);
                if (mounted) setState(() => _following = now);
              } on AppException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: Icon(
        _following ? Icons.notifications_active : Icons.notifications_none,
        size: 16,
      ),
      label: Text(_following ? 'Following' : 'Follow'),
    );
  }
}

/// The composer.
///
/// Deliberately plain: a box, a button, and the count of what is left. A
/// forum on a phone in Ekori is not the place for a formatting toolbar.
class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({
    required this.space,
    required this.topicSlug,
    required this.viewer,
    required this.isLocked,
    required this.onPosted,
    this.parentPostId,
    this.replyingTo,
    this.onCancel,
  });

  final String space;
  final String topicSlug;
  final ForumViewer viewer;
  final bool isLocked;
  final VoidCallback onPosted;
  final String? parentPostId;
  final String? replyingTo;
  final VoidCallback? onCancel;

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  final TextEditingController _body = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String body = _body.text.trim();
    if (body.length < 2) {
      setState(() => _error = 'Write something first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<ForumRepository>().reply(
        widget.space,
        widget.topicSlug,
        body: body,
        parentPostId: widget.parentPostId,
      );
      _body.clear();
      widget.onPosted();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    if (widget.isLocked) {
      return const _Notice(
        icon: Icons.lock_outline,
        text: 'This conversation has been closed to new replies.',
      );
    }

    if (!auth.isSignedIn) {
      return _Notice(
        icon: Icons.login,
        text: 'Sign in to take part in this conversation.',
        action: FilledButton(
          onPressed: () => context.go(
            AppRoutes.signInReturningTo(AppRoutes.forumTopic(widget.space, widget.topicSlug)),
          ),
          child: const Text('Sign in'),
        ),
      );
    }

    if (!widget.viewer.canPost) {
      return _Notice(
        icon: Icons.info_outline,
        text: widget.viewer.blockedReason ?? 'You cannot post here.',
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.join),
          child: const Text('Complete your membership'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.replyingTo != null) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.reply, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const Gap.hSm(),
                Text(
                  'Replying to ${widget.replyingTo}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const Gap.md(),
          ],
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 10,
            maxLength: 20000,
            decoration: InputDecoration(
              hintText: widget.replyingTo == null
                  ? 'Add to this conversation'
                  : 'Your answer',
              alignLabelWithHint: true,
              errorText: _error,
            ),
          ),
          Row(
            children: <Widget>[
              if (widget.onCancel != null)
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 16),
                label: const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Editing your own reply.
class _EditBox extends StatefulWidget {
  const _EditBox({required this.initial, required this.onSave, required this.onCancel});

  final String initial;
  final Future<void> Function(String body) onSave;
  final VoidCallback onCancel;

  @override
  State<_EditBox> createState() => _EditBoxState();
}

class _EditBoxState extends State<_EditBox> {
  late final TextEditingController _body = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 10,
            decoration: InputDecoration(errorText: _error),
          ),
          const Gap.sm(),
          Text(
            'The conversation will show that this was edited, and when.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.md(),
          Row(
            children: <Widget>[
              TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
              const Spacer(),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          await widget.onSave(_body.text.trim());
                        } on AppException catch (error) {
                          if (mounted) setState(() => _error = error.message);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Save the change'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A moderator's controls, with the reason they will be recorded under.
class _ModeratorMenu extends StatelessWidget {
  const _ModeratorMenu({
    required this.targetType,
    required this.targetId,
    required this.onDone,
    this.isHidden = false,
    this.isLocked = false,
    this.isPinned = false,
    this.isAwaitingApproval = false,
  });

  final String targetType;
  final String targetId;
  final VoidCallback onDone;
  final bool isHidden;
  final bool isLocked;
  final bool isPinned;
  final bool isAwaitingApproval;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Moderate',
      icon: const Icon(Icons.shield_outlined, size: 18),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (isAwaitingApproval)
          const PopupMenuItem<String>(value: 'approve', child: Text('Approve — let it appear')),
        if (isHidden)
          const PopupMenuItem<String>(value: 'restore', child: Text('Restore it'))
        else
          const PopupMenuItem<String>(value: 'hide', child: Text('Hide it')),
        const PopupMenuItem<String>(
          value: 'remove',
          child: Text('Remove it — the text is cleared'),
        ),
        if (targetType == 'topic') ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: isLocked ? 'unlock' : 'lock',
            child: Text(isLocked ? 'Open it to replies' : 'Close it to replies'),
          ),
          PopupMenuItem<String>(
            value: isPinned ? 'unpin' : 'pin',
            child: Text(isPinned ? 'Unpin it' : 'Pin it to the top'),
          ),
        ],
      ],
      onSelected: (String action) => moderateWithReason(
        context,
        action: action,
        targetType: targetType,
        targetId: targetId,
        onDone: onDone,
      ),
    );
  }
}

/// Asks for the reason, then acts.
///
/// The reason is optional to the API and asked for here anyway: the log is what
/// somebody appeals to, and a log of actions with no reasons in it cannot
/// answer anybody.
Future<void> moderateWithReason(
  BuildContext context, {
  required String action,
  required String targetType,
  required String targetId,
  required VoidCallback onDone,
}) async {
  final ForumRepository repository = context.read<ForumRepository>();
  final TextEditingController reason = TextEditingController();

  final bool go =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(_actionTitle(action)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_actionExplanation(action)),
                const Gap.lg(),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Why (recorded in the moderation log)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_actionTitle(action)),
            ),
          ],
        ),
      ) ??
      false;

  if (!go) return;

  try {
    await repository.moderate(
      action: action,
      targetType: targetType,
      targetId: targetId,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
    );
    onDone();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Done, and recorded.')));
    }
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

String _actionTitle(String action) {
  switch (action) {
    case 'hide':
      return 'Hide it';
    case 'remove':
      return 'Remove it';
    case 'restore':
      return 'Restore it';
    case 'approve':
      return 'Approve it';
    case 'lock':
      return 'Close it to replies';
    case 'unlock':
      return 'Open it to replies';
    case 'pin':
      return 'Pin it';
    case 'unpin':
      return 'Unpin it';
    default:
      return 'Confirm';
  }
}

String _actionExplanation(String action) {
  switch (action) {
    case 'hide':
      return 'It stops appearing to everybody except moderators. The text is kept, and it can '
          'be restored.';
    case 'remove':
      return 'The text is replaced with a note saying a moderator removed it. The record stays '
          'so the decision can be reviewed, but the words are gone.';
    case 'restore':
      return 'It appears again to everybody.';
    case 'approve':
      return 'It appears to everybody in the space.';
    case 'lock':
      return 'Nobody but a moderator can reply. What is already here stays readable.';
    case 'unlock':
      return 'Replies are open again.';
    case 'pin':
      return 'It sits at the top of the space until it is unpinned.';
    case 'unpin':
      return 'It returns to its place in the order.';
    default:
      return '';
  }
}

class _NoReplies extends StatelessWidget {
  const _NoReplies({required this.canPost});

  final bool canPost;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.chat_bubble_outline,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const Gap.md(),
          Text(
            canPost
                ? 'Nobody has replied yet. You could be the first.'
                : 'Nobody has replied yet.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.warn = false});

  final IconData icon;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = warn ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colour),
          const Gap.hXs(),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colour)),
        ],
      ),
    );
  }
}
