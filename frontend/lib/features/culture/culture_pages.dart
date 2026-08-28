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
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';
import '../../services/api/api_response.dart';
import '../about/about_pages.dart';
import '../shared/content_detail_page.dart';

/// CULTURE & HERITAGE.
///
/// The areas below are the shape of the section — what the Preservation Team is
/// expected to document. They are not claims about Ekoli-Yeden's culture: each
/// one is an empty shelf until somebody who knows fills it, and the page says
/// so.
///
/// Each area has an address of its own. A card that names "Food" and cannot be
/// opened is a label; a card that leads to what has been recorded about food,
/// and to a way of adding to it, is a shelf somebody can put something on.
class CultureArea {
  const CultureArea({
    required this.slug,
    required this.label,
    required this.description,
    required this.icon,
    required this.prompt,
    this.linkedSection,
  });

  /// Matches the `category` an article is filed under, which is how the area
  /// page finds its records without needing an endpoint of its own.
  final String slug;

  final String label;
  final String description;
  final IconData icon;

  /// What to ask for where nothing has been recorded yet. Written per area,
  /// because "please contribute" is a poster and "who cooks this, and for which
  /// occasion?" is a question somebody can actually answer.
  final String prompt;

  /// Where an area also has a whole section of its own, so the page can send a
  /// visitor to the fuller thing rather than duplicating it.
  final ({String label, String path})? linkedSection;
}

const List<CultureArea> cultureAreas = <CultureArea>[
  CultureArea(
    slug: 'language',
    label: 'Language',
    description: 'Words, expressions and the sound of the language itself.',
    icon: Icons.translate_outlined,
    prompt:
        'The dictionary is the fuller home for this. Words, their meanings, and above all '
        'recordings of somebody saying them — that last is what written words preserve worst.',
    linkedSection: (label: 'Open the dictionary', path: AppRoutes.language),
  ),
  CultureArea(
    slug: 'leboku',
    label: 'Leboku',
    description: 'The festival, its meaning, and how it is kept.',
    icon: Icons.celebration_outlined,
    prompt:
        'What the festival means, how it is kept, and what has changed. Photographs from any year '
        'belong in the festival section, where they are filed under the year they were taken.',
    linkedSection: (label: 'Go to the festivals', path: AppRoutes.festivals),
  ),
  CultureArea(
    slug: 'traditional-practices',
    label: 'Traditional practices',
    description: 'Ceremonies, rites and the customs that mark a life.',
    icon: Icons.auto_awesome_outlined,
    prompt:
        'Birth, marriage, burial, initiation — what is done, by whom, and in what order. An elder '
        'describing a ceremony in their own words is worth more here than a summary.',
  ),
  CultureArea(
    slug: 'wrestling',
    label: 'Wrestling / KEPU',
    description: 'The wrestling tradition and the age sets it belongs to.',
    icon: Icons.sports_kabaddi_outlined,
    prompt:
        'How KEPU is held, who wrestles, what it marks, and who has been remembered for it. '
        'Photographs and the names of wrestlers are especially wanted.',
  ),
  CultureArea(
    slug: 'dances',
    label: 'Dances',
    description: 'Movement, music and the occasions each belongs to.',
    icon: Icons.music_note_outlined,
    prompt:
        'The name of each dance, the occasion it belongs to, who dances it and what is played. A '
        'recording of a performance, with the players named, is among the most valuable things '
        'this archive can receive.',
    linkedSection: (label: 'Cultural music', path: AppRoutes.music),
  ),
  CultureArea(
    slug: 'food',
    label: 'Food',
    description: 'What is cooked, how, and for which occasions.',
    icon: Icons.restaurant_outlined,
    prompt:
        'What is cooked, what goes into it, who cooks it, and which occasions call for it. A '
        'recipe as somebody actually makes it — not as a cookbook would write it — is what '
        'belongs here.',
  ),
  CultureArea(
    slug: 'clothing',
    label: 'Clothing',
    description: 'Dress, cloth, and what is worn when.',
    icon: Icons.checkroom_outlined,
    prompt:
        'What is worn, by whom, and on what occasion. The names of cloths and ornaments, and what '
        'each one signifies, are the part most easily lost.',
  ),
  CultureArea(
    slug: 'agriculture',
    label: 'Agriculture',
    description: 'Farming, the seasons, and the crops the community lives by.',
    icon: Icons.agriculture_outlined,
    prompt:
        'The farming year: what is planted when, how the seasons are read, and the work each one '
        'calls for. Yam in particular, since the festival turns on it.',
  ),
  CultureArea(
    slug: 'proverbs',
    label: 'Proverbs',
    description: 'Sayings, and what they are used to mean.',
    icon: Icons.format_quote_outlined,
    prompt:
        'The saying, what it literally says, and what it is actually used to mean — which is '
        'often something quite different. Proverbs can also be added straight to the dictionary.',
    linkedSection: (label: 'Add one to the dictionary', path: AppRoutes.contributeWord),
  ),
  CultureArea(
    slug: 'folklore',
    label: 'Folklore',
    description: 'Stories, riddles and the tales told to children.',
    icon: Icons.menu_book_outlined,
    prompt:
        'The stories told to children, the riddles, and who told them. Recorded in the voice of '
        'the person telling it, if you can — the telling is half the story.',
  ),
  CultureArea(
    slug: 'oral-history',
    label: 'Oral history',
    description: 'What elders remember, recorded in their own voices.',
    icon: Icons.record_voice_over_outlined,
    prompt:
        'What an elder remembers, recorded as they say it. This is the most urgent part of the '
        'archive: it is the only part with a deadline nobody sets.',
  ),
  CultureArea(
    slug: 'traditional-institutions',
    label: 'Traditional institutions',
    description: 'The bodies that hold authority and how they work.',
    icon: Icons.account_balance_outlined,
    prompt:
        'Which bodies hold authority, how somebody comes to sit on one, and what each decides. '
        'Named office-holders belong under Leadership.',
    linkedSection: (label: 'Leadership', path: AppRoutes.leaders),
  ),
  CultureArea(
    slug: 'community-life',
    label: 'Community life',
    description: 'Age grades, associations, and how the community organises itself.',
    icon: Icons.diversity_3_outlined,
    prompt:
        'How the community organises itself, and who does what. Age grades keep their own pages '
        'here — if you belong to one, you can register it and run its page yourself.',
    linkedSection: (label: 'Age grades', path: AppRoutes.ageGrades),
  ),
];

