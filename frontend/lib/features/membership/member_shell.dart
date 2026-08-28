/// THE INDIGENE DASHBOARD SHELL.
///
/// ---------------------------------------------------------------------------
/// WHY A SHELL OF ITS OWN
/// ---------------------------------------------------------------------------
///
/// A signed-in member used to browse the archive inside the public scaffold:
/// the same top navigation as a visitor — History, Culture, Language, Gallery,
/// Festivals — with their own account tucked behind an avatar menu. Everything
/// they had actually signed in to do was two or three clicks inside a menu that
/// was mostly about something else.
///
/// This shell inverts that. The sidebar carries only the member's own tools,
/// each one reachable in a single click, and the whole public archive collapses
/// into one link at the bottom: *Return to the website*. A member here is
/// working, not browsing; when they want to browse, they say so.
///
/// ---------------------------------------------------------------------------
/// ON THE COLOURS
/// ---------------------------------------------------------------------------
///
/// The layout follows the dashboard design supplied: a full-height coloured
/// sidebar with an active pill, a search-forward top bar, and a canvas of
/// rounded white cards on a tinted ground.
///
/// The colours are the archive's own — navy and gold from `app_colors.dart` —
/// rather than the reference's purple. The sidebar plays exactly the same
/// structural role in navy, and a member who follows *Return to the website*
/// should not feel they have crossed into a different product.
library;

import 'dart:async';

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
import '../../repositories/message_repository.dart';
import '../../services/auth/auth_controller.dart';

/// One destination in the member's sidebar.
class MemberNavItem {
  const MemberNavItem({
    required this.label,
    required this.path,
    required this.icon,
    this.badgeKey,
  });

  final String label;
  final String path;
  final IconData icon;

  /// Which live count, if any, sits on this row.
  final String? badgeKey;
}

/// The member's own tools, and nothing else.
///
/// Deliberately short. Every row here is something a member does, and anything
/// that is a thing to *read* lives on the website behind the single link at the
/// foot of the sidebar.
const List<MemberNavItem> memberNavigation = <MemberNavItem>[
  MemberNavItem(label: 'Dashboard', path: AppRoutes.account, icon: Icons.dashboard_outlined),
  MemberNavItem(
    label: 'Opportunities',
    path: AppRoutes.opportunities,
    icon: Icons.work_outline,
  ),
  MemberNavItem(
    label: 'Messages',
    path: AppRoutes.messages,
    icon: Icons.forum_outlined,
    badgeKey: 'messages',
  ),
  MemberNavItem(label: 'Directory', path: AppRoutes.directory, icon: Icons.contacts_outlined),
  MemberNavItem(label: 'Forums', path: AppRoutes.forums, icon: Icons.groups_outlined),
  MemberNavItem(
    label: 'Contribute',
    path: AppRoutes.contribute,
    icon: Icons.cloud_upload_outlined,
  ),
  MemberNavItem(label: 'Family', path: AppRoutes.accountFamily, icon: Icons.family_restroom),
  MemberNavItem(label: 'Birthdays', path: AppRoutes.accountBirthdays, icon: Icons.cake_outlined),
  MemberNavItem(
    label: 'Notifications',
    path: AppRoutes.accountNotifications,
    icon: Icons.notifications_none,
  ),
  MemberNavItem(label: 'My profile', path: AppRoutes.accountProfile, icon: Icons.person_outline),
  MemberNavItem(label: 'Privacy', path: AppRoutes.accountPrivacy, icon: Icons.lock_outline),
];

/// The member page a path belongs to, or null when it is an ordinary page of
/// the website.
///
/// Used by `AppScaffold` to decide whether a signed-in visitor is browsing the
/// archive or working in their own area. Longest match wins, so
/// `/account/profile` resolves to My profile rather than to Dashboard.
MemberNavItem? memberPageFor(String path) {
  MemberNavItem? best;
  for (final MemberNavItem item in memberNavigation) {
    if (item.path.isEmpty) continue;
    final bool hit = path == item.path || path.startsWith('${item.path}/');
    if (!hit) continue;
    if (best == null || item.path.length > best.path.length) best = item;
  }

  // Posting an opportunity is a member's own page even though it sits under a
  // public section — it is one of the things they signed in to do.
  if (best == null && path == AppRoutes.postOpportunity) {
    return const MemberNavItem(
      label: 'Post an opportunity',
      path: AppRoutes.postOpportunity,
      icon: Icons.campaign_outlined,
    );
  }
  return best;
}

