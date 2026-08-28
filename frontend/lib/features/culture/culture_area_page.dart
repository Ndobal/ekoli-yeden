import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/service_locator.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/content_record.dart';
import '../../services/api/api_response.dart';
import 'culture_pages.dart';

/// ONE AREA OF THE CULTURAL ARCHIVE.
///
/// The culture page lists thirteen areas — food, wrestling, dances, proverbs,
/// and the rest. Until now they were labels: a visitor who wanted to know about
/// food read the word "Food" and had nowhere to go.
///
/// Each one now has an address of its own, showing what has been recorded in
/// that area and inviting what has not. That second half matters more at the
/// moment than the first: almost every area is empty, and an empty shelf that
/// asks for material is useful in a way that an empty shelf is not.
class CultureAreaPage extends StatelessWidget {
  const CultureAreaPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final CultureArea? area = cultureAreaFor(slug);

    // An unknown area is not a 404: the list of areas lives in the client, and
    // an old link to an area since renamed should still land somewhere useful.
    if (area == null) return _UnknownArea(slug: slug);

    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.culture,
      seo: SeoMetadata(
        title: '${area.label} — Culture & Heritage',
        description: area.description,
        canonicalPath: AppRoutes.cultureArea(area.slug),
      ),
      child: Column(
        children: <Widget>[
          _AreaHeader(area: area),
          PageSection(
            child: AsyncContent<PaginatedResult<ContentRecord>>(
              // The area is the record's `category`, which is a filter the
              // content registry already supports — so an area page is a
              // narrowed list rather than a new endpoint.
              load: () =>
                  context.contentRepository('culture').list(perPage: 24, category: area.slug),
              loadingMessage: 'Opening this part of the archive…',
              isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
              emptyBuilder: (BuildContext context) => _EmptyArea(area: area),
              builder: (BuildContext context, PaginatedResult<ContentRecord> result) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      result.total == 1 ? '1 record' : '${result.total} records',
                      style: theme.textTheme.labelMedium,
                    ),
                    const Gap.lg(),
                    ResponsiveCardGrid(
                      maxColumns: 3,
                      children: result.items
                          .map(
                            (ContentRecord record) => ContentCard(
                              record: record,
                              path: AppRoutes.cultureEntry(record.pathSegment),
                              showVerification: true,
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const Gap.xxl(),
                    _ContributeToArea(area: area),
                  ],
                );
              },
            ),
          ),
          PageSection(
            background: theme.colorScheme.surfaceContainerHigh,
            title: 'Other areas of the archive',
            child: const _OtherAreas(),
          ),
        ],
      ),
    );
  }
}

class _AreaHeader extends StatelessWidget {
  const _AreaHeader({required this.area});

  final CultureArea area;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.culture),
              icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white70),
              label: const Text(
                'Culture & Heritage',
                style: TextStyle(color: Colors.white70),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.md(),
            Row(
              children: <Widget>[
                Icon(area.icon, size: 32, color: AppColors.goldLight),
                const Gap.hLg(),
                Expanded(
                  child: Text(
                    area.label,
                    style: (context.isMobile
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.displayMedium)
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const Gap.md(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: Text(
                area.description,
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.goldLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What this area says when nothing has been recorded in it yet.
///
/// Written as a request rather than an apology. The empty state is the normal
/// state of most of this archive today, and it is the page's real job.
class _EmptyArea extends StatelessWidget {
  const _EmptyArea({required this.area});

  final CultureArea area;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(area.icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
              const Gap.lg(),
              Text('Nothing recorded here yet', style: theme.textTheme.headlineSmall),
              const Gap.sm(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
                child: Text(
                  area.prompt,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap.xxl(),
        _ContributeToArea(area: area),
      ],
    );
  }
}

/// The invitation, carrying the area with it so a contribution arrives already
/// filed under the right heading.
class _ContributeToArea extends StatelessWidget {
  const _ContributeToArea({required this.area});

  final CultureArea area;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.green, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Do you know about ${area.label.toLowerCase()}?', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
            child: Text(
              'Photographs, recordings, a description in your own words, or the name of somebody '
              'who would know — all of it helps. Nothing is published until the Preservation Team '
              'has checked it, and you are credited when it is.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const Gap.lg(),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.contributeToArea(area.label)),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text('Contribute to ${area.label.toLowerCase()}'),
              ),
              // The two areas that have a whole section of their own rather
              // than a shelf in the cultural archive.
              if (area.slug == 'language')
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.contributeWord),
                  icon: const Icon(Icons.translate_outlined, size: 18),
                  label: const Text('Add a word to the dictionary'),
                ),
              if (area.linkedSection != null)
                OutlinedButton.icon(
                  onPressed: () => context.go(area.linkedSection!.path),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(area.linkedSection!.label),
                  iconAlignment: IconAlignment.end,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rest of the areas, so a visitor can move sideways rather than back.
class _OtherAreas extends StatelessWidget {
  const _OtherAreas();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? current = GoRouterState.of(context).pathParameters['slug'];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: cultureAreas
          .where((CultureArea area) => area.slug != current)
          .map(
            (CultureArea area) => ActionChip(
              avatar: Icon(area.icon, size: 16),
              label: Text(area.label),
              onPressed: () => context.go(AppRoutes.cultureArea(area.slug)),
              labelStyle: theme.textTheme.labelMedium,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _UnknownArea extends StatelessWidget {
  const _UnknownArea({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentPath: AppRoutes.culture,
      child: PageSection(
        eyebrow: 'Culture & Heritage',
        title: 'That area is not part of the archive',
        description:
            'The cultural archive is organised into the areas below. The link you followed does '
            'not match any of them — it may have been renamed.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _OtherAreas(),
            const Gap.xxl(),
            FilledButton(
              onPressed: () => context.go(AppRoutes.culture),
              child: const Text('Back to Culture & Heritage'),
            ),
          ],
        ),
      ),
    );
  }
}
