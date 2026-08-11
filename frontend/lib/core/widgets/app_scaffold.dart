import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/cms_controller.dart';
import '../config/site_settings_controller.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive.dart';
import '../../repositories/cms_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/auth/auth_controller.dart';
import 'brand_logo.dart';
import 'cms_text.dart';
import 'seo_head.dart';

/// The public shell: header, navigation, footer.
///
/// Every public page is wrapped in this, so the header and footer are defined
/// once. On a phone the navigation collapses into a drawer — which is the
/// layout most visitors will actually see, since most arrive from a WhatsApp
/// link.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    required this.currentPath,
    this.seo,
    super.key,
  });

  final Widget child;
  final String currentPath;
  final SeoMetadata? seo;

  @override
  Widget build(BuildContext context) {
    final SiteSettings settings = context.watch<SiteSettingsController>().settings;
    final List<NavItem> primary = context.watch<CmsController>().primaryNavigationOrFallback;

    return Scaffold(
      drawer: context.hasRoomForNavBar
          ? null
          : _MobileDrawer(currentPath: currentPath, items: primary),
      body: SeoHead(
        metadata: seo,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _Header(currentPath: currentPath, settings: settings, items: primary),
            ),
            SliverToBoxAdapter(child: child),
            SliverToBoxAdapter(child: _Footer(settings: settings)),
          ],
        ),
      ),
    );
  }
}

/// Resolves the CMS menus, falling back to the compiled-in navigation.
///
/// The site must never render without navigation, so an unreachable CMS
/// degrades to the built-in menu rather than an empty header.
extension CmsNavigation on CmsController {
  List<NavItem> get primaryNavigationOrFallback {
    if (primaryNavigation.isEmpty) return fallbackPrimaryNavigation;
    return primaryNavigation.map(_toNavItem).toList(growable: false);
  }

  List<NavItem> get footerNavigationOrFallback {
    if (footerNavigation.isEmpty) return fallbackFooterNavigation;
    return footerNavigation.map(_toNavItem).toList(growable: false);
  }

  NavItem _toNavItem(CmsNavItem item) => NavItem(
    label: item.label,
    path: item.path,
    description: item.description,
    isCta: item.isCta,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.currentPath, required this.settings, required this.items});

  final String currentPath;
  final SiteSettings settings;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool wide = context.hasRoomForNavBar;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: PageWidthContainer(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  if (!wide)
                    Builder(
                      builder: (BuildContext context) => IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Open navigation menu',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  Expanded(child: _Wordmark(settings: settings, compact: !wide)),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: context.cms('system.search', fallback: 'Search the archive'),
                    onPressed: () => context.go(AppRoutes.search),
                  ),
                  if (wide) ...<Widget>[const Gap.hSm(), const _AccountButton()],
                ],
              ),
            ),
            if (wide) _DesktopNav(currentPath: currentPath, items: items),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed background, contents constrained to the page width.