class MemberShell extends StatelessWidget {
  const MemberShell({
    required this.child,
    required this.currentPath,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.searchHint,
    this.onSearch,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// When given, the top bar carries a search field, as the reference does.
  final String? searchHint;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    // The sidebar is open by default on anything desktop-shaped.
    //
    // `Breakpoints.laptop` is 1240, which is wider than a great many laptops
    // actually are — a 1366 screen with the browser not maximised falls under
    // it, and the member got a hamburger on a desktop. `tablet` (905) is the
    // point at which a 262px sidebar still leaves a usable column beside it.
    final bool wide = context.screenWidth >= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              title: Text(title),
              actions: actions,
            ),
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AppColors.navy,
              child: _Sidebar(currentPath: currentPath, closeOnTap: true),
            ),
      // On a phone the four most-used tools sit under the thumb, and `More`
      // opens the rest as the app drawer. A member on a phone should not have
      // to find a hamburger to answer a message.
      bottomNavigationBar: wide ? null : const _BottomBar(),
      body: SeoHead(
        // A member's own dashboard is never indexed.
        metadata: SeoMetadata(title: '$title · Ekoli-Yeden', noIndex: true),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (wide)
              const SizedBox(
                width: 262,
                child: _Sidebar(currentPath: '', closeOnTap: false),
              ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _TopBar(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                    searchHint: searchHint,
                    onSearch: onSearch,
                    showMenuButton: !wide,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? AppSpacing.xxl : AppSpacing.lg),
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

// ---------------------------------------------------------------------------
// The bottom bar — phones only
// ---------------------------------------------------------------------------

/// The four things a member reaches for most, plus a door to everything else.
///
/// Four and not five: the fifth slot is `More`, and a bottom bar that is all
/// destinations and no overflow either hides the rest of the product or grows
/// until the labels are unreadable.
///
/// `More` opens the same sidebar as the drawer, so there is one list of the
/// member's tools rather than two that drift apart.
const List<MemberNavItem> _bottomBarItems = <MemberNavItem>[
  MemberNavItem(label: 'Home', path: AppRoutes.account, icon: Icons.dashboard_outlined),
  MemberNavItem(label: 'Jobs', path: AppRoutes.opportunities, icon: Icons.work_outline),
  MemberNavItem(
    label: 'Messages',
    path: AppRoutes.messages,
    icon: Icons.forum_outlined,
    badgeKey: 'messages',
  ),
  MemberNavItem(label: 'People', path: AppRoutes.directory, icon: Icons.contacts_outlined),
];

class _BottomBar extends StatefulWidget {
  const _BottomBar();

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
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
    final ThemeData theme = Theme.of(context);
    final String location = GoRouterState.of(context).uri.path;

    int selected = _bottomBarItems.length; // `More`, when nothing else matches.
    for (int i = 0; i < _bottomBarItems.length; i++) {
      final String path = _bottomBarItems[i].path;
      final bool hit = path == AppRoutes.account
          ? location == AppRoutes.account
          : location == path || location.startsWith('$path/');
      if (hit) {
        selected = i;
        break;
      }
    }

    return NavigationBar(
      selectedIndex: selected,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: AppColors.navy.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 66,
      onDestinationSelected: (int index) {
        if (index == _bottomBarItems.length) {
          Scaffold.of(context).openDrawer();
          return;
        }
        context.go(_bottomBarItems[index].path);
      },
      destinations: <Widget>[
        for (final MemberNavItem item in _bottomBarItems)
          NavigationDestination(
            icon: item.badgeKey == 'messages' && _unread > 0
                ? Badge.count(count: _unread, child: Icon(item.icon))
                : Icon(item.icon),
            selectedIcon: Icon(item.icon, color: AppColors.navy),
            label: item.label,
          ),
        const NavigationDestination(
          icon: Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu, color: AppColors.navy),
          label: 'More',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatefulWidget {
  const _Sidebar({required this.currentPath, required this.closeOnTap});

  final String currentPath;
  final bool closeOnTap;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  int _unreadMessages = 0;
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
    if (!context.read<AuthController>().isSignedIn) return;
    try {
      final int unread = await context.read<MessageRepository>().unread();
      if (mounted) setState(() => _unreadMessages = unread);
    } catch (_) {
      // A badge is not worth an error state.
    }
  }

  bool get closeOnTap => widget.closeOnTap;

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    // The wide layout passes an empty path and reads the live location, so the
    // active pill follows the router rather than whatever a page declared.
    final String location = GoRouterState.of(context).uri.path;

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Row(
                children: <Widget>[
                  const BrandLogo(size: 38, onDarkBackground: true),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ekoli-Yeden',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: <Widget>[
                  for (final MemberNavItem item in memberNavigation)
                    _NavRow(
                      item: item,
                      badge: item.badgeKey == 'messages' ? _unreadMessages : 0,
                      selected: _isSelected(location, item.path),
                      onTap: () {
                        if (closeOnTap) Navigator.of(context).pop();
                        context.go(item.path);
                      },
                    ),

                  // The workspaces, for the few members who also hold a role.
                  // Shown only when they do, so an ordinary member's sidebar
                  // stays the length it should be.
                  if (auth.canAccessEditorial || auth.canAccessAdmin) ...<Widget>[
                    const _SidebarDivider(),
                    if (auth.canAccessEditorial)
                      _NavRow(
                        item: const MemberNavItem(
                          label: 'Editorial',
                          path: AppRoutes.editorialDashboard,
                          icon: Icons.edit_note_outlined,
                        ),
                        badge: 0,
                        selected: location.startsWith('/editorial'),
                        onTap: () {
                          if (closeOnTap) Navigator.of(context).pop();
                          context.go(AppRoutes.editorialDashboard);
                        },
                      ),
                    if (auth.canAccessAdmin)
                      _NavRow(
                        item: const MemberNavItem(
                          label: 'Administration',
                          path: AppRoutes.adminDashboard,
                          icon: Icons.shield_outlined,
                        ),
                        badge: 0,
                        selected: location.startsWith('/admin'),
                        onTap: () {
                          if (closeOnTap) Navigator.of(context).pop();
                          context.go(AppRoutes.adminDashboard);
                        },
                      ),
                  ],
                ],
              ),
            ),

            // The whole public archive, behind one link.
            const _SidebarDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _NavRow(
                    item: const MemberNavItem(
                      label: 'Return to the website',
                      path: AppRoutes.home,
                      icon: Icons.public,
                    ),
                    badge: 0,
                    selected: false,
                    onTap: () {
                      if (closeOnTap) Navigator.of(context).pop();
                      context.go(AppRoutes.home);
                    },
                  ),
                  _NavRow(
                    item: const MemberNavItem(
                      label: 'Sign out',
                      path: '',
                      icon: Icons.logout,
                    ),
                    badge: 0,
                    selected: false,
                    onTap: () async {
                      if (closeOnTap) Navigator.of(context).pop();
                      await context.read<AuthController>().signOut();
                      if (context.mounted) context.go(AppRoutes.home);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `/account` must not light up for `/account/profile`, but `/messages/12`
  /// should keep Messages lit.
  static bool _isSelected(String location, String path) {
    if (path == AppRoutes.account) return location == AppRoutes.account;
    return location == path || location.startsWith('$path/');
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final MemberNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: AppRadius.pillAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppColors.navy : Colors.white.withValues(alpha: 0.82),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? AppColors.navy : Colors.white.withValues(alpha: 0.9),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.searchHint,
    required this.onSearch,
    required this.showMenuButton,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final bool wide = context.screenWidth >= Breakpoints.tablet;

    if (!wide) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      color: AppColors.backgroundDeep,
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.xxl),
          if (searchHint != null)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _SearchField(hint: searchHint!, onSubmitted: onSearch),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: AppSpacing.lg),
          ...actions,
          const SizedBox(width: AppSpacing.md),
          _Avatar(name: auth.user?.displayName ?? 'Member'),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onSubmitted});

  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TextField(
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: theme.colorScheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: AppColors.navy, width: 1.6),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part[0].toUpperCase())
        .join();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.navy,
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Text(
            name,
            style: theme.textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
