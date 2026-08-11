import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/config/cms_controller.dart';
import '../../core/config/site_settings_controller.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/settings_repository.dart';
import 'hero_carousel.dart';

/// The homepage.
///
/// A hero carousel and exactly five sections. The restraint is deliberate: a
/// long homepage would bury the archive underneath itself, and every one of
/// these sections is a door into a part of the site rather than a substitute
/// for it.
///
/// Every heading, paragraph and button label here comes from the CMS. The
/// literals passed as `fallback` are what renders before the database is
/// seeded — they are defaults, not the source of truth.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final SiteSettingsController settingsController = context.watch<SiteSettingsController>();
    final CmsController cms = context.watch<CmsController>();
    final SiteSettings settings = settingsController.settings;

    return AppScaffold(
      currentPath: AppRoutes.home,
      seo: SeoMetadata(
        title: cms.text('brand.name', fallback: settings.siteName),
        description: settings.description ??
            'The permanent digital home and archive of ${settings.communityName}: its history, '
                'culture, language, leadership, people, festivals and community life.',
        canonicalPath: AppRoutes.home,
      ),
      child: Column(
        children: <Widget>[
          const HeroCarousel(),
          if (AppConfig.isDevelopment && !cms.isApiReachable) const _ApiOfflineNotice(),
          const _Welcome(),
          const _SectionDiscover(),
          const _SectionLeboku(),
          const _SectionToday(),
          const _SectionArchive(),
          _SectionPreserve(settings: settings),
        ],
      ),
    );
  }
}

/// The introduction. Platform description, not a historical claim.
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PageSection(
      reading: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CmsText(
            'home.welcome.eyebrow',
            fallback: 'Welcome',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              letterSpacing: 1.8,
            ),
            transform: (String value) => value.toUpperCase(),
          ),
          const Gap.md(),
          CmsText(
            'home.welcome.title',
            fallback: 'Welcome to Ekoli-Yeden',
            style: context.isMobile
                ? theme.textTheme.headlineMedium
                : theme.textTheme.headlineLarge,
          ),
          const Gap.lg(),
          CmsText(
            'home.welcome.body',
            fallback:
                'EKOLI YEDEN DIGITAL HOME is a digital heritage and community platform dedicated '
                'to preserving, documenting and celebrating the history, culture, language, people '
                'and development of Ekoli-Yeden.',
            style: theme.textTheme.bodyLarge,
          ),
          const Gap.xl(),
          const BrandPillars(),
        ],
      ),
    );
  }
}

/// SECTION 1 — Discover Ekoli-Yeden.
class _SectionDiscover extends StatelessWidget {
  const _SectionDiscover();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PageSection(
      background: theme.colorScheme.surfaceContainerHigh,
      eyebrow: context.cmsWatch('home.s1.eyebrow', fallback: 'Discover'),
      title: context.cmsWatch('home.s1.title', fallback: 'Discover Ekoli-Yeden'),
      description: context.cmsWatch('home.s1.description', fallback: 'Four ways into the archive.'),
      child: const _DiscoverCards(),
    );
  }
}

class _DiscoverCards extends StatelessWidget {
  const _DiscoverCards();

