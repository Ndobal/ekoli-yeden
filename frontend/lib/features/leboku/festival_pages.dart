import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';
import '../../models/festival.dart';
import '../../models/video.dart';
import '../../repositories/festival_repository.dart';
import '../videos/video_pages.dart';

/// FESTIVALS.
///
/// Lekoli Boku is the largest of the community's festivals; it is not the only
/// one. This section therefore lists festivals in general — the Editorial Team
/// creates them, and the one that is current or upcoming is given prominence
/// while the earlier editions sit beneath it as a permanent archive.
class FestivalsIndexPage extends StatelessWidget {
  const FestivalsIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FestivalRepository repository = context.read<FestivalRepository>();

    return AppScaffold(
      currentPath: AppRoutes.festivals,
      seo: const SeoMetadata(
        title: 'Festivals',
        description:
            'The festivals of Ekoli-Yeden, including Lekoli Boku — the New Yam Festival. '
            'Programmes, events, photographs and videos, preserved year by year.',
        canonicalPath: AppRoutes.festivals,
      ),
      child: Column(
        children: <Widget>[
          const _FestivalsBanner(),
          PageSection(
            child: AsyncContent<FestivalIndex>(
              load: repository.index,
              loadingMessage: 'Opening the festival archive…',
              isEmpty: (FestivalIndex index) => index.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: Icons.celebration_outlined,
                title: 'No festival published yet',
                message: context.cms(
                  'page.festivals.empty',
                  fallback:
                      'No festival has been published yet. When the Editorial Team creates one, it '
                      'appears here with its programme, its events and its archive.',
                ),
              ),
              builder: (BuildContext context, FestivalIndex index) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (index.featured != null) ...<Widget>[
                    CmsText(
                      'page.festivals.upcoming_label',
                      fallback: 'Coming up',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.8,
                      ),
                      transform: (String value) => value.toUpperCase(),
                    ),
                    const Gap.md(),
                    FeaturedFestivalCard(festival: index.featured!),
                  ],
                  if (index.past.isNotEmpty) ...<Widget>[
                    const Gap.section(),
                    CmsText(
                      'page.festivals.past_label',
                      fallback: 'Past festivals',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Gap.lg(),
                    ResponsiveCardGrid(
                      maxColumns: 3,
                      children: index.past
                          .map((Festival festival) => _FestivalCard(festival: festival))
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FestivalsBanner extends StatelessWidget {
  const _FestivalsBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.greenDark, AppColors.green, AppColors.goldDark],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? AppSpacing.xxxl : AppSpacing.huge,
      ),
      child: PageWidthContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'CELEBRATIONS OF EKOLI-YEDEN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.goldLight,
                letterSpacing: 2,
              ),
            ),
            const Gap.md(),
            CmsText(
              'page.festivals.title',
              fallback: 'Festivals',
              style: (context.isMobile
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.displayMedium)
                  ?.copyWith(color: Colors.white),
            ),
            const Gap.lg(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: CmsText(
                'page.festivals.intro',
                fallback:
                    'The festivals of Ekoli-Yeden, each with its own permanent page. Every edition '
                    'keeps its programme, announcements, photographs and videos, so that when a '
                    'festival ends the year is not lost.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The current or upcoming festival, given the space it deserves.
class FeaturedFestivalCard extends StatelessWidget {
  const FeaturedFestivalCard({required this.festival, super.key});

  final Festival festival;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool stacked = context.screenWidth < Breakpoints.tablet;
    final Duration? countdown = festival.timeUntilStart;

    final Widget emblem = AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        // The festival's own logo where one has been uploaded; otherwise a
        // branded panel rather than an empty frame.
        child: festival.logoUrl != null
            ? Image.network(
                festival.logoUrl!,
                fit: BoxFit.contain,
                semanticLabel: '${festival.displayName} official logo',
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                    const _FestivalEmblemFallback(),
              )
            : const _FestivalEmblemFallback(),
      ),
    );

    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (festival.fullName != null)
          Text(
            festival.fullName!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              letterSpacing: 1.6,
            ),
          ),
        const Gap.sm(),
        Text(
          festival.displayName,
          style: (context.isMobile ? theme.textTheme.headlineMedium : theme.textTheme.displaySmall)
              ?.copyWith(color: AppColors.navy),
        ),
        if (festival.tagline != null) ...<Widget>[
          const Gap.sm(),
          Text(
            festival.tagline!,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.green,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Fact(
              icon: Icons.calendar_today_outlined,
              text: Formatters.dateRange(festival.startDate, festival.endDate),
            ),
            if (festival.location != null)
              _Fact(icon: Icons.place_outlined, text: festival.location!),
            if (countdown != null)
              _Fact(icon: Icons.timer_outlined, text: '${countdown.inDays} days to go'),
          ],
        ),
        if (festival.description != null) ...<Widget>[
          const Gap.lg(),
          Text(
            Formatters.excerpt(festival.description, maxLength: 320),
            style: theme.textTheme.bodyLarge,
          ),
        ],
        const Gap.xl(),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.festival(festival.slug)),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text('Explore ${festival.displayName}'),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(stacked ? AppSpacing.lg : AppSpacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 2),
      ),
      child: stacked
          ? Column(children: <Widget>[emblem, const Gap.xl(), copy])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(flex: 4, child: emblem),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(flex: 7, child: copy),
              ],
            ),
    );
  }
}

