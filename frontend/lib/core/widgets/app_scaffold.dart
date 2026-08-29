import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/cms_controller.dart';
import '../errors/app_exception.dart';
import '../config/site_settings_controller.dart';
import '../routing/app_routes.dart';
import 'header_inbox.dart';
import '../../features/membership/member_shell.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive.dart';
import '../../repositories/cms_repository.dart';
import '../../repositories/message_repository.dart';
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

    // A SIGNED-IN MEMBER ON ONE OF THEIR OWN PAGES GETS THEIR OWN SHELL.
    //
    // Decided here rather than page by page, because these pages are not all
    // member pages: `/opportunities` and the forums are public to a visitor and
    // a workspace to a member, and the same widget has to serve both. Doing it
    // in each page would mean the same branch written a dozen times, and one of
    // them eventually forgotten.
    //
    // The effect is that the member's tools stay in the sidebar as they move
    // between them, instead of the sidebar vanishing the moment they follow one
    // of its own links.
    final MemberNavItem? memberPage = memberPageFor(currentPath);
    if (memberPage != null && context.watch<AuthController>().isSignedIn) {
      return MemberShell(
        currentPath: currentPath,
        title: memberPage.label,
        child: child,
      );
    }

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
                  if (wide) ...<Widget>[
                    // Only for somebody signed in: a messages button that
                    // always shows nothing is furniture.
                    // The bell and the chat icon together. The old lone
                    // messages button showed a count with nowhere to act on it
                    // and said nothing at all about notifications.
                    const HeaderInbox(),
                    const Gap.hSm(),
                    const _AccountButton(),
                  ],
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

/// The messages button, with the number waiting on it.
///
/// In the header rather than only in the navigation menu, because an unread
/// count nobody can see is an unread count nobody answers. It polls quietly
/// while the tab is open — a minute is often enough for a community archive,
/// and it costs one small request.
class MessagesButton extends StatefulWidget {
  const MessagesButton({super.key});

  @override
  State<MessagesButton> createState() => _MessagesButtonState();
}

