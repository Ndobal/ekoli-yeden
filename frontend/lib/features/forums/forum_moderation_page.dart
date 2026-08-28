import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
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
import '../../services/api/api_response.dart';
import 'forum_topic_page.dart' show moderateWithReason;

/// THE MODERATORS' SIDE OF THE FORUMS.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS SCREEN IS FOR
/// ---------------------------------------------------------------------------
///
/// **The queue carries what was reported.** Reason, text, author, and the
/// conversation it sits in — all in the row. A moderator who has to open
/// another tab to find out what they are being asked about will either act
/// blind or not act, and both are worse than a longer row.
///
/// **Child-safety reports come first.** The server orders them that way and
/// this page marks them, because a queue where the urgent thing looks like
/// everything else is a queue that fails at exactly the wrong moment.
///
/// **Nothing here is silent.** Every action asks for a reason and writes it to
/// an append-only log, and the log is on this page rather than somewhere only
/// an administrator can see. A moderator's decisions are reviewable by the other
/// moderators, which is what makes them answerable.
class ForumModerationPage extends StatefulWidget {
  const ForumModerationPage({super.key});

  @override
  State<ForumModerationPage> createState() => _ForumModerationPageState();
}

class _ForumModerationPageState extends State<ForumModerationPage> {
  static const List<({String value, String label})> _statuses = <({String value, String label})>[
    (value: 'open', label: 'Waiting'),
    (value: 'reviewing', label: 'Being looked at'),
    (value: 'actioned', label: 'Acted on'),
    (value: 'dismissed', label: 'Dismissed'),
  ];

  String _status = 'open';
  int _reloads = 0;
  bool _showLog = false;

  void _reload() => setState(() => _reloads += 1);

