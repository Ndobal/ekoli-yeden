import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/async_content.dart';
import '../../models/content_status.dart';
import '../../repositories/cms_repository.dart';
import '../../services/auth/auth_controller.dart';
import 'editorial_shell.dart';

/// THE EDITORIAL DASHBOARD.
///
/// What the Editorial Team sees when they sign in: how much is in draft, how
/// much is waiting for review, how much is live, and how much has come back for
/// revision.
///
/// No Cloudflare dashboard. No database console. No secrets. No user
/// management. The server does not send any of it to this endpoint, and the
/// sidebar does not offer a way to ask.
class EditorialDashboard extends StatelessWidget {
  const EditorialDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    return WorkspaceShell(
      currentPath: AppRoutes.editorialDashboard,
      title: 'Editorial Dashboard',
      workspaceName: 'Editorial',
      accent: AppColors.skyBlue,
      navigation: editorialNavigation,
      child: AsyncContent<Map<String, dynamic>>(
        load: () => context.read<CmsRepository>().editorialDashboard(),
        loadingMessage: 'Loading your dashboard…',
        builder: (BuildContext context, Map<String, dynamic> data) =>
            _Dashboard(data: data, auth: auth),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, required this.auth});

  final Map<String, dynamic> data;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, dynamic> summary =
        (data['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> websiteText =
        (data['websiteText'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> capabilities =
        (data['capabilities'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Welcome, ${auth.user?.displayName ?? 'colleague'}',
          style: theme.textTheme.headlineMedium,
        ),
        const Gap.xs(),
        Text(
          'You are working on the content of the public website.',
          style: theme.textTheme.bodyMedium,
        ),
        const Gap.xxl(),

        _StatRow(
          tiles: <Widget>[
            StatTile(
              label: 'Drafts',
              value: '${Json.intVal(summary, 'drafts')}',
              icon: Icons.edit_note_outlined,
              accent: AppColors.inkMuted,
            ),
            StatTile(
              label: 'Pending review',
              value: '${Json.intVal(summary, 'pendingReview')}',
              icon: Icons.pending_actions_outlined,
              accent: AppColors.warning,
            ),
            StatTile(
              label: 'Published',
              value: '${Json.intVal(summary, 'published')}',
              icon: Icons.public,
              accent: AppColors.green,
            ),
            StatTile(
              label: 'Needs revision',
              value: '${Json.intVal(summary, 'needsRevision')}',
              icon: Icons.replay_outlined,
              accent: AppColors.danger,
            ),
          ],
        ),
        const Gap.xxl(),

        // Spelling out what this person may do removes the main frustration of
        // a layered workflow: discovering you cannot publish only after writing.
        _CapabilityNote(capabilities: capabilities),
        const Gap.xxl(),

        Text('Website text', style: theme.textTheme.headlineSmall),
        const Gap.sm(),
        Text(
          'Every heading, paragraph, button label and notice on the public site. '
          'Changing them here does not require a developer or a deployment.',
          style: theme.textTheme.bodyMedium,
        ),
        const Gap.lg(),
        _StatRow(
          tiles: <Widget>[
            StatTile(
              label: 'Text drafts saved',
              value: '${Json.intVal(websiteText, 'drafts')}',
              accent: AppColors.inkMuted,
            ),
            StatTile(
              label: 'Text awaiting review',
              value: '${Json.intVal(websiteText, 'pendingReview')}',
              accent: AppColors.warning,
            ),
            StatTile(
              label: 'Text live on the site',
              value: '${Json.intVal(websiteText, 'published')}',
              accent: AppColors.green,
            ),
          ],
        ),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.editorialHomepage),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Edit the homepage'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.editorialPages),
              icon: const Icon(Icons.text_fields, size: 18),
              label: const Text('Edit all website text'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.editorialSources),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('Sources & references'),
            ),
          ],
        ),
        const Gap.xxl(),

        Text('Content', style: theme.textTheme.headlineSmall),
        const Gap.lg(),
        _ContentTable(rows: Json.objectList(data, 'content')),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final int columns = context.responsive<int>(mobile: 2, tablet: 2, laptop: 4, desktop: 4);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int effective = columns > tiles.length ? tiles.length : columns;
        final double width =
            (constraints.maxWidth - AppSpacing.md * (effective - 1)) / effective;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: tiles
              .map((Widget tile) => SizedBox(width: width, child: tile))
              .toList(growable: false),
        );
      },
    );
  }
}

/// States plainly what this account can and cannot do.
class _CapabilityNote extends StatelessWidget {
  const _CapabilityNote({required this.capabilities});

  final Map<String, dynamic> capabilities;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canPublish = Json.boolVal(capabilities, 'canPublish');
    final bool canReview = Json.boolVal(capabilities, 'canReview');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What you can do', style: theme.textTheme.titleSmall),
          const Gap.sm(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Capability(label: 'Create', granted: Json.boolVal(capabilities, 'canCreate')),
              _Capability(label: 'Edit', granted: Json.boolVal(capabilities, 'canEdit')),
              _Capability(label: 'Submit for review', granted: Json.boolVal(capabilities, 'canSubmit')),
              _Capability(label: 'Approve or reject', granted: canReview),
              _Capability(label: 'Publish', granted: canPublish),
              _Capability(label: 'Edit page text', granted: Json.boolVal(capabilities, 'canEditPages')),
              _Capability(label: 'Edit navigation', granted: Json.boolVal(capabilities, 'canEditNavigation')),
              _Capability(label: 'Manage sources', granted: Json.boolVal(capabilities, 'canManageSources')),
            ],
          ),
          if (!canPublish) ...<Widget>[
            const Gap.md(),
            Text(
              'Publishing is a separate permission, held by a Publisher. Submit your work for '
              'review and somebody with that authority will take it live.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final Color color = granted ? AppColors.green : AppColors.inkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: granted ? 0.10 : 0.05),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(granted ? Icons.check : Icons.remove, size: 14, color: color),
          const Gap.hSm(),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ContentTable extends StatelessWidget {
  const _ContentTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (rows.isEmpty) {
      return Text(
        'You do not currently have access to any content types.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      // Wide tables scroll inside their own box rather than pushing the page
      // sideways, which would break the layout on a phone.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Content type')),
            DataColumn(label: Text('Drafts'), numeric: true),
            DataColumn(label: Text('Pending'), numeric: true),
            DataColumn(label: Text('Approved'), numeric: true),
            DataColumn(label: Text('Published'), numeric: true),
            DataColumn(label: Text('Rejected'), numeric: true),
          ],
          rows: rows
              .map(
                (Map<String, dynamic> row) => DataRow(
                  cells: <DataCell>[
                    DataCell(Text(Json.str(row, 'label'))),
                    DataCell(Text('${Json.intVal(row, 'drafts')}')),
                    DataCell(Text('${Json.intVal(row, 'pendingReview')}')),
                    DataCell(Text('${Json.intVal(row, 'approved')}')),
                    DataCell(Text('${Json.intVal(row, 'published')}')),
                    DataCell(Text('${Json.intVal(row, 'rejected')}')),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
