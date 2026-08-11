import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/async_content.dart';
import '../features/editorial/editorial_shell.dart';
import '../repositories/admin_repository.dart';
import '../services/auth/auth_controller.dart';

/// THE SUPER ADMIN DASHBOARD.
///
/// A different interface from the Editorial workspace, reached at a different
/// address, showing things an editorial account never sees: accounts, roles,
/// the audit trail, security posture and system settings.
///
/// The separation is enforced on the server — an editorial token is refused at
/// every `/api/admin/*` endpoint — so this screen is the visible half of a
/// boundary that already exists in the API.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    return WorkspaceShell(
      currentPath: AppRoutes.adminDashboard,
      title: 'System Overview',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: AsyncContent<DashboardSummary>(
        load: () => context.read<AdminRepository>().dashboard(),
        loadingMessage: 'Loading the system overview…',
        builder: (BuildContext context, DashboardSummary summary) =>
            _Overview(summary: summary, auth: auth),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary, required this.auth});

  final DashboardSummary summary;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Welcome, ${auth.user?.displayName ?? 'administrator'}',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            _EnvironmentBadge(environment: summary.environment),
          ],
        ),
        const Gap.xs(),
        Text(
          'Administration of the platform: accounts, roles, security and settings.',
          style: theme.textTheme.bodyMedium,
        ),
        const Gap.xxl(),

        // On a fresh installation every figure is zero, which is correct but
        // reads as broken unless it is explained.
        if (summary.archiveIsEmpty) ...<Widget>[
          const _EmptyArchiveNote(),
          const Gap.xxl(),
        ],

        _Tiles(
          children: <Widget>[
            StatTile(
              label: 'Published records',
              value: '${summary.publishedRecords}',
              icon: Icons.public,
              accent: AppColors.green,
            ),
            StatTile(
              label: 'Awaiting review',
              value: '${summary.awaitingReview}',
              icon: Icons.pending_actions_outlined,
              accent: AppColors.warning,
              onTap: () => context.go(AppRoutes.adminSubmissions),
            ),
            StatTile(
              label: 'Community submissions',
              value: '${summary.pendingSubmissions}',
              icon: Icons.inbox_outlined,
              accent: AppColors.navy,
              onTap: () => context.go(AppRoutes.adminSubmissions),
            ),
            StatTile(
              label: 'Registered accounts',
              value: '${summary.registeredUsers}',
              icon: Icons.people_outline,
              accent: AppColors.navyLight,
              onTap: () => context.go(AppRoutes.adminUsers),
            ),
          ],
        ),
        const Gap.xxl(),

        Text('Media library', style: theme.textTheme.headlineSmall),
        const Gap.md(),
        if (summary.media.isEmpty)
          Text('No files have been uploaded yet.', style: theme.textTheme.bodyMedium)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: summary.media.entries
                .map(
                  (MapEntry<String, int> entry) => Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                  ),
                )
                .toList(growable: false),
          ),
        const Gap.xxl(),

        Text('Administration', style: theme.textTheme.headlineSmall),
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            _AdminAction(
              label: 'Users',
              description: 'Accounts and their roles',
              icon: Icons.people_outline,
              onTap: () => context.go(AppRoutes.adminUsers),
            ),
            _AdminAction(
              label: 'Roles & permissions',
              description: 'What each role may do',
              icon: Icons.key_outlined,
              onTap: () => context.go(AppRoutes.adminRoles),
            ),
            _AdminAction(
              label: 'Audit log',
              description: 'Everything that has been changed, and by whom',
              icon: Icons.receipt_long_outlined,
              onTap: () => context.go(AppRoutes.adminAuditLogs),
            ),
            _AdminAction(
              label: 'Editorial workspace',
              description: 'The content side of the platform',
              icon: Icons.edit_note_outlined,
              onTap: () => context.go(AppRoutes.editorialDashboard),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final int columns = context.responsive<int>(mobile: 2, tablet: 2, laptop: 4, desktop: 4);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((Widget child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge({required this.environment});

  final String environment;

  @override
  Widget build(BuildContext context) {
    final bool production = environment == 'production';
    final Color color = production ? AppColors.danger : AppColors.inkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        environment.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 1),
      ),
    );
  }
}

class _EmptyArchiveNote extends StatelessWidget {
  const _EmptyArchiveNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('The archive is empty — this is expected', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          Text(
            'Nothing has been published yet, so every figure above is zero. The platform is '
            'complete and waiting for material; no history, leadership record, language entry or '
            'photograph has been invented to fill it.\n\n'
            'The first steps are to create accounts for the Preservation Team, grant them their '
            'roles, and let them begin entering verified material.',
            style: theme.textTheme.bodyMedium,
          ),
          const Gap.md(),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.adminUsers),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Create the first team accounts'),
          ),
        ],
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: AppColors.gold),
              const Gap.hMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.titleSmall),
                    const Gap.xs(),
                    Text(description, style: theme.textTheme.bodySmall),
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

/// A small helper used by several admin screens.
class AdminSectionNote extends StatelessWidget {
  const AdminSectionNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}

/// Shown where a screen is deliberately not yet built out.
class AdminPlaceholder extends StatelessWidget {
  const AdminPlaceholder({
    required this.title,
    required this.explanation,
    required this.path,
    super.key,
  });

  final String title;
  final String explanation;
  final String path;

  @override
  Widget build(BuildContext context) {
    return WorkspaceShell(
      currentPath: path,
      title: title,
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminSectionNote(message: explanation),
          if (AppConfig.isDevelopment) ...<Widget>[
            const Gap.lg(),
            Text(
              'The API for this section already exists and is protected. '
              'The interface is added in a later module.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