  @override
  Widget build(BuildContext context) {
    final ForumRepository repository = context.read<ForumRepository>();

    return AppScaffold(
      currentPath: AppRoutes.forums,
      seo: const SeoMetadata(
        title: 'Forum moderation',
        description: 'The report queue and the moderation log.',
        noIndex: true,
      ),
      child: PageSection(
        eyebrow: 'Forums',
        title: 'Moderation',
        description:
            'What the community has reported, and every decision taken on it. The log is '
            'append-only and every moderator can read it.',
        action: OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.forums),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to the forums'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ..._statuses.map(
                  (({String value, String label}) status) => ChoiceChip(
                    label: Text(status.label),
                    selected: !_showLog && _status == status.value,
                    onSelected: (_) => setState(() {
                      _status = status.value;
                      _showLog = false;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                ChoiceChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: const Text('The log'),
                  selected: _showLog,
                  onSelected: (_) => setState(() => _showLog = true),
                ),
              ],
            ),
            const Gap.xl(),
            if (_showLog)
              AsyncContent<List<ForumModerationAction>>(
                key: ValueKey<String>('log:$_reloads'),
                load: repository.moderationLog,
                loadingMessage: 'Reading the log…',
                isEmpty: (List<ForumModerationAction> items) => items.isEmpty,
                emptyBuilder: (BuildContext context) => const EmptyView(
                  icon: Icons.history,
                  showContributeAction: false,
                  title: 'Nothing has been moderated yet',
                  message:
                      'Every hide, removal, lock, warning and suspension is recorded here, '
                      'with who did it and why.',
                ),
                builder: (BuildContext context, List<ForumModerationAction> items) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map((ForumModerationAction a) => _LogRow(action: a)).toList(),
                ),
              )
            else
              AsyncContent<PaginatedResult<ForumReport>>(
                key: ValueKey<String>('$_status:$_reloads'),
                load: () => repository.reports(status: _status),
                loadingMessage: 'Opening the queue…',
                isEmpty: (PaginatedResult<ForumReport> r) => r.isEmpty,
                emptyBuilder: (BuildContext context) => EmptyView(
                  icon: _status == 'open' ? Icons.check_circle_outline : Icons.inbox_outlined,
                  showContributeAction: false,
                  title: _status == 'open' ? 'Nothing is waiting' : 'Nothing here',
                  message: _status == 'open'
                      ? 'The queue is empty. Anything the community reports appears here, and '
                            'anything that puts a child at risk is hidden before it does.'
                      : 'No reports in this state.',
                ),
                builder: (BuildContext context, PaginatedResult<ForumReport> result) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${Formatters.number(result.total)} '
                      '${result.total == 1 ? 'report' : 'reports'}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Gap.md(),
                    ...result.items.map(
                      (ForumReport report) => _ReportCard(report: report, onChanged: _reload),
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

/// One report, with the thing it is about.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onChanged});

  final ForumReport report;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool urgent = report.isChildSafety;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: urgent
                ? theme.colorScheme.error.withValues(alpha: 0.6)
                : theme.colorScheme.outlineVariant,
            width: urgent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: urgent
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    report.reasonLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: urgent
                          ? theme.colorScheme.onError
                          : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Gap.hMd(),
                Text(
                  report.isTopic ? 'A conversation' : 'A reply',
                  style: theme.textTheme.labelMedium,
                ),
                const Spacer(),
                Text(
                  Formatters.relative(report.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (urgent) ...<Widget>[
              const Gap.md(),
              Text(
                'Hidden automatically when it was reported. It needs looking at now.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const Gap.lg(),

            // --- What was reported -----------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (report.targetTitle != null) ...<Widget>[
                    Text(report.targetTitle!, style: theme.textTheme.titleSmall),
                    const Gap.sm(),
                  ],
                  if (report.targetBody != null)
                    SelectableText(
                      Formatters.excerpt(report.targetBody, maxLength: 600),
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Text(
                      'The reported item is no longer in the database.',
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  const Gap.md(),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (report.targetAuthorName != null)
                        Text(
                          'Written by ${report.targetAuthorName}',
                          style: theme.textTheme.labelMedium,
                        ),
                      if (report.isAlreadyActioned)
                        Text(
                          report.targetStatus == 'removed'
                              ? 'Already removed'
                              : 'Already hidden',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      if (report.conversation != null)
                        TextButton.icon(
                          onPressed: () => context.go(
                            AppRoutes.forumTopic(
                              report.conversation!.space,
                              report.conversation!.topic,
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open the conversation'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (report.detail != null) ...<Widget>[
              const Gap.lg(),
              Text('What the person reporting said', style: theme.textTheme.labelMedium),
              const Gap.xs(),
              SelectableText(report.detail!, style: theme.textTheme.bodyMedium),
            ],

            if (report.reviewNotes != null) ...<Widget>[
              const Gap.lg(),
              Text('Notes from the review', style: theme.textTheme.labelMedium),
              const Gap.xs(),
              Text(report.reviewNotes!, style: theme.textTheme.bodyMedium),
            ],

            if (report.status == 'open' || report.status == 'reviewing') ...<Widget>[
              const Gap.xl(),
              const Divider(height: 1),
              const Gap.lg(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (!report.isAlreadyActioned)
                    OutlinedButton.icon(
                      onPressed: () => moderateWithReason(
                        context,
                        action: 'hide',
                        targetType: report.targetType,
                        targetId: report.targetId,
                        onDone: onChanged,
                      ),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('Hide it'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => moderateWithReason(
                        context,
                        action: 'restore',
                        targetType: report.targetType,
                        targetId: report.targetId,
                        onDone: onChanged,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Restore it'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => moderateWithReason(
                      context,
                      action: 'remove',
                      targetType: report.targetType,
                      targetId: report.targetId,
                      onDone: onChanged,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove it'),
                  ),
                  if (report.targetAuthorId != null)
                    OutlinedButton.icon(
                      onPressed: () => _sanction(context, report, onChanged),
                      icon: const Icon(Icons.gavel_outlined, size: 18),
                      label: const Text('Warn or suspend the author'),
                    ),
                ],
              ),
              const Gap.lg(),
              // Closing the report is separated from acting on the content,
              // because they are two decisions and a moderator can take either
              // without the other.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => _settle(context, report, 'dismissed', onChanged),
                    child: const Text('Nothing wrong here'),
                  ),
                  const Gap.hMd(),
                  FilledButton(
                    onPressed: () => _settle(context, report, 'actioned', onChanged),
                    child: const Text('Mark it dealt with'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Closes a report, with a note for whoever reads the queue next.
Future<void> _settle(
  BuildContext context,
  ForumReport report,
  String status,
  VoidCallback onChanged,
) async {
  final ForumRepository repository = context.read<ForumRepository>();
  final TextEditingController notes = TextEditingController();

  final bool go =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(status == 'dismissed' ? 'Dismiss this report' : 'Mark it dealt with'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  status == 'dismissed'
                      ? 'The report is closed and the content is left as it is. Dismissing a '
                            'report is a decision like any other and is recorded.'
                      : 'The report is closed. Do this once you have hidden, removed or '
                            'otherwise settled what it is about.',
                ),
                const Gap.lg(),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'A note for the next moderator (optional)',
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
              child: const Text('Close the report'),
            ),
          ],
        ),
      ) ??
      false;

  if (!go) return;

  try {
    await repository.settleReport(
      report.id,
      status: status,
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
    onChanged();
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// A warning, a suspension or a ban.
///
/// The three are presented with what each one does, because they are not
/// degrees of the same thing: a warning does not stop anybody posting, and a
/// suspension ends on a date the member is told.
Future<void> _sanction(
  BuildContext context,
  ForumReport report,
  VoidCallback onChanged,
) async {
  final ForumRepository repository = context.read<ForumRepository>();
  final TextEditingController reason = TextEditingController();
  String kind = 'warning';
  int days = 7;

  final bool go =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext inner, StateSetter setInner) => AlertDialog(
            title: Text('About ${report.targetAuthorName ?? 'this member'}'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RadioGroup<String>(
                      groupValue: kind,
                      onChanged: (String? value) => setInner(() => kind = value ?? kind),
                      child: const Column(
                        children: <Widget>[
                          RadioListTile<String>(
                            value: 'warning',
                            title: Text('A warning'),
                            subtitle: Text(
                              'They are told, and it is recorded. They can still post.',
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            value: 'suspension',
                            title: Text('A suspension'),
                            subtitle: Text('They cannot post until it ends. They are told when.'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            value: 'ban',
                            title: Text('A ban'),
                            subtitle: Text('They can no longer post in the forums at all.'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    if (kind == 'suspension') ...<Widget>[
                      const Gap.md(),
                      Row(
                        children: <Widget>[
                          const Text('For'),
                          const Gap.hMd(),
                          DropdownButton<int>(
                            value: days,
                            items: const <DropdownMenuItem<int>>[
                              DropdownMenuItem<int>(value: 1, child: Text('1 day')),
                              DropdownMenuItem<int>(value: 3, child: Text('3 days')),
                              DropdownMenuItem<int>(value: 7, child: Text('7 days')),
                              DropdownMenuItem<int>(value: 30, child: Text('30 days')),
                              DropdownMenuItem<int>(value: 90, child: Text('90 days')),
                            ],
                            onChanged: (int? value) => setInner(() => days = value ?? days),
                          ),
                        ],
                      ),
                    ],
                    const Gap.lg(),
                    TextField(
                      controller: reason,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Why — this is sent to them',
                        alignLabelWithHint: true,
                        helperText:
                            'Somebody who cannot post and does not know why assumes the '
                            'worst and leaves.',
                        helperMaxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Record it'),
              ),
            ],
          ),
        ),
      ) ??
      false;

  if (!go) return;

  try {
    await repository.sanction(
      userId: report.targetAuthorId!,
      kind: kind,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
      days: kind == 'suspension' ? days : null,
    );
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recorded, and the member has been told.')),
      );
    }
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// One line of the append-only log.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.action});

  final ForumModerationAction action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_iconFor(action.action), size: 18, color: theme.colorScheme.onSurfaceVariant),
            const Gap.hLg(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${action.moderatorName ?? 'A moderator'} '
                    '${_verb(action.action)} a ${action.targetType}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (action.reason != null) ...<Widget>[
                    const Gap.xs(),
                    Text(
                      action.reason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action.expiresAt != null) ...<Widget>[
                    const Gap.xs(),
                    Text(
                      'Until ${Formatters.date(action.expiresAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const Gap.hLg(),
            Text(
              Formatters.relative(action.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String action) {
    switch (action) {
      case 'hide':
        return Icons.visibility_off_outlined;
      case 'remove':
        return Icons.delete_outline;
      case 'restore':
      case 'approve':
        return Icons.visibility_outlined;
      case 'lock':
        return Icons.lock_outline;
      case 'unlock':
        return Icons.lock_open_outlined;
      case 'pin':
      case 'unpin':
        return Icons.push_pin_outlined;
      case 'warn':
        return Icons.report_gmailerrorred_outlined;
      case 'suspend':
      case 'ban':
        return Icons.gavel_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  static String _verb(String action) {
    switch (action) {
      case 'hide':
        return 'hid';
      case 'remove':
        return 'removed';
      case 'restore':
        return 'restored';
      case 'approve':
        return 'approved';
      case 'lock':
        return 'closed';
      case 'unlock':
        return 'reopened';
      case 'pin':
        return 'pinned';
      case 'unpin':
        return 'unpinned';
      case 'warn':
        return 'warned';
      case 'suspend':
        return 'suspended';
      case 'ban':
        return 'banned';
      default:
        return 'acted on';
    }
  }
}
