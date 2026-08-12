import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// EKOLI-YEDEN HISTORY & HERITAGE.
///
/// The historical archive. Each entry carries its period, its source and
/// whether the Preservation Team has verified it — because an archive that
/// cannot say where a claim came from is not an archive.
class HistoryListPage extends StatelessWidget {
  const HistoryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'history',
      basePath: AppRoutes.history,
      eyebrow: 'Heritage',
      title: 'Our History',
      descriptionKey: 'page.history.intro',
      description:
          'The recorded history of Ekoli-Yeden: its origins, its important events, its traditional '
          'institutions and the accounts held by its elders. Each entry names its source, and shows '
          'whether it has been verified.',
      emptyTitle: 'The historical record is not yet published',
      emptyMessage:
          'No history has been entered yet. Nothing has been written here from guesswork — the '
          'Ekoli-Yeden Preservation Team is collecting accounts, documents and photographs from '
          'elders and families, and they will appear here once verified.',
      showVerification: true,
      // A period matters more than an exact date for much of this material:
      // "before 1900" is often the most honest thing anyone can say.
      metaBuilder: (ContentRecord record) =>
          record.text('period_label') ??
          record.text('era') ??
          Formatters.date(record.text('event_date'), fallback: ''),
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'history',
      identifier: slug,
      basePath: AppRoutes.history,
      sectionTitle: 'History',
      showVerification: true,
      // History is the section where provenance matters most: every entry shows
      // its citations and credits whoever supplied the material.
      showSources: true,
      showContributors: true,
      detailFields: <DetailField>[
        const DetailField(label: 'Period', key: 'period_label'),
        DetailField(
          label: 'Date',
          key: 'event_date',
          formatter: (dynamic value) => Formatters.date(value.toString()),
        ),
        const DetailField(label: 'Era', key: 'era'),
        const DetailField(label: 'Location', key: 'location'),
        const DetailField(label: 'Recorded by', key: 'contributed_by'),
      ],
    );
  }
}
