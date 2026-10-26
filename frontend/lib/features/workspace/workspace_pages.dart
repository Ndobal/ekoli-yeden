import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/submission_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart';
import 'settings_form.dart';
import 'source_tools.dart';

/// Screens shared between the Editorial and Administration workspaces.
///
/// Both workspaces need a submissions queue and a source library; only the
/// shell around them differs. Building each twice would guarantee they drift.

// ---------------------------------------------------------------------------
// Submissions
// ---------------------------------------------------------------------------

/// THE MODERATION QUEUE.
///
/// What the community has sent in, and the decision each item is waiting for.
/// Nothing here is public — a submission is a proposal until a moderator turns
/// it into content.
class SubmissionsQueuePage extends StatefulWidget {
  const SubmissionsQueuePage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<SubmissionsQueuePage> createState() => _SubmissionsQueuePageState();
}

class _SubmissionsQueuePageState extends State<SubmissionsQueuePage> {
  String? _status = ContentStatus.pendingReview;
  int _reloadToken = 0;

  void _reload() => setState(() => _reloadToken += 1);

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: isAdmin ? AppRoutes.adminSubmissions : AppRoutes.editorialSubmissions,
      title: 'Submissions',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminNote(
            message:
                'Material sent in by the community. Nothing here is visible on the website. '
                'Approving a submission records the decision; the material is then written up as '
                'content, with the contributor credited.',
          ),
          const Gap.xl(),

          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              FilterChip(
                label: const Text('All'),
                selected: _status == null,
                onSelected: (_) => setState(() => _status = null),
              ),
              ...<String>[
                ContentStatus.pendingReview,
                ContentStatus.approved,
                ContentStatus.rejected,
                ContentStatus.archived,
              ].map(
                (String status) => FilterChip(
                  label: Text(ContentStatus.label(status)),
                  selected: _status == status,
                  onSelected: (bool selected) =>
                      setState(() => _status = selected ? status : null),
                ),
              ),
            ],
          ),
          const Gap.xl(),

          AsyncContent<PaginatedResult<ContentRecord>>(
            key: ValueKey<String>('submissions:$_status:$_reloadToken'),
            load: () => context.read<SubmissionRepository>().queue(status: _status, perPage: 50),
            loadingMessage: 'Loading the queue…',
            isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
            emptyBuilder: (BuildContext context) => const EmptyView(
              icon: Icons.inbox_outlined,
              title: 'Nothing waiting',
              message:
                  'Contributions sent through the public form appear here for review. '
                  'The queue being empty means there is nothing outstanding.',
              showContributeAction: false,
            ),
            builder: (BuildContext context, PaginatedResult<ContentRecord> result) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${result.total} submission${result.total == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                const Gap.lg(),
                ...result.items.map(
                  (ContentRecord submission) =>
                      _SubmissionRow(submission: submission, onReviewed: _reload),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionRow extends StatefulWidget {
  const _SubmissionRow({required this.submission, required this.onReviewed});

  final ContentRecord submission;
  final VoidCallback onReviewed;

  @override
  State<_SubmissionRow> createState() => _SubmissionRowState();
}

class _SubmissionRowState extends State<_SubmissionRow> {
  bool _busy = false;
  String? _error;

  Future<void> _review(String status) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SubmissionRepository>().review(widget.submission.id, status: status);
      widget.onReviewed();
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
    final ContentRecord s = widget.submission;
    final bool canReview = auth.canReview || auth.can('submissions:review') || auth.can('*');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.text('title') ?? 'Untitled', style: theme.textTheme.titleMedium),
                      const Gap.xs(),
                      Text(
                        '${SubmissionTypes.label(s.text('submission_type') ?? '')} · '
                        '${s.text('reference_code') ?? ''} · '
                        '${Formatters.relative(s.text('created_at'))}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge(s.status),
              ],
            ),
            if (s.text('description') != null) ...<Widget>[
              const Gap.md(),
              Text(s.text('description')!, style: theme.textTheme.bodyMedium),
            ],
            const Gap.md(),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (s.text('submitter_name') != null)
                  _Fact(label: 'From', value: s.text('submitter_name')!),
                if (s.text('submitter_email') != null)
                  _Fact(label: 'Email', value: s.text('submitter_email')!),
                if (s.text('submitter_relationship') != null)
                  _Fact(label: 'Connection', value: s.text('submitter_relationship')!),
                if (s.text('youtube_url') != null)
                  _Fact(label: 'Video', value: s.text('youtube_url')!),
              ],
            ),
            if (_error != null) ...<Widget>[
              const Gap.sm(),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (canReview && s.status == ContentStatus.pendingReview) ...<Widget>[
              const Gap.lg(),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: _busy ? null : () => _review(ContentStatus.approved),
                    child: const Text('Approve'),
                  ),
                  const Gap.hMd(),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _review(ContentStatus.rejected),
                    child: const Text('Reject'),
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

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label: ', style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

/// THE CITATION LIBRARY.
///
/// Where the archive's claims come from. A source recorded once can be cited by
/// many records, and its reliability is stated rather than assumed.
class SourcesPage extends StatelessWidget {
  const SourcesPage({required this.workspace, super.key});
  final WorkspaceKind workspace;
  @override
  Widget build(BuildContext context) {
    final isAdmin = workspace == WorkspaceKind.admin;
    return WorkspaceShell(
      currentPath: isAdmin ? AppRoutes.adminSources : AppRoutes.editorialSources,
      title: 'Sources & references', workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: const SourcesManager(),
    );
  }
}

// ---------------------------------------------------------------------------
// Administration-only screens
// ---------------------------------------------------------------------------

/// The Editorial Team: who holds which editorial position.
class AdminEditorialTeamPage extends StatelessWidget {
  const AdminEditorialTeamPage({super.key});

  static const List<({String role, String title, String does, String cannot})> positions =
      <({String role, String title, String does, String cannot})>[
    (
      role: 'editorial_writer',
      title: 'Writer',
      does: 'Drafts content and submits it for review.',
      cannot: 'Approve or publish anything.',
    ),
    (
      role: 'editorial_editor',
      title: 'Editor',
      does: 'Edits all content, plus page text, navigation, the homepage, SEO and sources.',
      cannot: 'Approve or publish.',
    ),
    (
      role: 'editorial_reviewer',
      title: 'Reviewer',
      does: 'Approves or rejects submitted content, and reviews community submissions.',
      cannot: 'Publish — approval is not publication.',
    ),
    (
      role: 'editorial_publisher',
      title: 'Publisher',
      does: 'Publishes approved content to the public site, and can withdraw it.',
      cannot: 'Create or edit content, unless also given an editing role.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.adminEditorialTeam,
      title: 'Editorial Team',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminNote(
            message:
                'The Editorial Team runs the content of the website. None of these positions can '
                'manage users, change roles, alter security settings, read the audit log or delete '
                'content — those permissions are simply absent from them, and the API denies by '
                'default.\n\n'
                'Writing and publishing are separate on purpose: a volunteer can be trusted to '
                'draft without being able to put something on the public site alone.',
          ),
          const Gap.xxl(),
          ...positions.map(
            (({String role, String title, String does, String cannot}) position) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(position.title, style: theme.textTheme.titleMedium)),
                        Text(position.role, style: theme.textTheme.labelSmall),
                      ],
                    ),
                    const Gap.sm(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.check, size: 16, color: AppColors.green),
                        const Gap.hSm(),
                        Expanded(child: Text(position.does, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                    const Gap.xs(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.block, size: 16, color: AppColors.inkMuted),
                        const Gap.hSm(),
                        Expanded(child: Text(position.cannot, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Gap.xl(),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.adminUsers),
            icon: const Icon(Icons.people_outline, size: 18),
            label: const Text('Assign these roles to accounts'),
          ),
        ],
      ),
    );
  }
}

