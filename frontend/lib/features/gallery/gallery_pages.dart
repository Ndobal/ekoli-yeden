import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// THE PHOTO GALLERY.
///
/// A gallery is an ordered set of photographs plus the labels that turn a
/// picture into an archive record: who is in it, where, when, and who took it.
/// Those labels are what make a photograph findable in fifty years; an
/// unlabelled photograph is preserved but not yet documented, and the archive
/// says which it is.
class GalleryListPage extends StatelessWidget {
  const GalleryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'galleries',
      basePath: AppRoutes.gallery,
      eyebrow: 'Photographs',
      title: 'Gallery',
      descriptionKey: 'page.gallery.intro',
      description:
          'Photographs of Ekoli-Yeden — its people, ceremonies, festivals, schools and everyday '
          'life — labelled with what they show so they can still be understood by people who were '
          'not there.',
      emptyTitle: 'The gallery is being prepared',
      emptyMessage:
          'Our community archive is being prepared. Historical and contemporary photographs will '
          'appear here as they are collected, labelled and verified.',
      maxColumns: 3,
      metaBuilder: (ContentRecord record) {
        final String date = Formatters.date(record.text('event_date'), fallback: '');
        final String? location = record.text('location');
        if (date.isNotEmpty && location != null) return '$date · $location';
        return date.isEmpty ? location : date;
      },
    );
  }
}

class GalleryDetailPage extends StatelessWidget {
  const GalleryDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'galleries',
      identifier: slug,
      basePath: AppRoutes.gallery,
      sectionTitle: 'Gallery',
      showContributors: true,
      detailFields: <DetailField>[
        const DetailField(label: 'Category', key: 'category'),
        DetailField(
          label: 'Date',
          key: 'event_date',
          formatter: (dynamic value) => Formatters.date(value.toString()),
        ),
        const DetailField(label: 'Location', key: 'location'),
      ],
    );
  }
}