class _MessagesButtonState extends State<MessagesButton> {
  int _unread = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
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
      if (mounted) setState(() => _unread = unread);
    } on AppException {
      // A badge is not worth an error message. It simply stays as it was.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: 'Messages',
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          onPressed: () => context.go(AppRoutes.messages),
        ),
        if (_unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: theme.colorScheme.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
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

/// The site footer.
///
/// Every colour used here is stated explicitly from `OnDark`. That is not
/// fussiness: the theme's own text styles carry foreground colours chosen for
/// light surfaces, so applying `bodySmall` unchanged on this navy background
/// produced dark-grey text on dark navy — which is how the link row became
/// unreadable. Nothing in this widget inherits a colour.
class _Footer extends StatelessWidget {
  const _Footer({required this.settings});

  final SiteSettings settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int year = DateTime.now().year;
    final List<NavItem> primary = context.watch<CmsController>().primaryNavigationOrFallback;
    final List<NavItem> secondary = context.watch<CmsController>().footerNavigationOrFallback;
    final bool wide = context.screenWidth >= Breakpoints.tablet;

    // Grouped by what things are — see `_footerGroups`. Anything the CMS offers
    // that no group claims still appears, under "More".
    final List<NavItem> archive = _footerItems('The archive', primary);
    final List<NavItem> community = _footerItems('The community', primary);
    final List<NavItem> takePart = _footerItems('Take part', primary);
    final List<NavItem> more = _footerRemainder(primary, secondary);

    final Widget brandBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const BrandLogo(size: 64, onDarkBackground: true),
            const Gap.hLg(),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CmsText(
                    'brand.name',
                    fallback: settings.siteName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: OnDark.primary,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap.xs(),
                  CmsText(
                    'brand.tagline',
                    fallback: settings.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(color: OnDark.link),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Gap.lg(),
        CmsText(
          'footer.about.body',
          fallback:
              'A permanent digital home for the history, culture, language and people of '
              'Ekoli-Yeden, built and maintained by the community.',
          style: theme.textTheme.bodyMedium?.copyWith(color: OnDark.body, height: 1.6),
        ),
        const Gap.lg(),
        const BrandPillars(onDarkBackground: true),
      ],
    );

    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: PageWidthContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 4, child: brandBlock),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(flex: 2, child: _FooterColumn(heading: 'The archive', items: archive)),
                  Expanded(
                    flex: 2,
                    child: _FooterColumn(heading: 'The community', items: community),
                  ),
                  Expanded(flex: 2, child: _FooterColumn(heading: 'Take part', items: takePart)),
                  Expanded(flex: 2, child: _FooterColumn(heading: 'More', items: more)),
                ],
              )
            else ...<Widget>[
              brandBlock,
              const Gap.xxl(),
              // On a phone the groups stack in the order somebody is most
              // likely to want them, rather than all four at full length.
              _FooterColumn(heading: 'The archive', items: archive),
              const Gap.xl(),
              _FooterColumn(heading: 'The community', items: community),
              const Gap.xl(),
              _FooterColumn(heading: 'Take part', items: takePart),
              const Gap.xl(),
              _FooterColumn(heading: 'More', items: more),
            ],

            if (settings.contactEmail != null ||
                settings.contactPhone != null ||
                settings.contactAddress != null) ...<Widget>[
              const Gap.xxl(),
              CmsText(
                'footer.contact.title',
                fallback: 'Contact',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: OnDark.primary,
                  letterSpacing: 1.2,
                ),
                transform: (String value) => value.toUpperCase(),
              ),
              const Gap.sm(),
              Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  if (settings.contactEmail != null)
                    _ContactLine(icon: Icons.mail_outline, value: settings.contactEmail!),
                  if (settings.contactPhone != null)
                    _ContactLine(icon: Icons.phone_outlined, value: settings.contactPhone!),
                  if (settings.contactAddress != null)
                    _ContactLine(icon: Icons.place_outlined, value: settings.contactAddress!),
                ],
              ),
            ],

            const Gap.xxl(),
            const Divider(color: OnDark.divider, height: 1),
            const Gap.lg(),

            // The policy links, where every site puts them and where people
            // therefore look. Reachable without an account, because somebody
            // deciding whether to make one needs to read them first.
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final ({String label, String path}) link
                    in const <({String label, String path})>[
                      (label: 'Terms of use', path: AppRoutes.terms),
                      (label: 'Privacy', path: AppRoutes.privacy),
                      (label: 'Cookies', path: AppRoutes.cookies),
                      (label: 'Contact us', path: AppRoutes.contact),
                    ])
                  InkWell(
                    onTap: () => context.go(link.path),
                    child: Text(
                      link.label,
                      style: theme.textTheme.bodySmall?.copyWith(color: OnDark.body),
                    ),
                  ),
              ],
            ),
            const Gap.lg(),

            // The bottom line wraps rather than overflowing on a phone.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '© $year',
                        style: theme.textTheme.bodySmall?.copyWith(color: OnDark.muted),
                      ),
                      const Gap.hSm(),
                      Flexible(
                        child: CmsText(
                          'footer.copyright',
                          fallback:
                              'This archive is built and maintained by the Ekoli-Yeden '
                              'Preservation Team and the wider community.',
                          style: theme.textTheme.bodySmall?.copyWith(color: OnDark.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.contribute),
                  icon: const Icon(Icons.favorite_outline, size: 15),
                  label: const Text('Contribute to the archive'),
                  style: TextButton.styleFrom(
                    foregroundColor: OnDark.link,
                    textStyle: theme.textTheme.labelMedium,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// THE FOOTER'S COLUMNS, GROUPED BY WHAT THINGS ARE.
///
/// They used to be the top navigation cut in half — the first seven items in
/// one column under "Explore" and the rest under "The archive". Those headings
/// described nothing, the split moved every time a section was added, and with
/// fourteen entries it had become two long unbalanced lists of everything.
///
/// A footer is a site map. So these are written down, in groups a reader would
/// recognise, and a section only appears in the one it belongs to.
///
/// Anything in the navigation that is not listed here still reaches the footer,
/// under "More" — so a section added by the community through the CMS is never
/// silently dropped.
const Map<String, List<String>> _footerGroups = <String, List<String>>{
  'The archive': <String>[
    AppRoutes.history,
    AppRoutes.culture,
    AppRoutes.language,
    AppRoutes.stories,
    AppRoutes.voices,
    AppRoutes.gallery,
  ],
  'The community': <String>[
    AppRoutes.people,
    AppRoutes.news,
    AppRoutes.festivals,
    AppRoutes.map,
    AppRoutes.learn,
  ],
  'Take part': <String>[
    AppRoutes.join,
    AppRoutes.contribute,
    AppRoutes.contributePerson,
    AppRoutes.directory,
    AppRoutes.opportunities,
  ],
};

/// The label a path should carry in the footer, preferring what the CMS calls
/// it so a community rename reaches here too.
String _footerLabel(String path, List<NavItem> navigation) {
  for (final NavItem item in navigation) {
    if (item.path == path) return item.label;
  }
  return const <String, String>{
    AppRoutes.history: 'History',
    AppRoutes.culture: 'Culture',
    AppRoutes.language: 'Language',
    AppRoutes.stories: 'Stories and folklore',
    AppRoutes.voices: 'Voices of Ekori',
    AppRoutes.gallery: 'Photographs and film',
    AppRoutes.people: 'People of Ekoli-Yeden',
    AppRoutes.news: 'News and announcements',
    AppRoutes.festivals: 'Festivals',
    AppRoutes.map: 'Discover Ekori',
    AppRoutes.learn: 'For children',
    AppRoutes.join: 'Join the community',
    AppRoutes.contribute: 'Send in material',
    AppRoutes.contributePerson: 'Add somebody to the archive',
    AppRoutes.directory: 'Member directory',
    AppRoutes.opportunities: 'Opportunities',
  }[path] ??
      path;
}

List<NavItem> _footerItems(String heading, List<NavItem> navigation) {
  return <NavItem>[
    for (final String path in _footerGroups[heading] ?? const <String>[])
      NavItem(label: _footerLabel(path, navigation), path: path),
  ];
}

/// Whatever the CMS offers that none of the groups above claims.
List<NavItem> _footerRemainder(List<NavItem> navigation, List<NavItem> secondary) {
  final Set<String> claimed = <String>{
    for (final List<String> group in _footerGroups.values) ...group,
    AppRoutes.home,
    AppRoutes.about,
    AppRoutes.messages,
  };
  return <NavItem>[
    const NavItem(label: 'About this archive', path: AppRoutes.about),
    for (final NavItem item in navigation)
      if (!item.isCta && !claimed.contains(item.path)) item,
    ...secondary,
  ];
}

/// One column of footer links.
class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.heading, required this.items});

  final String heading;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          heading.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: OnDark.primary,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap.md(),
        ...items.map(
          (NavItem item) => _FooterLink(item: item),
        ),
      ],
    );
  }
}

/// A footer link with a visible hover state and an explicit colour.
class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.item});

  final NavItem item;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        link: true,
        child: GestureDetector(
          onTap: () => context.go(widget.item.path),
          child: Padding(
            // Generous vertical padding so each link is a comfortable target on
            // a phone without the column becoming sparse.
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              widget.item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _hovered ? OnDark.primary : OnDark.body,
                decoration: _hovered ? TextDecoration.underline : null,
                decorationColor: OnDark.link,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: OnDark.link),
        const Gap.hSm(),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: OnDark.body),
        ),
      ],
    );
  }
}