/// An overview of everything in the archive, by type and status.
class AdminContentPage extends StatelessWidget {
  const AdminContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.adminContent,
      title: 'Content',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: AsyncContent<DashboardSummary>(
        load: () => context.read<AdminRepository>().dashboard(),
        loadingMessage: 'Loading content counts…',
        builder: (BuildContext context, DashboardSummary summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AdminNote(
              message:
                  'Everything in the archive, by type and editorial status. Editing happens in the '
                  'Editorial workspace — this is the overview.',
            ),
            const Gap.xl(),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Draft'), numeric: true),
                    DataColumn(label: Text('Pending'), numeric: true),
                    DataColumn(label: Text('Published'), numeric: true),
                    DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: summary.content
                      .map(
                        (ContentTypeCount row) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(row.label)),
                            DataCell(Text('${row.drafts}')),
                            DataCell(Text('${row.pending}')),
                            DataCell(Text('${row.published}')),
                            DataCell(Text('${row.total}')),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const Gap.xl(),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.editorialDashboard),
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: const Text('Open the Editorial workspace'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Site settings.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => WorkspaceShell(
    currentPath: AppRoutes.adminSettings, title: 'Site settings',
    workspaceName: 'Administration', accent: AppColors.gold, navigation: adminNavigation,
    child: AsyncContent<Map<String, dynamic>>(
      load: () => context.read<SettingsRepository>().adminSettings(),
      loadingMessage: 'Loading settings…',
      builder: (context, data) => SettingsForm(groups: (data['groups'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
    ),
  );
}

/// The security posture of the platform, stated plainly.
class AdminSecurityPage extends StatelessWidget {
  const AdminSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({String title, String detail})> controls =
        <({String title, String detail})>[
      (
        title: 'Zero trust on every request',
        detail:
            'Each protected request is authenticated, resolved to a user, checked for role and '
            'granular permission, and denied by default. The decision is made by the Worker, never '
            'by the browser.',
      ),
      (
        title: 'Passwords',
        detail:
            'PBKDF2-HMAC-SHA256 with a per-user salt, at 100,000 iterations — the Cloudflare '
            'Workers runtime maximum.',
      ),
      (
        title: 'Sessions',
        detail:
            'Only a digest of the refresh token is stored, so a database snapshot cannot be '
            'replayed. Refreshing rotates the session, so a stolen token is usable at most once. '
            'Suspending an account or changing a password revokes every session immediately.',
      ),
      (
        title: 'Separation of duties',
        detail:
            'The Editorial Team cannot manage users, roles, security or settings, cannot read the '
            'audit log, and cannot delete content. Publishing is a separate permission from '
            'editing.',
      ),
      (
        title: 'Audit trail',
        detail:
            'Append-only. Every content change, moderation decision, role change and sign-in '
            'attempt is recorded. There is no code path that edits or deletes an entry.',
      ),
      (
        title: 'Secrets',
        detail:
            'Held only by the Worker as Cloudflare secrets. The browser bundle is downloaded by '
            'every visitor and contains no credential of any kind.',
      ),
      (
        title: 'Uploads',
        detail:
            'Checked against a per-folder type allow-list and size limit, and re-checked after '
            'reading rather than trusting what the browser reported.',
      ),
      (
        title: 'Personal data',
        detail:
            'IP addresses are stored only as a salted digest. A person\'s profile requires a '
            'recorded consent reference before it is published.',
      ),
    ];

    return WorkspaceShell(
      currentPath: AppRoutes.adminSecurity,
      title: 'Security',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminNote(
            message:
                'The controls protecting this archive. Rotate secrets with '
                '`wrangler secret put` — they are never editable from this interface, by design.',
          ),
          const Gap.xxl(),
          ...controls.map(
            (({String title, String detail}) control) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.shield_outlined, size: 20, color: AppColors.green),
                    const Gap.hLg(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(control.title, style: theme.textTheme.titleSmall),
                          const Gap.xs(),
                          Text(control.detail, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short explanatory panel used at the top of workspace screens.
class AdminNote extends StatelessWidget {
  const AdminNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}