class _FestivalEmblemFallback extends StatelessWidget {
  const _FestivalEmblemFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.celebration_outlined, size: 48, color: AppColors.green),
          const Gap.sm(),
          Text(
            'Festival logo to be supplied',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// A past edition in the grid beneath the featured one.
class _FestivalCard extends StatelessWidget {
  const _FestivalCard({required this.festival});

  final Festival festival;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(AppRoutes.festival(festival.slug)),
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
            Row(
              children: <Widget>[
                Text(
                  '${festival.year}',
                  style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.gold),
                ),
                const Spacer(),
                if (festival.isArchived)
                  const Icon(Icons.archive_outlined, size: 16, color: AppColors.inkMuted),
              ],
            ),
            const Gap.sm(),
            Text(festival.name, style: theme.textTheme.titleLarge),
            if (festival.tagline != null) ...<Widget>[
              const Gap.xs(),
              Text(
                festival.tagline!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Gap.md(),
            Text(
              Formatters.dateRange(festival.startDate, festival.endDate),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.inkMuted),
        const Gap.hSm(),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One festival
// ---------------------------------------------------------------------------

/// A single festival, at `/festivals/<slug>` — or `/leboku/<year>`, which still
/// resolves so that links printed on earlier materials keep working.
class FestivalDetailPage extends StatelessWidget {
  const FestivalDetailPage({required this.identifier, super.key});

  final String identifier;

  @override
  Widget build(BuildContext context) {
    final FestivalRepository repository = context.read<FestivalRepository>();

    return AsyncContent<FestivalDetail>(
      key: ValueKey<String>('festival:$identifier'),
      load: () => repository.festival(identifier),
      loadingMessage: 'Opening the festival…',
      builder: (BuildContext context, FestivalDetail detail) => _FestivalPage(detail: detail),
    );
  }
}

class _FestivalPage extends StatelessWidget {
  const _FestivalPage({required this.detail});

  final FestivalDetail detail;

  @override
  Widget build(BuildContext context) {
    final Festival festival = detail.festival;
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.festivals,
      seo: SeoMetadata(
        title: festival.fullName ?? festival.displayName,
        description: festival.tagline ?? festival.description,
        imageUrl: festival.logoUrl,
        canonicalPath: AppRoutes.festival(festival.slug),
        type: 'article',
      ),
      child: Column(
        children: <Widget>[
          _FestivalHeader(festival: festival),

          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('About this festival', style: theme.textTheme.headlineSmall),
                const Gap.lg(),
                if (festival.description != null)
                  SelectableText(festival.description!, style: theme.textTheme.bodyLarge)
                else
                  const AwaitingMaterialNote(
                    message:
                        'A description of this festival has not been supplied yet. The committee '
                        'can add its history, meaning and programme through the admin system.',
                  ),
              ],
            ),
          ),

          // The programme, in the order the festival actually runs.
          PageSection(
            background: theme.colorScheme.surfaceContainerHigh,
            title: context.cmsWatch('festival.programme.title', fallback: 'Programme of events'),
            child: detail.programme.isEmpty
                ? AwaitingMaterialNote(
                    message: context.cms(
                      'festival.programme.empty',
                      fallback:
                          'The programme for this festival has not been published yet. It will '
                          'appear here once the committee has confirmed it.',
                    ),
                  )
                : _ProgrammeTimeline(phases: detail.programme),
          ),

          if (detail.gallery.isNotEmpty)
            PageSection(
              title: 'Photographs',
              child: _FestivalGallery(items: detail.gallery),
            ),

          if (detail.videos.isNotEmpty)
            PageSection(
              background: theme.colorScheme.surfaceContainerHigh,
              title: 'Videos',
              child: ResponsiveCardGrid(
                children: detail.videos
                    .map((Video video) => VideoCard(video: video))
                    .toList(growable: false),
              ),
            ),

          if (festival.announcements.isNotEmpty)
            PageSection(
              title: 'Announcements',
              child: _EntryList(entries: festival.announcements),
            ),

          if (festival.sponsors.isNotEmpty)
            PageSection(
              background: theme.colorScheme.surfaceContainerHigh,
              title: 'Sponsors',
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: festival.sponsors
                    .map(
                      (Map<String, dynamic> sponsor) =>
                          Chip(label: Text((sponsor['name'] ?? 'Sponsor').toString())),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _FestivalHeader extends StatelessWidget {
  const _FestivalHeader({required this.festival});

  final Festival festival;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration? countdown = festival.timeUntilStart;
    final bool stacked = context.screenWidth < Breakpoints.tablet;

    final Widget logo = festival.logoUrl == null
        ? const SizedBox.shrink()
        : Container(
            width: stacked ? 140 : 200,
            height: stacked ? 140 : 200,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: ClipOval(
              child: Image.network(
                festival.logoUrl!,
                fit: BoxFit.cover,
                semanticLabel: '${festival.displayName} official logo',
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          );

    final Widget copy = Column(
      crossAxisAlignment: stacked ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.festivals),
          icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white70),
          label: const Text('All festivals', style: TextStyle(color: Colors.white70)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        const Gap.md(),
        if (festival.fullName != null)
          Text(
            festival.fullName!.toUpperCase(),
            textAlign: stacked ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.goldLight,
              letterSpacing: 2,
            ),
          ),
        const Gap.sm(),
        Text(
          festival.displayName,
          textAlign: stacked ? TextAlign.center : TextAlign.start,
          style: (context.isMobile ? theme.textTheme.displaySmall : theme.textTheme.displayMedium)
              ?.copyWith(color: Colors.white),
        ),
        if (festival.tagline != null) ...<Widget>[
          const Gap.md(),
          Text(
            festival.tagline!,
            textAlign: stacked ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.goldLight),
          ),
        ],
        const Gap.lg(),
        Wrap(
          alignment: stacked ? WrapAlignment.center : WrapAlignment.start,
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _HeaderFact(
              icon: Icons.calendar_today_outlined,
              text: Formatters.dateRange(festival.startDate, festival.endDate),
            ),
            if (festival.location != null)
              _HeaderFact(icon: Icons.place_outlined, text: festival.location!),
            if (countdown != null)
              _HeaderFact(icon: Icons.timer_outlined, text: '${countdown.inDays} days to go'),
            if (festival.isArchived)
              const _HeaderFact(icon: Icons.archive_outlined, text: 'Archived edition'),
          ],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.greenDark, AppColors.navy],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? AppSpacing.xxxl : AppSpacing.huge,
      ),
      child: PageWidthContainer(
        child: stacked
            ? Column(
                children: <Widget>[
                  if (festival.logoUrl != null) ...<Widget>[logo, const Gap.xl()],
                  copy,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: copy),
                  if (festival.logoUrl != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xxl),
                    logo,
                  ],
                ],
              ),
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: Colors.white70),
        const Gap.hSm(),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// The programme, rendered as a timeline: the run-up, the main day, and after.
class _ProgrammeTimeline extends StatelessWidget {
  const _ProgrammeTimeline({required this.phases});

  final List<ProgrammePhase> phases;

  static const Map<String, ({String fallback, Color colour, IconData icon})> _phaseStyle =
      <String, ({String fallback, Color colour, IconData icon})>{
    'lead_up': (
      fallback: 'Leading up to the main day',
      colour: AppColors.skyBlueDark,
      icon: Icons.trending_up
    ),
    'main_day': (
      fallback: 'The main day',
      colour: AppColors.gold,
      icon: Icons.star_outline
    ),
    'after': (
      fallback: 'After the main day',
      colour: AppColors.green,
      icon: Icons.arrow_downward
    ),
    'other': (
      fallback: 'Other activities',
      colour: AppColors.inkMuted,
      icon: Icons.more_horiz
    ),
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: phases.map((ProgrammePhase phase) {
        final ({String fallback, Color colour, IconData icon}) style =
            _phaseStyle[phase.phase] ?? _phaseStyle['other']!;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: style.colour.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(style.icon, size: 18, color: style.colour),
                  ),
                  const Gap.hMd(),
                  CmsText(
                    'festival.phase.${phase.phase}',
                    fallback: style.fallback,
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const Gap.lg(),
              // The connecting rail makes the sequence read as a timeline
              // rather than three unrelated lists.
              Padding(
                padding: const EdgeInsets.only(left: 17),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: style.colour.withValues(alpha: 0.3), width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: phase.items
                        .map(
                          (ContentRecord item) =>
                              _ProgrammeItem(item: item, accent: style.colour),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ProgrammeItem extends StatelessWidget {
  const _ProgrammeItem({required this.item, required this.accent});

  final ContentRecord item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String when = Formatters.dateRange(
      item.text('start_datetime'),
      item.text('end_datetime'),
      fallback: '',
    );
    final String? day = item.text('programme_day');
    final String? venue = item.text('venue') ?? item.text('location');
    final bool headline = item.flag('is_headline');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: headline
                ? accent.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (day != null || when.isNotEmpty) ...<Widget>[
              Text(
                <String>[?day, if (when.isNotEmpty) when].join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(color: accent),
              ),
              const Gap.xs(),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(item.displayTitle, style: theme.textTheme.titleMedium),
                ),
                if (item.category != null)
                  Chip(
                    label: Text(item.category!),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            if (venue != null) ...<Widget>[
              const Gap.xs(),
              Row(
                children: <Widget>[
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.inkMuted),
                  const Gap.hSm(),
                  Text(venue, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            if (item.summary != null) ...<Widget>[
              const Gap.sm(),
              Text(item.summary!, style: theme.textTheme.bodyMedium),
            ],
            if (when.isEmpty && day == null) ...<Widget>[
              const Gap.sm(),
              Text(
                'Date to be confirmed',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Announcements and other free-form JSON entries.
class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: entries.map((Map<String, dynamic> entry) {
        final String title = (entry['title'] ?? entry['name'] ?? 'Announcement').toString();
        final String? detail = (entry['description'] ?? entry['detail'])?.toString();
        final String? when = (entry['date'] ?? entry['time'])?.toString();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (when != null)
                Text(
                  when,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
                ),
              Text(title, style: theme.textTheme.titleMedium),
              if (detail != null) ...<Widget>[
                const Gap.sm(),
                Text(detail, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _FestivalGallery extends StatelessWidget {
  const _FestivalGallery({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ResponsiveCardGrid(
      maxColumns: 4,
      spacing: AppSpacing.md,
      children: items.map((Map<String, dynamic> item) {
        final String url = (item['url'] ?? '').toString();
        final String label =
            (item['caption'] ?? item['alt_text'] ?? 'An unlabelled photograph from the archive')
                .toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: ArchiveImage(url: url, label: label, aspectRatio: 1),
            ),
            if (item['caption'] != null) ...<Widget>[
              const Gap.sm(),
              Text(
                item['caption'].toString(),
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      }).toList(growable: false),
    );
  }
}
