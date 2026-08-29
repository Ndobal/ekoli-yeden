import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/seo_head.dart';
import '../../services/auth/auth_controller.dart';

/// The shell shared by every Editorial Team screen.
///
/// Deliberately a different interface from the Super Admin area. There is no
/// user management here, no roles, no security, no audit log, no infrastructure
/// and no secrets — an editorial account has no business seeing any of it, and
/// this sidebar does not offer it.
class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({
    required this.child,
    required this.currentPath,
    required this.title,
    required this.navigation,
    required this.workspaceName,
    required this.accent,
    this.actions = const <Widget>[],
    super.key,
  });

  final Widget child;
  final String currentPath;
  final String title;
  final List<NavItem> navigation;

  /// "Editorial" or "Administration" — shown so nobody is in any doubt which
  /// area they are working in.
  final String workspaceName;

  final Color accent;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // Matches the member shell: `laptop` (1240) is wider than many laptops,
    // so a desktop user was given a hamburger.
    final bool wide = context.screenWidth >= Breakpoints.tablet;

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: Text(title),
              backgroundColor: accent,
              foregroundColor: Colors.white,
              actions: actions,
            ),
      bottomNavigationBar: wide
          ? null
          : _WorkspaceBottomBar(
              navigation: navigation,
              currentPath: currentPath,
              accent: accent,
            ),
      drawer: wide
          ? null
          : Drawer(
              child: _Sidebar(
                currentPath: currentPath,
                navigation: navigation,
                workspaceName: workspaceName,
                accent: accent,
                closeOnTap: true,
              ),
            ),
      body: SeoHead(
        // The workspace is not a public page; it should never be indexed.
        metadata: SeoMetadata(title: '$title · $workspaceName'),
        child: Row(
          children: <Widget>[
            if (wide)
              SizedBox(
                width: 268,
                child: _Sidebar(
                  currentPath: currentPath,
                  navigation: navigation,
                  workspaceName: workspaceName,
                  accent: accent,
                  closeOnTap: false,
                ),
              ),
            Expanded(
              child: Column(
                children: <Widget>[
                  if (wide) _TopBar(title: title, actions: actions),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: child,
                    ),
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

/// THE BOTTOM BAR IN THE WORKSPACES — PHONES ONLY.
///
/// The member area got one and the Editorial and Administration areas did not,
/// so a Super Admin on a phone had a hamburger and nothing else while an
/// ordinary member had their tools under the thumb. Somebody moderating from a
/// phone at a festival is exactly the person who needs this most.
///
/// The four destinations come from whichever navigation list the workspace was
/// given, in the order it already puts them — those lists are ordered by
/// importance, so the first four are the right four — and `More` opens the
/// same drawer as the hamburger, so there is one list of the workspace's
/// screens rather than two that drift apart.
class _WorkspaceBottomBar extends StatelessWidget {
  const _WorkspaceBottomBar({
    required this.navigation,
    required this.currentPath,
    required this.accent,
  });

  final List<NavItem> navigation;
  final String currentPath;
  final Color accent;

  /// Icons by destination, with a sensible fallback.
  ///
  /// Kept here rather than on `NavItem` because only this bar needs them, and
  /// a field on the shared model would have to be filled in for sixty entries
  /// that will never appear in a bottom bar.
  static IconData _iconFor(NavItem item) {
    final String label = item.label.toLowerCase();
    if (label.contains('overview') || label.contains('dashboard')) {
      return Icons.dashboard_outlined;
    }
    if (label.contains('user')) return Icons.people_outline;
    if (label.contains('role') || label.contains('permission')) return Icons.key_outlined;
    if (label.contains('team')) return Icons.groups_outlined;
    if (label.contains('content')) return Icons.article_outlined;
    if (label.contains('submission') || label.contains('sent in')) {
      return Icons.inbox_outlined;
    }
    if (label.contains('media') || label.contains('file')) return Icons.perm_media_outlined;
    if (label.contains('news')) return Icons.newspaper_outlined;
    if (label.contains('gallery') || label.contains('photograph')) {
      return Icons.photo_library_outlined;
    }
    if (label.contains('setting')) return Icons.settings_outlined;
    if (label.contains('security') || label.contains('audit')) return Icons.shield_outlined;
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<NavItem> primary = navigation.take(4).toList(growable: false);
    if (primary.isEmpty) return const SizedBox.shrink();

    int selected = primary.length; // `More`, when nothing else matches.
    for (int i = 0; i < primary.length; i++) {
      final String path = primary[i].path;
      if (currentPath == path || currentPath.startsWith('$path/')) {
        selected = i;
        break;
      }
    }

    return NavigationBar(
      selectedIndex: selected,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: accent.withValues(alpha: 0.18),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 66,
      onDestinationSelected: (int index) {
        if (index == primary.length) {
          Scaffold.of(context).openDrawer();
          return;
        }
        context.go(primary[index].path);
      },
      destinations: <Widget>[
        for (final NavItem item in primary)
          NavigationDestination(
            icon: Icon(_iconFor(item)),
            selectedIcon: Icon(_iconFor(item), color: accent),
            // Bottom-bar labels have to fit under an icon on a small phone.
            label: item.label.split(' ').first,
          ),
        NavigationDestination(
          icon: const Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu, color: accent),
          label: 'More',
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
          ...actions,
        ],
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.currentPath,
    required this.navigation,
    required this.workspaceName,
    required this.accent,
    required this.closeOnTap,
  });

  final String currentPath;
  final List<NavItem> navigation;
  final String workspaceName;
  final Color accent;
  final bool closeOnTap;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  /// What the sidebar shows once something has been typed.
  ///
  /// Matches the label AND the description, because somebody looking for the
  /// place to review a photograph will type "photograph" long before they
  /// remember it is called "Contributed files".
  List<NavItem> get _visible {
    if (_query.isEmpty) return widget.navigation;
    final String needle = _query.toLowerCase();
    return widget.navigation
        .where(
          (NavItem item) =>
              item.label.toLowerCase().contains(needle) ||
              (item.description ?? '').toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final String workspaceName = widget.workspaceName;
    final Color accent = widget.accent;
    final String currentPath = widget.currentPath;
    final bool closeOnTap = widget.closeOnTap;
    final List<NavItem> navigation = _visible;

    return Container(
      color: AppColors.navyDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  const BrandLogo(size: 40, onDarkBackground: true),
                  const Gap.hMd(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Ekoli Yeden',
                          style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
                        ),
                        Text(
                          workspaceName,
                          style: theme.textTheme.labelSmall?.copyWith(color: accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),

            // A filter rather than a link list to scroll.
            //
            // The administration sidebar has grown past twenty entries, which
            // is well past the point where finding one by eye is slower than
            // typing three letters of it.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _filter,
                onChanged: (String value) => setState(() => _query = value.trim()),
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search this menu',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          onPressed: () {
                            _filter.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            Expanded(
              child: navigation.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Nothing in this menu matches “$_query”.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: navigation.map((NavItem item) {
                  final bool active = currentPath == item.path;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    child: Material(
                      color: active ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
                      borderRadius: AppRadius.smAll,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: active ? Colors.white : Colors.white.withValues(alpha: 0.75),
                            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        subtitle: item.description == null
                            ? null
                            : Text(
                                item.description!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                        onTap: () {
                          if (closeOnTap) Navigator.of(context).pop();
                          context.go(item.path);
                        },
                      ),
                    ),
                  );
                      }).toList(growable: false),
                    ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (auth.user != null) ...<Widget>[
                    Text(
                      auth.user!.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                    Text(
                      auth.user!.roleSummary,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const Gap.sm(),
                  ],
                  // The way back to your own account.
                  //
                  // A workspace used to offer "View site" and sign out, and
                  // nothing else — so somebody who had switched into
                  // Administration could reach the public website or leave, but
                  // not return to their own dashboard. The switcher in the
                  // member sidebar goes one way; this is the other.
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.account),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('My account'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.home),
                        icon: const Icon(Icons.public, size: 16),
                        label: const Text('View site'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.skyBlue),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18),
                        tooltip: 'Sign out',
                        color: Colors.white70,
                        onPressed: () async {
                          await auth.signOut();
                          if (context.mounted) context.go(AppRoutes.home);
                        },
                      ),
                    ],
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

/// A single figure on a dashboard.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.accent = AppColors.navy,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: accent),
              const Gap.md(),
            ],
            Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(color: accent),
            ),
            const Gap.xs(),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
