import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/news.dart';
import '../../repositories/news_portal_repository.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// THE NEWSROOM.
///
/// ---------------------------------------------------------------------------
/// THE QUEUE IS THE PRODUCT
/// ---------------------------------------------------------------------------
///
/// A community newspaper fails at the queue, not at the writing. Somebody sends
/// in an account of a meeting, nobody sees it, nothing happens, and they never
/// send another. So this screen is built around the states a story moves
/// through and puts the ones with a person waiting on them first.
///
/// Every tab says what the state MEANS rather than only naming it. "Changes
/// requested" tells an editor nothing on its own; "an editor asked for
/// something before it can go out" tells them whose move it is.
class NewsWorkspacePage extends StatefulWidget {
  const NewsWorkspacePage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<NewsWorkspacePage> createState() => _NewsWorkspacePageState();
}

class _NewsWorkspacePageState extends State<NewsWorkspacePage> {
  String _status = 'pending_review';
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) => setState(() {
    _reloads += 1;
    _notice = notice;
  });

  @override
  Widget build(BuildContext context) {
    final NewsPortalRepository repository = context.read<NewsPortalRepository>();
    final ThemeData theme = Theme.of(context);
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;

    return WorkspaceShell(
      currentPath: AppRoutes.editorialNews,
      title: 'News',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      actions: <Widget>[
        IconButton(
          tooltip: 'Write a story',
          icon: const Icon(Icons.add),
          onPressed: () => context.go(AppRoutes.editorialNewsCompose),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Everything the community has sent in, and everything the Editorial Team is '
                  'writing. Stories with somebody waiting on an answer come first.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap.hLg(),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.editorialNewsCompose),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Write a story'),
              ),
            ],
          ),
          const Gap.xl(),

          if (_notice != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                borderRadius: AppRadius.smAll,
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Text(_notice!, style: theme.textTheme.bodyMedium),
            ),
            const Gap.xl(),
          ],

          AsyncContent<
            ({List<EditorialNewsRow> items, Map<String, int> counts, int total, int totalPages})
          >(
            key: ValueKey<String>('$_status:$_reloads'),
            load: () => repository.editorialList(status: _status),
            loadingMessage: 'Opening the newsroom…',
            builder:
                (
                  BuildContext context,
                  ({
                    List<EditorialNewsRow> items,
                    Map<String, int> counts,
                    int total,
                    int totalPages,
                  })
                  result,
                ) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Everything'),
                          selected: _status == 'all',
                          onSelected: (_) => setState(() {
                            _status = 'all';
                            _reloads += 1;
                          }),
                        ),
                        ...NewsStatus.all.map(
                          (({String value, String label, String meaning}) status) {
                            final int count = result.counts[status.value] ?? 0;
                            return Tooltip(
                              message: status.meaning,
                              child: ChoiceChip(
                                label: Text(
                                  count > 0 ? '${status.label} ($count)' : status.label,
                                ),
                                selected: _status == status.value,
                                onSelected: (_) => setState(() {
                                  _status = status.value;
                                  _reloads += 1;
                                  _notice = null;
                                }),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Gap.sm(),
                    Text(
                      NewsStatus.meaning(_status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap.xl(),

                    if (result.items.isEmpty)
                      EmptyView(
                        icon: Icons.article_outlined,
                        showContributeAction: false,
                        title: 'Nothing here',
                        message: _status == 'pending_review'
                            ? 'Nothing is waiting to be read. Stories members send in arrive '
                                  'here.'
                            : 'No stories in this state.',
                      )
                    else
                      ...result.items.map(
                        (EditorialNewsRow row) => _StoryRow(row: row, onChanged: _reload),
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

/// One story in the queue.
class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.row, required this.onChanged});

  final EditorialNewsRow row;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: row.status == 'pending_review'
                ? AppColors.gold.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (row.coverUrl != null) ...<Widget>[
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: Image.network(
                      row.coverUrl!,
                      width: 96,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 64),
                    ),
                  ),
                  const Gap.hLg(),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(row.title, style: theme.textTheme.titleMedium),
                      const Gap.xs(),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _StatePill(status: row.status),
                          if (row.categoryName != null)
                            Text(row.categoryName!, style: theme.textTheme.labelSmall),
                          if (row.isFromMember)
                            Text(
                              'Sent in by ${row.contributorName}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.goldDark,
                              ),
                            ),
                          if (row.isFeatured)
                            const Icon(Icons.star, size: 14, color: AppColors.gold),
                          if (row.isImportant)
                            const Icon(Icons.campaign, size: 14, color: AppColors.gold),
                          Text(
                            'Updated ${Formatters.relative(row.updatedAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (row.scheduledPublishAt != null) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          'Goes out ${Formatters.dateTime(row.scheduledPublishAt)}',
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.green),
                        ),
                      ],
                      if (row.reviewNotes != null) ...<Widget>[
                        const Gap.sm(),
                        Text(
                          'Note: ${row.reviewNotes}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Gap.md(),
            const Divider(height: 1),
            const Gap.md(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.editorialNewsEdit(row.id)),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Open'),
                ),
                if (row.status == 'published')
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.newsItem(row.slug)),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View'),
                  ),
                ..._actionsFor(context, row.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// What can be done from here, given where the story is.
  ///
  /// Only the moves that make sense: a rejected story does not offer "publish",
  /// and a draft does not offer "approve". The full set lives in the composer,
  /// where an editor has read the thing they are deciding about.
  List<Widget> _actionsFor(BuildContext context, String status) {
    switch (status) {
      case 'pending_review':
        return <Widget>[
          FilledButton(
            onPressed: () => _move(context, 'approved', 'Approved.'),
            child: const Text('Approve'),
          ),
          TextButton(
            onPressed: () => _moveWithComment(
              context,
              'changes_requested',
              'What do you need before this can go out?',
            ),
            child: const Text('Ask for changes'),
          ),
          TextButton(
            onPressed: () => _moveWithComment(context, 'rejected', 'Why not?'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Decline'),
          ),
        ];

      case 'approved':
        return <Widget>[
          FilledButton(
            onPressed: () => _move(context, 'published', 'Published.'),
            child: const Text('Publish now'),
          ),
          OutlinedButton(
            onPressed: () => _schedule(context),
            child: const Text('Schedule'),
          ),
        ];

      case 'published':
        return <Widget>[
          TextButton(
            onPressed: () => _move(context, 'archived', 'Archived.'),
            child: const Text('Archive'),
          ),
        ];

      default:
        return const <Widget>[];
    }
  }

  Future<void> _move(BuildContext context, String status, String notice) async {
    try {
      await context.read<NewsPortalRepository>().setState(row.id, status: status);
      onChanged(notice);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _moveWithComment(BuildContext context, String status, String prompt) async {
    final TextEditingController comment = TextEditingController();

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(prompt),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (row.isFromMember)
                    Text(
                      '${row.contributorName} can read this. Write it to them.',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  const Gap.md(),
                  TextField(controller: comment, maxLines: 4, autofocus: true),
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
                child: const Text('Send'),
              ),
            ],
          ),
        ) ??
        false;

    if (!go || !context.mounted) return;

    try {
      await context.read<NewsPortalRepository>().setState(
        row.id,
        status: status,
        comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
      );
      onChanged('Saved, and they have been told.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _schedule(BuildContext context) async {
    final DateTime now = DateTime.now();

    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'When should it go out?',
    );
    if (day == null || !context.mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'At what time?',
    );
    if (time == null || !context.mounted) return;

    final DateTime when = DateTime(day.year, day.month, day.day, time.hour, time.minute);

    try {
      await context.read<NewsPortalRepository>().setState(
        row.id,
        status: 'scheduled',
        scheduledFor: when.toUtc().toIso8601String(),
      );
      onChanged('Scheduled for ${Formatters.dateTime(when.toIso8601String())}.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

/// Where a story is, at a glance.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color colour = switch (status) {
      'published' => AppColors.green,
      'pending_review' => AppColors.gold,
      'changes_requested' => AppColors.goldDark,
      'rejected' => theme.colorScheme.error,
      'scheduled' => AppColors.navyLight,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Text(
        NewsStatus.label(status),
        style: theme.textTheme.labelSmall?.copyWith(color: colour),
      ),
    );
  }
}
