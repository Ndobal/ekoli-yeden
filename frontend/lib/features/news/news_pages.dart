import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
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
      // The invitation belongs on the page where somebody has just failed to
      // find what they came looking for. A member who hears something first
      // should not have to go hunting for a form.
      footer: const _SendInNews(),
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

/// The invitation to send news in.
///
/// Deliberately says who publishes it. Somebody deciding whether to bother
/// wants to know that a person reads it, and that they are not posting
/// straight to the community's front page.
class _SendInNews extends StatelessWidget {
  const _SendInNews();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.xxl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Do you know something the community should?', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          Text(
            'A borehole finished, a scholarship deadline moved, somebody appointed, somebody '
            'gone. Write it here and an administrator will read it — they decide what is '
            'published under the community’s name.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.lg(),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.contributeNews),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Send in news'),
          ),
        ],
      ),
    );
  }
}
