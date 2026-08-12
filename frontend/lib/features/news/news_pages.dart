import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// NEWS & COMMUNITY INFORMATION.
///
/// Social media stays the way news is distributed. This is where it is
/// permanently recorded — a Facebook post from today is nearly impossible to
/// find in five years, and a WhatsApp message disappears entirely.
class NewsListPage extends StatelessWidget {
  const NewsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'news',
      basePath: AppRoutes.news,
      eyebrow: 'Community',
      title: 'News & Announcements',
      descriptionKey: 'page.news.intro',
      description:
          'Official community news, announcements, appointments, achievements and notices. '
          'Published here permanently, and shared onward through social media.',
      emptyTitle: 'No news published yet',
      emptyMessage:
          'Community news and announcements will appear here as they are published by the '
          'administrators.',
      metaBuilder: (ContentRecord record) {
        final String date = Formatters.date(record.text('published_at'), fallback: '');
        final String? author = record.text('author_name');
        if (date.isNotEmpty && author != null) return '$date · $author';
        return date.isEmpty ? author : date;
      },
    );
  }
}

class NewsDetailPage extends StatelessWidget {
  const NewsDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'news',
      identifier: slug,
      basePath: AppRoutes.news,
      sectionTitle: 'News',
      detailFields: <DetailField>[
        DetailField(
          label: 'Published',
          key: 'published_at',
          formatter: (dynamic value) => Formatters.date(value.toString()),
        ),
        const DetailField(label: 'Author', key: 'author_name'),
        const DetailField(label: 'Category', key: 'category'),
      ],
    );
  }
}
