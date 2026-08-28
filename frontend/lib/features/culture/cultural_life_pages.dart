import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// CULTURAL GROUPS AND CULTURAL MUSIC.
///
/// Two parts of community life that the community named directly. Each is a
/// registered content type of its own rather than a paragraph inside the
/// culture page, because each will eventually hold many records — every group,
/// every musical form — and each deserves its own address.
///
/// Age grades were a third, and have moved to `features/age_grades/`. They
/// outgrew this file: unlike a group or a musical form, an age grade has living
/// members and its own administrators, and it keeps its own page rather than
/// waiting for an editor to write one.
///
/// The names seeded so far came from a member of the community. Everything
/// beyond the names is left to be documented, and each record says so.

/// CULTURAL GROUPS — Obam, Igban and the others.
class CulturalGroupsListPage extends StatelessWidget {
  const CulturalGroupsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentListPage(
      resource: 'cultural-groups',
      basePath: AppRoutes.culturalGroups,
      eyebrow: 'Cultural life',
      title: 'Cultural Groups',
      descriptionKey: 'page.cultural_groups.intro',
      description:
          'The cultural groups of Ekoli-Yeden — among them Obam and Igban. Each carries its own '
          'practice, its own occasions and its own membership.',
      emptyTitle: 'No groups recorded yet',
      emptyMessage:
          'The cultural groups of the community will be listed here as they are documented.',
      showVerification: true,
      maxColumns: 3,
    );
  }
}

class CulturalGroupDetailPage extends StatelessWidget {
  const CulturalGroupDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'cultural-groups',
      identifier: slug,
      basePath: AppRoutes.culturalGroups,
      sectionTitle: 'Cultural Groups',
      showVerification: true,
      showSources: true,
      showContributors: true,
      detailFields: const <DetailField>[
        DetailField(label: 'Type', key: 'subtitle'),
      ],
    );
  }
}

/// CULTURAL MUSIC — Onene and the others.
class CulturalMusicListPage extends StatelessWidget {
  const CulturalMusicListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentListPage(
      resource: 'music',
      basePath: AppRoutes.music,
      eyebrow: 'Cultural life',
      title: 'Cultural Music',
      descriptionKey: 'page.music.intro',
      description:
          'The musical forms of Ekoli-Yeden — among them Onene. Music is the part of a heritage '
          'that written words preserve worst, which is why a recording matters here more than a '
          'description.',
      emptyTitle: 'No musical forms recorded yet',
      emptyMessage:
          'The musical traditions of the community will be listed here as they are documented. '
          'A recording of a performance, with the players named and the occasion given, is among '
          'the most valuable things this archive can receive.',
      showVerification: true,
      maxColumns: 3,
    );
  }
}

class CulturalMusicDetailPage extends StatelessWidget {
  const CulturalMusicDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'music',
      identifier: slug,
      basePath: AppRoutes.music,
      sectionTitle: 'Cultural Music',
      showVerification: true,
      showSources: true,
      showContributors: true,
      detailFields: const <DetailField>[
        DetailField(label: 'Type', key: 'subtitle'),
      ],
    );
  }
}