  @override
  Widget build(BuildContext context) {
    const List<({String key, String title, String body, String path, IconData icon, Color color})>
    cards = <({String key, String title, String body, String path, IconData icon, Color color})>[
      (
        key: 'card1',
        title: 'Our History',
        body: 'Origins, migrations, institutions and the events that shaped this community.',
        path: AppRoutes.history,
        icon: Icons.auto_stories_outlined,
        color: AppColors.navy,
      ),
      (
        key: 'card2',
        title: 'Our Culture',
        body: 'Festivals, traditional practices, food, dress, farming, proverbs and folklore.',
        path: AppRoutes.culture,
        icon: Icons.celebration_outlined,
        color: AppColors.green,
      ),
      (
        key: 'card3',
        title: 'Our People',
        body: 'Leaders, scholars, professionals, artists and community builders, at home and abroad.',
        path: AppRoutes.people,
        icon: Icons.groups_outlined,
        color: AppColors.gold,
      ),
      (
        key: 'card4',
        title: 'Our Language',
        body: 'Words, meanings, expressions and proverbs, with pronunciation by native speakers.',
        path: AppRoutes.language,
        icon: Icons.translate_outlined,
        color: AppColors.navyLight,
      ),
    ];

    final int columns = context.gridColumns(max: 4);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width =
            (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: cards
              .map(
                (({String key, String title, String body, String path, IconData icon, Color color}) card) =>
                    SizedBox(
                      width: width,
                      child: _DiscoverCard(
                        cmsKey: card.key,
                        title: card.title,
                        body: card.body,
                        path: card.path,
                        icon: card.icon,
                        accent: card.color,
                      ),
                    ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _DiscoverCard extends StatefulWidget {
  const _DiscoverCard({
    required this.cmsKey,
    required this.title,
    required this.body,
    required this.path,
    required this.icon,
    required this.accent,
  });

  final String cmsKey;
  final String title;
  final String body;
  final String path;
  final IconData icon;
  final Color accent;

  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: widget.title,
        child: InkWell(
          onTap: () => context.go(widget.path),
          borderRadius: AppRadius.lgAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: _hovered
                    ? widget.accent.withValues(alpha: 0.45)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(widget.icon, size: 24, color: widget.accent),
                ),
                const Gap.lg(),
                CmsText(
                  'home.s1.${widget.cmsKey}.title',
                  fallback: widget.title,
                  style: theme.textTheme.titleLarge,
                ),
                const Gap.sm(),
                CmsText(
                  'home.s1.${widget.cmsKey}.description',
                  fallback: widget.body,
                  style: theme.textTheme.bodyMedium,
                ),
                const Gap.lg(),
                Row(
                  children: <Widget>[
                    Text(
                      context.cms('system.read_more', fallback: 'Read more'),
                      style: theme.textTheme.labelMedium?.copyWith(color: widget.accent),
                    ),
                    const Gap.hSm(),
                    Icon(Icons.arrow_forward, size: 14, color: widget.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SECTION 2 — Leboku & Heritage. A visual feature: image one side, text the other.
class _SectionLeboku extends StatelessWidget {
  const _SectionLeboku();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool stacked = context.screenWidth < Breakpoints.tablet;

    final Widget visual = AspectRatio(
      aspectRatio: stacked ? 16 / 10 : 4 / 3,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: AppRadius.lgAll,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.greenDark, AppColors.green, AppColors.gold],
          ),
        ),
        alignment: Alignment.center,
        // A placeholder until the Media Team supplies a festival photograph.
        // It is branded and deliberate rather than an empty grey rectangle.
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.celebration_outlined, size: 48, color: Colors.white),
              const Gap.md(),
              Text(
                'Festival photographs will appear here once they have been contributed and approved.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CmsText(
          'home.s2.eyebrow',
          fallback: 'Festival',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.gold,
            letterSpacing: 1.8,
          ),
          transform: (String value) => value.toUpperCase(),
        ),
        const Gap.md(),
        CmsText(
          'home.s2.title',
          fallback: 'Leboku & Heritage',
          style: context.isMobile
              ? theme.textTheme.headlineMedium
              : theme.textTheme.headlineLarge,
        ),
        const Gap.lg(),
        CmsText(
          'home.s2.description',
          fallback:
              'Discover the traditions, stories, celebrations and memories surrounding one of the '
              'most important cultural festivals associated with Yakurr communities. Each year '
              'keeps its own permanent page, so that when a festival is over, the year is not lost.',
          style: theme.textTheme.bodyLarge,
        ),
        const Gap.xl(),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.leboku),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(context.cms('home.s2.cta', fallback: 'Explore Leboku')),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );

    return PageSection(
      child: stacked
          ? Column(children: <Widget>[visual, const Gap.xxl(), copy])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(flex: 5, child: visual),
                const SizedBox(width: AppSpacing.section / 2),
                Expanded(flex: 6, child: copy),
              ],
            ),
    );
  }
}

/// SECTION 3 — Ekoli-Yeden Today.
class _SectionToday extends StatelessWidget {
  const _SectionToday();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({String label, String path, IconData icon})> links =
        <({String label, String path, IconData icon})>[
      (label: 'Community news', path: AppRoutes.news, icon: Icons.campaign_outlined),
      (label: 'Development projects', path: AppRoutes.community, icon: Icons.construction_outlined),
      (label: 'Businesses', path: AppRoutes.businesses, icon: Icons.storefront_outlined),
      (label: 'Organizations', path: AppRoutes.organizations, icon: Icons.diversity_3_outlined),
      (label: 'Achievements', path: AppRoutes.people, icon: Icons.emoji_events_outlined),
    ];

