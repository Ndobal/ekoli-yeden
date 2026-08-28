import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/forum.dart';
import '../../repositories/forum_repository.dart';
import '../../services/auth/auth_controller.dart';

/// STARTING A CONVERSATION.
///
/// Three fields, and the shelf it belongs on. The category is asked for first
/// rather than last, because choosing where something belongs changes how it is
/// written — and a conversation filed in the wrong place is one the people who
/// could answer it never see.
///
/// A space that holds new conversations for a moderator says so on the way out,
/// not silently: an author who posts and then cannot find their own
/// conversation concludes the site is broken and does not post again.
class ForumNewTopicPage extends StatelessWidget {
  const ForumNewTopicPage({required this.space, super.key});

  final String space;

  @override
  Widget build(BuildContext context) {
    final ForumRepository repository = context.read<ForumRepository>();
    final AuthController auth = context.watch<AuthController>();

    if (!auth.isSignedIn) {
      return AppScaffold(
        currentPath: AppRoutes.forums,
        seo: const SeoMetadata(title: 'Start a conversation', noIndex: true),
        child: PageSection(
          reading: true,
          title: 'Sign in first',
          description:
              'Conversations are signed with your name, so the community knows who is '
              'speaking.',
          child: Row(
            children: <Widget>[
              FilledButton(
                onPressed: () => context.go(
                  AppRoutes.signInReturningTo(AppRoutes.forumNewTopic(space)),
                ),
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

    return AsyncContent<ForumSpaceView>(
      load: () => repository.space(space, perPage: 1),
      loadingMessage: 'Opening the composer…',
      builder: (BuildContext context, ForumSpaceView view) =>
          _Composer(space: space, view: view),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.space, required this.view});

  final String space;
  final ForumSpaceView view;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  String? _categoryId;
  bool _busy = false;
  String? _error;

  /// The shelves this person may actually write on. An announcements category
  /// is offered only to a moderator, because the alternative is letting
  /// somebody write a whole post and then be refused for a reason that was
  /// knowable before they started.
  List<ForumCategory> get _writable => widget.view.categories
      .where(
        (ForumCategory category) => !category.isModeratorsOnly || widget.view.viewer.isModerator,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    if (_writable.isNotEmpty) _categoryId = _writable.first.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      setState(() => _error = 'Choose where this belongs.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ({String slug, String status, String message}) result = await context
          .read<ForumRepository>()
          .createTopic(
            widget.space,
            title: _title.text.trim(),
            body: _body.text.trim(),
            categoryId: _categoryId!,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));

      // A conversation held for approval has nothing to open yet, so the author
      // goes back to the space with the message rather than to a page that
      // would answer "not found".
      context.go(
        result.status == 'published' && result.slug.isNotEmpty
            ? AppRoutes.forumTopic(widget.space, result.slug)
            : AppRoutes.forumSpace(widget.space),
      );
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ForumSpaceView view = widget.view;

    if (!view.viewer.canPost) {
      return AppScaffold(
        currentPath: AppRoutes.forums,
        seo: const SeoMetadata(title: 'Start a conversation', noIndex: true),
        child: PageSection(
          reading: true,
          title: 'You cannot post here yet',
          description: view.viewer.blockedReason,
          child: Row(
            children: <Widget>[
              FilledButton(
                onPressed: () => context.go(AppRoutes.join),
                child: const Text('Complete your membership'),
              ),
              const Gap.hLg(),
              TextButton(
                onPressed: () => context.go(AppRoutes.forumSpace(widget.space)),
                child: const Text('Back to the space'),
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      currentPath: AppRoutes.forums,
      seo: SeoMetadata(
        title: 'Start a conversation — ${view.space.name}',
        canonicalPath: AppRoutes.forumNewTopic(widget.space),
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        eyebrow: view.space.name,
        title: 'Start a conversation',
        description:
            'Say what you want to say plainly. A question is as welcome as an answer — '
            'somebody here probably knows.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Where does it belong?', style: theme.textTheme.titleSmall),
              const Gap.md(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _writable
                    .map(
                      (ForumCategory category) => ChoiceChip(
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        onSelected: (_) => setState(() => _categoryId = category.id),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (_selectedDescription != null) ...<Widget>[
                const Gap.sm(),
                Text(
                  _selectedDescription!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Gap.xxl(),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'What is it about?',
                  helperText: 'A whole sentence works better than one word.',
                ),
                validator: (String? value) {
                  final String text = (value ?? '').trim();
                  if (text.length < 4) return 'Give it a title of at least four characters.';
                  return null;
                },
              ),
              const Gap.lg(),
              TextFormField(
                controller: _body,
                minLines: 8,
                maxLines: 20,
                maxLength: 20000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What do you want to say?',
                  alignLabelWithHint: true,
                ),
                validator: (String? value) {
                  final String text = (value ?? '').trim();
                  if (text.length < 2) return 'Write something first.';
                  return null;
                },
              ),
              if (view.space.isYouthSpace) ...<Widget>[
                const Gap.lg(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.shield_outlined, size: 18),
                      const Gap.hMd(),
                      Expanded(
                        child: Text(
                          'People here may be young. Do not post anybody’s phone number, '
                          'address or school, including your own.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...<Widget>[
                const Gap.lg(),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const Gap.xl(),
              Row(
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: const Text('Post it'),
                  ),
                  const Gap.hLg(),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.forumSpace(widget.space)),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get _selectedDescription {
    for (final ForumCategory category in _writable) {
      if (category.id == _categoryId) return category.description;
    }
    return null;
  }
}
