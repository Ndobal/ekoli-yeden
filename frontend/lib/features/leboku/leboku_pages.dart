import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/site_settings_controller.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';
import '../../models/festival.dart';
import '../../models/video.dart';
import '../../repositories/festival_repository.dart';
import '../../repositories/settings_repository.dart';
import '../videos/video_pages.dart';

/// THE LEBOKU FESTIVAL DIGITAL CENTRE.
///
/// Leboku is not a page that gets rewritten every year. Each edition is its own
/// record at its own permanent address — `/leboku/2026`, `/leboku/2027` — so
/// that when the festival is over, the year does not disappear. That is what
/// turns this section into a festival archive rather than a noticeboard.
class LebokuIndexPage extends StatelessWidget {
  const LebokuIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FestivalRepository repository = context.read<FestivalRepository>();
    final SiteSettings settings = context.watch<SiteSettingsController>().settings;

    return AppScaffold(
      currentPath: AppRoutes.leboku,
      seo: SeoMetadata(
        title: '${settings.festivalName} Festival',
        description:
            'The ${settings.festivalName} festival of ${settings.communityName}, year by year: '
            'programmes, announcements, photographs and videos, preserved permanently.',
        canonicalPath: AppRoutes.leboku,
      ),
      child: Column(
        children: <Widget>[
          _FestivalHero(settings: settings),
          PageSection(
            eyebrow: 'The festival archive',
            title: 'Every year, preserved',
            description:
                'Each edition of the festival keeps its own permanent page — its programme, its '
                'announcements, its photographs and its videos. When the festival is over, the '
                'year remains.',
            child: AsyncContent<List<FestivalEdition>>(
              load: repository.lebokuEditions,
              loadingMessage: 'Opening the festival archive…',
              isEmpty: (List<FestivalEdition> editions) => editions.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: Icons.celebration_outlined,
                title: 'No festival edition published yet',
                message:
                    'Festival information — the programme, the committee, the dates and the '
                    'announcements — is published by the ${settings.festivalName} Manager once the '
                    'community has confirmed it. Nothing about the festival has been assumed here.',
              ),
              builder: (BuildContext context, List<FestivalEdition> editions) {
                return ResponsiveCardGrid(
                  maxColumns: 3,
                  children: editions
                      .map((FestivalEdition edition) => _EditionCard(edition: edition))
                      .toList(growable: false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FestivalHero extends StatelessWidget {
  const _FestivalHero({required this.settings});

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
          colors: <Color>[AppColors.goldDark, AppColors.gold],
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
              'THE FESTIVAL OF ${settings.communityName.toUpperCase()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 2,
              ),
            ),
            const Gap.md(),
            Text(
              settings.festivalName,
              style: (context.isMobile
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.displayMedium)
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditionCard extends StatelessWidget {
  const _EditionCard({required this.edition});

  final FestivalEdition edition;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(AppRoutes.festivalYear(edition.year)),
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
            Text(
              '${edition.year}',
              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.gold),
            ),
            const Gap.sm(),
            Text(edition.name, style: theme.textTheme.titleLarge),
            if (edition.theme != null) ...<Widget>[
              const Gap.xs(),
              Text(edition.theme!, style: theme.textTheme.bodySmall),
            ],
            const Gap.md(),
            Text(
              Formatters.dateRange(edition.startDate, edition.endDate),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// One edition of the festival — `/leboku/2026`.
class FestivalYearPage extends StatelessWidget {
  const FestivalYearPage({required this.year, super.key});

  final String year;

  @override
  Widget build(BuildContext context) {
    final FestivalRepository repository = context.read<FestivalRepository>();

    return AsyncContent<FestivalDetail>(
      key: ValueKey<String>('festival:$year'),
      load: () => repository.festival(year),
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
      currentPath: AppRoutes.leboku,
      seo: SeoMetadata(
        title: festival.displayName,
        description: festival.description ??
            'The ${festival.displayName} festival: its programme, announcements, photographs and videos.',
        canonicalPath: AppRoutes.festivalYear(festival.year),
        type: 'article',
      ),
      child: Column(
        children: <Widget>[
          _EditionHeader(festival: festival),

          PageSection(
            title: 'About this edition',
            reading: true,
            child: festival.description != null
                ? Text(festival.description!, style: theme.textTheme.bodyLarge)
                : const AwaitingMaterialNote(
                    message:
                        'A description of this edition has not been supplied yet. The festival '
                        'committee can add the theme, the programme and the announcements through '
                        'the admin system.',
                  ),
          ),

          if (festival.programme.isNotEmpty)
            PageSection(
              title: 'Programme',
              background: theme.colorScheme.surfaceContainerHigh,
              child: _ProgrammeList(entries: festival.programme),
            ),

          if (detail.events.isNotEmpty)
            PageSection(
              title: 'Events',
              child: ResponsiveCardGrid(
                children: detail.events
                    .map(
                      (ContentRecord event) => ContentCard(
                        record: event,
                        path: AppRoutes.event(event.pathSegment),
                        metaLine: Formatters.dateRange(
                          event.text('start_datetime'),
                          event.text('end_datetime'),
                          fallback: '',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),

          if (detail.gallery.isNotEmpty)
            PageSection(
              title: 'Photographs',
              background: theme.colorScheme.surfaceContainerHigh,
              child: _FestivalGallery(items: detail.gallery),
            ),

          if (detail.videos.isNotEmpty)
            PageSection(
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
              background: theme.colorScheme.surfaceContainerHigh,
              child: _ProgrammeList(entries: festival.announcements),
            ),

          if (festival.sponsors.isNotEmpty)
            PageSection(title: 'Sponsors', child: _SponsorList(sponsors: festival.sponsors)),

          if (!detail.hasContent && festival.programme.isEmpty)
            const PageSection(
              child: EmptyView(
                icon: Icons.celebration_outlined,
                title: 'This edition has no material yet',
                message:
                    'Photographs, videos and the programme for this festival have not been added '
                    'yet. If you attended and have photographs or recordings, the archive would '
                    'welcome them.',
              ),
            ),
        ],
      ),
    );
  }
}

class _EditionHeader extends StatelessWidget {
  const _EditionHeader({required this.festival});

  final Festival festival;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration? countdown = festival.timeUntilStart;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navyDark, AppColors.goldDark],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? AppSpacing.xxxl : AppSpacing.huge,
      ),
      child: PageWidthContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.leboku),
              icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white70),
              label: const Text(
                'All festival years',
                style: TextStyle(color: Colors.white70),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.lg(),
            Text(
              festival.displayName,
              style: (context.isMobile
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.displayMedium)
                  ?.copyWith(color: Colors.white),
            ),
            if (festival.theme != null) ...<Widget>[
              const Gap.md(),
              Text(
                festival.theme!,
                style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.goldLight),
              ),
            ],
            const Gap.lg(),
            Wrap(
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
                  _HeaderFact(
                    icon: Icons.timer_outlined,
                    text: '${countdown.inDays} days to go',
                  ),
                if (festival.isArchived)
                  const _HeaderFact(icon: Icons.archive_outlined, text: 'Archived edition'),
              ],
            ),
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

/// Renders a programme or announcement list.
///
/// The stored shape is free-form JSON, because a festival programme differs
/// from year to year and the community should not need a migration to change
/// how theirs is laid out. This reads the fields it recognises and falls back
/// to showing the raw entry rather than dropping an editor's work.
class _ProgrammeList extends StatelessWidget {
  const _ProgrammeList({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: entries.map((Map<String, dynamic> entry) {
        final String title = (entry['title'] ?? entry['name'] ?? 'Item').toString();
        final String? when = (entry['time'] ?? entry['date'] ?? entry['day'])?.toString();
        final String? detail = (entry['description'] ?? entry['detail'])?.toString();
        final String? venue = (entry['venue'] ?? entry['location'])?.toString();

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
              if (when != null) ...<Widget>[
                Text(
                  when,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
                ),
                const Gap.xs(),
              ],
              Text(title, style: theme.textTheme.titleMedium),
              if (venue != null) ...<Widget>[
                const Gap.xs(),
                Text(venue, style: theme.textTheme.bodySmall),
              ],
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

class _SponsorList extends StatelessWidget {
  const _SponsorList({required this.sponsors});

  final List<Map<String, dynamic>> sponsors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: sponsors
          .map(
            (Map<String, dynamic> sponsor) => Chip(
              label: Text((sponsor['name'] ?? 'Sponsor').toString()),
            ),
          )
          .toList(growable: false),
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