    return PageSection(
      background: theme.colorScheme.surfaceContainerHigh,
      eyebrow: context.cmsWatch('home.s3.eyebrow', fallback: 'Today'),
      title: context.cmsWatch('home.s3.title', fallback: 'Ekoli-Yeden Today'),
      description: context.cmsWatch(
        'home.s3.description',
        fallback:
            'The community as it is now: its news, its development projects, its businesses, its '
            'organizations and its achievements.',
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: links
            .map(
              (({String label, String path, IconData icon}) link) => ActionChip(
                avatar: Icon(link.icon, size: 18, color: AppColors.navy),
                label: Text(link.label),
                onPressed: () => context.go(link.path),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// SECTION 4 — From Our Archive.
class _SectionArchive extends StatelessWidget {
  const _SectionArchive();

  @override
  Widget build(BuildContext context) {
    const List<({String label, String body, String path, IconData icon, Color color})> tiles =
        <({String label, String body, String path, IconData icon, Color color})>[
      (
        label: 'Photographs',
        body: 'Labelled and searchable, so a face in a crowd can still be named in fifty years.',
        path: AppRoutes.gallery,
        icon: Icons.photo_library_outlined,
        color: AppColors.navy,
      ),
      (
        label: 'Videos',
        body: 'Documentaries, interviews, performances and oral history, organised by subject.',
        path: AppRoutes.videos,
        icon: Icons.play_circle_outline,
        color: AppColors.green,
      ),
      (
        label: 'Historical documents',
        body: 'Scanned records, programmes and letters, held with their provenance.',
        path: AppRoutes.history,
        icon: Icons.description_outlined,
        color: AppColors.gold,
      ),
    ];

    final int columns = context.gridColumns(max: 3);

    return PageSection(
      eyebrow: context.cmsWatch('home.s4.eyebrow', fallback: 'The archive'),
      title: context.cmsWatch('home.s4.title', fallback: 'From Our Archive'),
      description: context.cmsWatch(
        'home.s4.description',
        fallback:
            'Photographs, videos and historical documents, catalogued so they can still be found '
            'in fifty years.',
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width =
              (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;

          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: tiles
                .map(
                  (({String label, String body, String path, IconData icon, Color color}) tile) =>
                      SizedBox(
                        width: width,
                        child: _ArchiveTile(
                          label: tile.label,
                          body: tile.body,
                          path: tile.path,
                          icon: tile.icon,
                          accent: tile.color,
                        ),
                      ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.label,
    required this.body,
    required this.path,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String body;
  final String path;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: AppRadius.lgAll,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 96,
                width: double.infinity,
                color: accent.withValues(alpha: 0.10),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: accent),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.titleMedium),
                    const Gap.xs(),
                    Text(body, style: theme.textTheme.bodySmall),
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

/// SECTION 5 — Preserve Our Heritage. The closing call to action.
class _SectionPreserve extends StatelessWidget {
  const _SectionPreserve({required this.settings});

  final SiteSettings settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navyDark, AppColors.navy],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: PageWidthContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CmsText(
              'home.s5.eyebrow',
              fallback: 'Preserve our heritage',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.goldLight,
                letterSpacing: 2,
              ),
              transform: (String value) => value.toUpperCase(),
            ),
            const Gap.lg(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CmsText(
                'home.s5.title',
                fallback: 'Your photograph could be history tomorrow.',
                style: (context.isMobile
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.displaySmall)
                    ?.copyWith(color: Colors.white),
              ),
            ),
            const Gap.lg(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CmsText(
                'home.s5.description',
                fallback:
                    'Help preserve the stories, images, language and memories of Ekoli-Yeden for '
                    'generations to come. Every contribution is reviewed by the Preservation Team '
                    'before it is published, so the archive stays trustworthy.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            const Gap.xxl(),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                if (settings.contributionsOpen)
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.contribute),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      context.cms('home.s5.cta1', fallback: 'Contribute Materials'),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.preservationTeam),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  child: Text(
                    context.cms('home.s5.cta2', fallback: 'Join the Preservation Team'),
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

/// Shown in development when the API is not running.
class _ApiOfflineNotice extends StatelessWidget {
  const _ApiOfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: PageWidthContainer(
        child: Row(
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.warning),
            const Gap.hMd(),
            Expanded(
              child: Text(
                'The API is not responding, so the site is rendering its built-in fallback text. '
                'Start the Worker with `npm run dev` in the worker directory, then reload. '
                '(Development only.)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
