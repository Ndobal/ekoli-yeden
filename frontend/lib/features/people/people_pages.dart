import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// PEOPLE OF EKOLI-YEDEN.
///
/// Profiles of scholars, professionals, artists, athletes, clergy and community
/// builders. A living person's profile is personal data, not archive material,
/// so the underlying record carries a consent reference and nothing is
/// published without it.
class PeopleListPage extends StatelessWidget {
  const PeopleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'people',
      basePath: AppRoutes.people,
      eyebrow: 'Our people',
      title: 'People of Ekoli-Yeden',
      description:
          'Scholars, professionals, artists, entrepreneurs, athletes, clergy and community builders '
          'from Ekoli-Yeden and its diaspora.',
      emptyTitle: 'No profiles published yet',
      emptyMessage:
          'Profiles are added once the person, or their family, has agreed to be listed and the '
          'information has been confirmed. If you would like to nominate someone, please use the '
          'contribution page.',
      maxColumns: 4,
      metaBuilder: (ContentRecord record) {
        final String? profession = record.text('profession');
        final String? city = record.text('city');
        final String? country = record.text('country');
        final String place = <String?>[city, country].whereType<String>().join(', ');
        if (profession != null && place.isNotEmpty) return '$profession · $place';
        return profession ?? (place.isEmpty ? null : place);
      },
    );
  }
}

class PersonDetailPage extends StatelessWidget {
  const PersonDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'people',
      identifier: slug,
      basePath: AppRoutes.people,
      sectionTitle: 'People',
      detailFields: <DetailField>[
        const DetailField(label: 'Profession', key: 'profession'),
        const DetailField(label: 'Category', key: 'category'),
        const DetailField(label: 'City', key: 'city'),
        const DetailField(label: 'Country', key: 'country'),
        const DetailField(label: 'Achievements', key: 'achievements'),
        const DetailField(label: 'Website', key: 'website_url'),
      ],
    );
  }
}
