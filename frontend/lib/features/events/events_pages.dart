import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// EVENTS.
///
/// Meetings, ceremonies and gatherings. An event may stand alone or belong to a
/// festival edition, which is how a Leboku programme is assembled.
class EventsListPage extends StatelessWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'events',
      basePath: AppRoutes.events,
      eyebrow: 'What is happening',
      title: 'Events',
      descriptionKey: 'page.events.intro',
      description:
          'Community meetings, ceremonies, cultural activities and gatherings — those coming up, '
          'and those already held.',
      emptyTitle: 'No events published yet',
      emptyMessage: 'Events will appear here once they are added by the administrators.',
      metaBuilder: (ContentRecord record) {
        final String when = Formatters.dateRange(
          record.text('start_datetime'),
          record.text('end_datetime'),
          fallback: '',
        );
        final String? venue = record.text('venue') ?? record.text('location');
        if (when.isNotEmpty && venue != null) return '$when · $venue';
        return when.isEmpty ? venue : when;
      },
    );
  }
}

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'events',
      identifier: slug,
      basePath: AppRoutes.events,
      sectionTitle: 'Events',
      detailFields: <DetailField>[
        DetailField(
          label: 'Starts',
          key: 'start_datetime',
          formatter: (dynamic value) => Formatters.dateTime(value.toString()),
        ),
        DetailField(
          label: 'Ends',
          key: 'end_datetime',
          formatter: (dynamic value) => Formatters.dateTime(value.toString()),
        ),
        const DetailField(label: 'Venue', key: 'venue'),
        const DetailField(label: 'Location', key: 'location'),
        const DetailField(label: 'Organiser', key: 'organiser'),
        const DetailField(label: 'Contact', key: 'contact_info'),
      ],
    );
  }
}
