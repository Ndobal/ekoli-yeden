import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// EKOLI-YEDEN TRADITIONAL INSTITUTION & LEADERSHIP.
///
/// A verified record of the community's leadership, so that future generations
/// have a reliable account rather than a contested one. Every profile shows its
/// verification state, and no name appears here that the community has not
/// supplied.
class LeadershipListPage extends StatelessWidget {
  const LeadershipListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'leaders',
      basePath: AppRoutes.leaders,
      eyebrow: 'Traditional institution',
      title: 'Leadership',
      descriptionKey: 'page.leaders.intro',
      description:
          'Traditional rulers, chiefs, the council and community leadership — past and present. '
          'This record is maintained with the traditional institution and is verified before '
          'publication.',
      emptyTitle: 'The leadership record is not yet published',
      emptyMessage:
          'No leadership information has been entered. Names, titles and profiles will be published '
          'only once they have been supplied and confirmed by the traditional institution and the '
          'Ekoli-Yeden Preservation Team.',
      showVerification: true,
      maxColumns: 4,
      metaBuilder: (ContentRecord record) {
        final String? title = record.text('traditional_title');
        final String? area = record.text('area_represented');
        if (title != null && area != null) return '$title · $area';
        return title ?? area;
      },
    );
  }
}

class LeaderDetailPage extends StatelessWidget {
  const LeaderDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'leaders',
      identifier: slug,
      basePath: AppRoutes.leaders,
      sectionTitle: 'Leadership',
      showVerification: true,
      showSource: true,
      detailFields: <DetailField>[
        const DetailField(label: 'Traditional title', key: 'traditional_title'),
        const DetailField(label: 'Role', key: 'role_description'),
        const DetailField(label: 'Area represented', key: 'area_represented'),
        const DetailField(label: 'From', key: 'reign_start'),
        const DetailField(label: 'Until', key: 'reign_end'),
        const DetailField(label: 'Contributions', key: 'contributions'),
      ],
    );
  }
}