/// Finds an area by its slug, or null where the link does not match one.
CultureArea? cultureAreaFor(String slug) {
  for (final CultureArea area in cultureAreas) {
    if (area.slug == slug) return area;
  }
  return null;
}

class CultureListPage extends StatelessWidget {
  const CultureListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.culture,
      seo: const SeoMetadata(
        title: 'Culture & Heritage',
        description:
            'Traditions, festivals, practices, food, dress, farming, proverbs and community life '
            'of Ekoli-Yeden, documented and verified by the Preservation Team.',
        canonicalPath: AppRoutes.culture,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'Heritage',
            titleKey: 'page.culture.title',
            titleFallback: 'Culture & Heritage',
            introKey: 'page.culture.intro',
            introFallback:
                'Traditions, festivals, practices, food, dress, farming, proverbs and community '
                'life. This section grows as the Preservation Team documents and verifies each area.',
            accent: AppColors.green,
          ),

          const PageSection(
            title: 'Areas of the cultural archive',
            description:
                'These are the areas the archive is built to hold. Open any one to see what has '
                'been recorded in it and to add what you know. Each is filled by the Preservation '
                'Team as material is collected and verified — nothing here has been written from '
                'assumption.',
            child: _CategoryGrid(),
          ),

          PageSection(
            background: theme.colorScheme.surfaceContainerHigh,
            title: 'Published articles',
            child: AsyncContent<PaginatedResult<ContentRecord>>(
              load: () => context.contentRepository('culture').list(perPage: 24),
              loadingMessage: 'Opening the cultural archive…',
              isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.auto_stories_outlined,
                title: 'No cultural articles published yet',
                message:
                    'Our cultural archive is being prepared. Articles on each area above will '
                    'appear here as they are written, sourced and verified.',
              ),
              builder: (BuildContext context, PaginatedResult<ContentRecord> result) {
                return ResponsiveCardGrid(
                  children: result.items
                      .map(
                        (ContentRecord record) => ContentCard(
                          record: record,
                          path: AppRoutes.cultureEntry(record.pathSegment),
                          metaLine: record.category,
                          showVerification: true,
                        ),
                      )
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

/// The areas of the cultural archive, each one a door rather than a label.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    final int columns = context.gridColumns(max: 4);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: cultureAreas
              .map(
                (CultureArea area) => SizedBox(
                  width: width,
                  child: _AreaCard(area: area),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area});

  final CultureArea area;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: () => context.go(AppRoutes.cultureArea(area.slug)),
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(area.icon, size: 22, color: AppColors.green),
              const Gap.md(),
              Text(area.label, style: theme.textTheme.titleSmall),
              const Gap.xs(),
              Text(area.description, style: theme.textTheme.bodySmall),
              const Gap.md(),
              Row(
                children: <Widget>[
                  Text(
                    'Open',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.greenDark),
                  ),
                  const Gap.hSm(),
                  const Icon(Icons.arrow_forward, size: 14, color: AppColors.greenDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CultureDetailPage extends StatelessWidget {
  const CultureDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'culture',
      identifier: slug,
      basePath: AppRoutes.culture,
      sectionTitle: 'Culture',
      showVerification: true,
      showSources: true,
      showContributors: true,
      detailFields: const <DetailField>[
        DetailField(label: 'Category', key: 'category'),
        DetailField(label: 'Subtitle', key: 'subtitle'),
      ],
    );
  }
}

/// THE PRESERVATION TEAM.
class PreservationTeamPage extends StatelessWidget {
  const PreservationTeamPage({super.key});

  static const List<({String title, String responsibility})> positions =
      <({String title, String responsibility})>[
    (
      title: 'Coordinator',
      responsibility: 'Leads the team, sets priorities and represents it to community leadership.'
    ),
    (
      title: 'Secretary',
      responsibility: 'Keeps the record of meetings, decisions and the register of volunteers.'
    ),
    (
      title: 'History & Research Team',
      responsibility:
          'Gathers and documents history, leadership records and historical materials, with sources.'
    ),
    (
      title: 'Language Preservation Team',
      responsibility:
          'Collects Ekoli words, meanings and proverbs from native speakers, and records pronunciation.'
    ),
    (
      title: 'Media Team',
      responsibility:
          'Captures and catalogues photographs, audio and video, and maintains the video archive.'
    ),
    (
      title: 'Technology Team',
      responsibility: 'Maintains the platform, its deployments, backups and security.'
    ),
    (
      title: 'Verification Team',
      responsibility:
          'Checks historical claims, leadership records and language entries before they are marked verified.'
    ),
    (
      title: 'Community Outreach Team',
      responsibility:
          'Reaches elders, families and people abroad to collect materials and encourage contributions.'
    ),
    (
      title: 'Archive Team',
      responsibility:
          'Organises, labels and preserves accepted materials so they remain findable for future generations.'
    ),
    (
      title: 'Volunteers',
      responsibility: 'Contribute materials and assist the teams as needed.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.preservationTeam,
      seo: const SeoMetadata(
        title: 'The Ekoli-Yeden Preservation Team',
        description:
            'The volunteer organisation that collects, verifies and preserves the material in the '
            'Ekoli Yeden Digital Home.',
        canonicalPath: AppRoutes.preservationTeam,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'Volunteers',
            titleKey: 'page.preservation_team.title',
            titleFallback: 'The Ekoli-Yeden Preservation Team',
            introKey: 'page.preservation_team.intro',
            introFallback:
                'The volunteer organisation that collects, checks and preserves the material in '
                'this archive.',
            accent: AppColors.green,
          ),
          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The work of this team is what separates a verified community record from a '
                  'collection of unchecked claims. Nothing is published as fact until somebody '
                  'with the standing to confirm it has done so.',
                  style: theme.textTheme.bodyLarge,
                ),
                const Gap.xxl(),
                Text('Positions', style: theme.textTheme.headlineSmall),
                const Gap.sm(),
                Text(
                  'The structure below is the shape of the organisation. No member is named here '
                  'yet — appointments are recorded once the community has constituted the team.',
                  style: theme.textTheme.bodySmall,
                ),
                const Gap.xl(),
                ...positions.map(
                  (({String title, String responsibility}) position) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: AppRadius.smAll,
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(position.title, style: theme.textTheme.titleMedium),
                          const Gap.xs(),
                          Text(position.responsibility, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap.xl(),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.contribute),
                  icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                  label: const Text('Offer to help'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
