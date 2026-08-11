import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/video.dart';
import '../../repositories/video_repository.dart';
import '../../services/api/api_response.dart';

/// THE EKOLI-YEDEN VIDEO ARCHIVE.
///
/// Every video is hosted on YouTube, which is deliberate: it costs the
/// community nothing, it works on a slow connection, and the videos already
/// published there can be catalogued here without being re-uploaded anywhere.
/// What this archive adds is organisation — categories, transcripts and a
/// permanent link — which is the difference between a video existing and a
/// video being findable in twenty years.
class VideosListPage extends StatefulWidget {
  const VideosListPage({super.key});

  @override
  State<VideosListPage> createState() => _VideosListPageState();
}

class _VideosListPageState extends State<VideosListPage> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final VideoRepository repository = context.read<VideoRepository>();

    return AppScaffold(
      currentPath: AppRoutes.videos,
      seo: const SeoMetadata(
        title: 'Video Archive',
        description:
            'Documentaries, interviews, oral history, festival performances, cultural events and '
            'music from Ekoli-Yeden, organised and preserved.',
        canonicalPath: AppRoutes.videos,
      ),
      child: PageSection(
        eyebrow: 'Video archive',
        title: 'Videos',
        description:
            'Documentaries, interviews, oral history recordings, festival performances, ceremonies '
            'and music. Videos are hosted on YouTube and organised here.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilterChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...VideoCategories.all.map(
                  (String category) => FilterChip(
                    label: Text(VideoCategories.label(category)),
                    selected: _category == category,
                    onSelected: (bool selected) =>
                        setState(() => _category = selected ? category : null),
                  ),
                ),
              ],
            ),
            const Gap.xxl(),
            AsyncContent<PaginatedResult<Video>>(
              key: ValueKey<String>('videos:$_category'),
              load: () => repository.list(category: _category, perPage: 24),
              loadingMessage: 'Opening the video archive…',
              isEmpty: (PaginatedResult<Video> result) => result.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.play_circle_outline,
                title: 'No videos catalogued yet',
                message:
                    'Videos published on YouTube can be added to this archive by the Media Team, '
                    'with their category, description and — where possible — a written transcript '
                    'so that what is said in them becomes searchable.',
              ),
              builder: (BuildContext context, PaginatedResult<Video> result) {
                return ResponsiveCardGrid(
                  children: result.items
                      .map((Video video) => VideoCard(video: video))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A video in a grid.
class VideoCard extends StatelessWidget {
  const VideoCard({required this.video, super.key});

  final Video video;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(AppRoutes.video(video.pathSegment)),
      borderRadius: AppRadius.mdAll,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ArchiveImage(
                  url: video.thumbnailUrl,
                  label: video.title,
                  aspectRatio: 16 / 9,
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xB3000000),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
                ),
                if (video.durationSeconds != null)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xCC000000),
                        borderRadius: AppRadius.xsAll,
                      ),
                      child: Text(
                        Formatters.duration(video.durationSeconds),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    video.categoryLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
                  ),
                  const Gap.sm(),
                  Text(
                    video.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap.xs(),
                  Row(
                    children: <Widget>[
                      Text(
                        Formatters.shortDate(video.publishedDate, fallback: 'Date not recorded'),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (video.hasTranscript) ...<Widget>[
                        const Gap.hSm(),
                        Icon(
                          Icons.subject,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One video, with its description and — where it exists — its transcript.
class VideoDetailPage extends StatelessWidget {
  const VideoDetailPage({required this.identifier, super.key});

  final String identifier;

  @override
  Widget build(BuildContext context) {
    final VideoRepository repository = context.read<VideoRepository>();

    return AsyncContent<Video>(
      key: ValueKey<String>('video:$identifier'),
      load: () => repository.find(identifier),
      loadingMessage: 'Opening the video…',
      builder: (BuildContext context, Video video) => _VideoDetail(video: video),
    );
  }
}

class _VideoDetail extends StatelessWidget {
  const _VideoDetail({required this.video});

  final Video video;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.videos,
      seo: SeoMetadata(
        title: video.title,
        description: video.description,
        imageUrl: video.thumbnailUrl,
        canonicalPath: AppRoutes.video(video.pathSegment),
        type: 'article',
        publishedAt: video.publishedDate,
      ),
      child: PageSection(
        reading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.videos),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to videos'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.lg(),

            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: ArchiveImage(
                url: video.thumbnailUrl,
                label: video.title,
                aspectRatio: 16 / 9,
              ),
            ),
            const Gap.lg(),

            // The player is added in Module 2. Until then the archive links out
            // to YouTube rather than pretending to embed — a broken player
            // would be worse than an honest link.
            FilledButton.icon(
              onPressed: () => _openExternal(context, video.watchUrl),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Watch on YouTube'),
            ),
            const Gap.xxl(),

            Text(
              video.categoryLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
            ),
            const Gap.sm(),
            Text(video.title, style: theme.textTheme.displaySmall),
            const Gap.md(),
            Row(
              children: <Widget>[
                Text(
                  Formatters.date(video.publishedDate, fallback: 'Date not recorded'),
                  style: theme.textTheme.bodySmall,
                ),
                if (video.speaker != null) ...<Widget>[
                  const Gap.hSm(),
                  Text('· ${video.speaker}', style: theme.textTheme.bodySmall),
                ],
              ],
            ),

            if (video.verificationStatus != null) ...<Widget>[
              const Gap.lg(),
              VerificationBadge(video.verificationStatus!),
            ],

            const Gap.xxl(),
            if (video.description != null)
              Text(video.description!, style: theme.textTheme.bodyLarge)
            else
              const AwaitingMaterialNote(
                message: 'A description for this video has not been supplied yet.',
              ),

            if (video.hasTranscript) ...<Widget>[
              const Gap.xxl(),
              Text('Transcript', style: theme.textTheme.headlineSmall),
              const Gap.md(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.smAll,
                ),
                child: SelectableText(video.transcript!, style: theme.textTheme.bodyMedium),
              ),
            ] else ...<Widget>[
              const Gap.xxl(),
              const AwaitingMaterialNote(
                message:
                    'No transcript has been recorded for this video. A written transcript makes an '
                    'oral-history recording searchable, and is one of the most valuable things a '
                    'volunteer can contribute.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the YouTube link.
  ///
  /// Shown as a copyable dialog rather than pulling in a URL-launcher plugin
  /// for one call — Module 2 replaces this with an in-page player.
  void _openExternal(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Watch on YouTube'),
        content: SelectableText(url),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
