import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/routing/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/async_content.dart';
import '../core/widgets/state_views.dart';
import '../features/editorial/editorial_shell.dart';
import 'admin_dashboard.dart' show AdminSectionNote;
import '../models/content_record.dart';
import '../models/content_status.dart';
import '../repositories/admin_repository.dart';
import 'user_actions.dart';
import '../services/api/api_response.dart';

/// ACCOUNTS, THE ROLES THEY HOLD, AND THE TWO WAYS BACK INTO ONE.
///
/// ---------------------------------------------------------------------------
/// WHY BOTH A LINK AND A TEMPORARY PASSWORD
/// ---------------------------------------------------------------------------
///
/// A reset link is the better mechanism and stays the default: no administrator
/// ever learns anybody's password. But it assumes the person can receive and
/// open a link, and that is not always true — an elder on a borrowed phone,
/// somebody whose email stopped working years ago, somebody standing in front
/// of an administrator right now.
///
/// So there are two. The temporary password is not a shared password: the
/// account must replace it before it can do anything else, and every existing
/// session on that account ends the moment it is issued. Knowing it buys
/// exactly one thing — the right to choose a real one.
///
/// Both are shown once, on this screen, and never stored on this side.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  int _reloads = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.adminUsers,
      title: 'Users',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: AsyncContent<PaginatedResult<ContentRecord>>(
        key: ValueKey<int>(_reloads),
        load: () => context.read<AdminRepository>().users(perPage: 100),
        loadingMessage: 'Loading accounts…',
        builder: (BuildContext context, PaginatedResult<ContentRecord> result) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${result.total} account${result.total == 1 ? '' : 's'}',
              style: theme.textTheme.bodyMedium,
            ),
            const Gap.lg(),
            if (result.isEmpty)
              const EmptyView(
                icon: Icons.people_outline,
                title: 'No accounts yet',
                message: 'Create accounts for the Preservation Team to begin filling the archive.',
                showContributeAction: false,
              )
            else
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
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Roles')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Last signed in')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: result.items
                        .map(
                          (ContentRecord user) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(user.text('display_name') ?? '—')),
                              DataCell(Text(user.text('email') ?? '—')),
                              DataCell(
                                Text(
                                  Json.stringList(user.raw, 'roles').join(', '),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              DataCell(Text(user.text('status') ?? '—')),
                              DataCell(
                                Text(Formatters.relative(user.text('last_login_at'), fallback: 'never')),
                              ),
                              DataCell(
                                UserActions(
                                  userId: user.text('id') ?? '',
                                  name: user.text('display_name') ?? user.text('email') ?? '',
                                  status: user.text('status') ?? 'active',
                                  roles: Json.stringList(user.raw, 'roles'),
                                  onDone: () => setState(() => _reloads += 1),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            const Gap.xxl(),
            const AdminSectionNote(
              message:
                  'When somebody uses "forgot password", every Super Admin is told here whether '
                  'the link actually reached them — and if it did not, the notification carries '
                  'the link so you can pass it on. Accounts are still created and roles assigned '
                  'through the API; those endpoints are protected by the users.manage and '
                  'roles.manage permissions.',
            ),
          ],
        ),
      ),
    );
  }
}

/// The roles and exactly what each one may do.
///
/// Worth showing in full: it is how an administrator confirms that the
/// Editorial Team really cannot reach administration.
class AdminRolesPage extends StatelessWidget {
  const AdminRolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.adminRoles,
      title: 'Roles & permissions',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: AsyncContent<RolesResponse>(
        load: () => context.read<AdminRepository>().roles(),
        loadingMessage: 'Loading roles…',
        builder: (BuildContext context, RolesResponse response) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AdminSectionNote(
              message:
                  'Permissions are enforced by the Worker on every request. Hiding a control in '
                  'the interface is a courtesy; the API is what actually refuses.',
            ),
            const Gap.xxl(),
            ...response.roles.map(
              (RoleDefinition role) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
                          Expanded(child: Text(role.name, style: theme.textTheme.titleMedium)),
                          Text(
                            '${role.permissions.length} permission'
                            '${role.permissions.length == 1 ? '' : 's'}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (role.description != null) ...<Widget>[
                        const Gap.xs(),
                        Text(role.description!, style: theme.textTheme.bodySmall),
                      ],
                      const Gap.md(),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: role.permissions
                            .map(
                              (String permission) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: permission == '*'
                                      ? AppColors.danger.withValues(alpha: 0.10)
                                      : theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: AppRadius.xsAll,
                                ),
                                child: Text(
                                  permission == '*' ? '* (everything)' : permission,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: permission == '*' ? AppColors.danger : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The audit trail.
class AdminAuditLogPage extends StatelessWidget {
  const AdminAuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.adminAuditLogs,
      title: 'Audit log',
      workspaceName: 'Administration',
      accent: AppColors.gold,
      navigation: adminNavigation,
      child: AsyncContent<PaginatedResult<ContentRecord>>(
        load: () => context.read<AdminRepository>().auditLogs(perPage: 100),
        loadingMessage: 'Loading the audit trail…',
        isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
        emptyBuilder: (BuildContext context) => const EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'Nothing recorded yet',
          message: 'Content changes, moderation decisions and role changes appear here as they happen.',
          showContributeAction: false,
        ),
        builder: (BuildContext context, PaginatedResult<ContentRecord> result) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AdminSectionNote(
              message:
                  'Every content change, moderation decision, role change and sign-in attempt is '
                  'recorded here. The log is append-only — there is no code path that edits or '
                  'deletes an entry.',
            ),
            const Gap.xl(),
            ...result.items.map(
              (ContentRecord entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 150,
                        child: Text(
                          Formatters.dateTime(entry.text('created_at')),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.text('action') ?? '—',
                              style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
                            ),
                            const Gap.xs(),
                            Text(
                              '${entry.text('actor_email') ?? 'anonymous'} · '
                              '${entry.text('resource_type') ?? '—'}',
                              style: theme.textTheme.bodySmall,
                            ),
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
      ),
    );
  }
}
