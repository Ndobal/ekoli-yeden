import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// AGE GRADES, CULTURAL GROUPS AND CULTURAL MUSIC.
///
/// Three parts of community life that the community named directly. Each is a
/// registered content type of its own rather than a paragraph inside the
/// culture page, because each will eventually hold many records — every age
/// grade, every group, every musical form — and each deserves its own address.
///
/// The names seeded so far came from a member of the community. Everything
/// beyond the names is left to be documented, and each record says so.

class AgeGradesListPage extends StatelessWidget {
  const AgeGradesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentListPage(
      resource: 'age-grades',
      basePath: AppRoutes.ageGrades,
      eyebrow: 'Community structure',
      title: 'Age Grades',
      descriptionKey: 'page.age_grades.intro',
      description:
          'Age grades are one of the ways Ekoli-Yeden organises itself — groupings of people of a '
          'similar age who take on responsibilities together.',
      emptyTitle: 'No age grades recorded yet',
      emptyMessage:
          'Each age grade should have its own record here: its name, when it was formed, who '
          'belongs to it, and what it has done for the community. If you belong to a grade, or '
          'can name the grades and the years they were formed, please contribute.',
      showVerification: true,
      maxColumns: 3,
    );
  }
}

class AgeGradeDetailPage extends StatelessWidget {
  const AgeGradeDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'age-grades',
      identifier: slug,
      basePath: AppRoutes.ageGrades,
      sectionTitle: 'Age Grades',
      showVerification: true,
      showSources: true,
      showContributors: true,
      detailFields: const <DetailField>[
        DetailField(label: 'Also known as', key: 'subtitle'),
      ],
    );
  }
}

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