class PageWidthContainer extends StatelessWidget {
  const PageWidthContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding(context.screenWidth),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.settings, required this.compact});

  final SiteSettings settings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      link: true,
      label: '${settings.siteName} — home',
      child: InkWell(
        onTap: () => context.go(AppRoutes.home),
        borderRadius: AppRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              BrandLogo(size: compact ? 36 : 48),
              const Gap.hMd(),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CmsText(
                      'brand.name',
                      fallback: settings.siteName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!compact)
                      CmsText(
                        'brand.tagline',
                        fallback: settings.tagline,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.currentPath, required this.items});

  final String currentPath;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items
              .map(
                (NavItem item) => _NavLink(
                  item: item,
                  isActive: isPathActive(currentPath, item.path),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// True when a nav item should be highlighted for the current location.
bool isPathActive(String currentPath, String itemPath) {
  if (itemPath == AppRoutes.home) return currentPath == AppRoutes.home;
  return currentPath == itemPath || currentPath.startsWith('$itemPath/');
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.item, required this.isActive});

  final NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (item.isCta) {
      return Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: FilledButton(
          onPressed: () => context.go(item.path),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          child: Text(item.label),
        ),
      );
    }

    return Tooltip(
      message: item.description ?? item.label,
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: AppRadius.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.gold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            item.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isActive ? AppColors.navy : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    if (!auth.isSignedIn) {
      return OutlinedButton(
        onPressed: () => context.go(AppRoutes.signIn),
        child: const Text('Sign in'),
      );
    }

    final bool editorial = auth.canAccessEditorial;
    final bool administration = auth.canAccessAdmin;

    return PopupMenuButton<String>(
      tooltip: auth.user!.displayName,
      onSelected: (String value) async {
        switch (value) {
          case 'editorial':
            context.go(AppRoutes.editorialDashboard);
          case 'admin':
            context.go(AppRoutes.adminDashboard);
          case 'signout':
            await auth.signOut();
            if (context.mounted) context.go(AppRoutes.home);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(auth.user!.displayName, style: Theme.of(context).textTheme.titleSmall),
              Text(auth.user!.roleSummary, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (editorial)
          const PopupMenuItem<String>(value: 'editorial', child: Text('Editorial dashboard')),
        if (administration)
          const PopupMenuItem<String>(value: 'admin', child: Text('Administration')),
        const PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.navy,
        child: Text(
          auth.user!.initials,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.currentPath, required this.items});

  final String currentPath;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final List<NavItem> footer = context.watch<CmsController>().footerNavigationOrFallback;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const BrandLogo(size: 40),
                  const Gap.hMd(),
                  Expanded(
                    child: CmsText(
                      'brand.name',
                      fallback: 'Ekoli Yeden',
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            const Gap.lg(),
            ...items.map(
              (NavItem item) => ListTile(
                title: Text(item.label),
                selected: isPathActive(currentPath, item.path),
                selectedColor: AppColors.navy,
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.path);
                },
              ),
            ),
            const Divider(),
            ...footer.map(
              (NavItem item) => ListTile(
                dense: true,
                title: Text(item.label, style: theme.textTheme.bodyMedium),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.path);
                },
              ),
            ),
            const Divider(),
            if (auth.isSignedIn) ...<Widget>[
              if (auth.canAccessEditorial)
                ListTile(
                  leading: const Icon(Icons.edit_note_outlined),
                  title: const Text('Editorial dashboard'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.editorialDashboard);
                  },
                ),
              if (auth.canAccessAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Administration'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.adminDashboard);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await auth.signOut();
                  if (context.mounted) context.go(AppRoutes.home);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.signIn);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.settings});

  final SiteSettings settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int year = DateTime.now().year;
    final List<NavItem> footer = context.watch<CmsController>().footerNavigationOrFallback;

    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: PageWidthContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const BrandLogo(size: 56, onDarkBackground: true),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CmsText(
                        'brand.name',
                        fallback: settings.siteName,
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const Gap.xs(),
                      CmsText(
                        'brand.tagline',
                        fallback: settings.tagline,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.skyBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap.xl(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: CmsText(
                'footer.about.body',
                fallback:
                    'A permanent digital home for the history, culture, language and people of '
                    'Ekoli-Yeden, built and maintained by the community.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
            const Gap.xxl(),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.xs,
              children: footer
                  .map(
                    (NavItem item) => TextButton(
                      onPressed: () => context.go(item.path),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.skyBlue,
                      ),
                      child: Text(item.label, style: theme.textTheme.bodySmall),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (settings.contactEmail != null || settings.contactPhone != null) ...<Widget>[
              const Gap.xl(),
              CmsText(
                'footer.contact.title',
                fallback: 'Contact',
                style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
              const Gap.xs(),
              if (settings.contactEmail != null)
                SelectableText(
                  settings.contactEmail!,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.skyBlue),
                ),
              if (settings.contactPhone != null)
                SelectableText(
                  settings.contactPhone!,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.skyBlue),
                ),
            ],
            const Gap.xxl(),
            Divider(color: Colors.white.withValues(alpha: 0.15)),
            const Gap.lg(),
            Row(
              children: <Widget>[
                Text(
                  '© $year · ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: CmsText(
                    'footer.copyright',
                    fallback:
                        'This archive is built and maintained by the Ekoli-Yeden Preservation Team '
                        'and the wider community.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
