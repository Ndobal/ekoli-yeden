import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/news.dart';
import '../../repositories/news_portal_repository.dart';
import 'news_blocks.dart';
import 'news_portal_page.dart' show NewsCard;

/// ONE STORY.
///
/// ---------------------------------------------------------------------------
/// WHAT A PERMANENT RECORD HAS TO CARRY
/// ---------------------------------------------------------------------------
///
/// Not just the words. A community's account of an event is the words, the
/// photographs somebody took, the recording somebody made, the date it actually
/// happened, where it happened, who said so, and how they knew.
///
/// All of that is on this page, and the two that are usually lost are the two
/// this page is most careful about:
///
///   **Who sent it in.** Held on the record rather than in the article text, so
///   it survives every later edit. An editor cannot remove it by rewording a
///   paragraph, because it is not in the paragraph.
///
///   **Where it came from.** A story from somebody who was present is a
///   different thing from one read in a group chat, and the page says which.
class NewsArticlePage extends StatelessWidget {
  const NewsArticlePage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return AsyncContent<NewsStory>(
      key: ValueKey<String>(slug),
      load: () => context.read<NewsPortalRepository>().story(slug),
      loadingMessage: 'Opening the story…',
      builder: (BuildContext context, NewsStory story) => _Article(story: story),
    );
  }
}

class _Article extends StatelessWidget {
  const _Article({required this.story});

  final NewsStory story;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NewsSummary summary = story.summary;

    return AppScaffold(
      currentPath: AppRoutes.news,
      seo: SeoMetadata(
        title: summary.title,
        description: summary.excerpt ?? 'News from Ekoli-Yeden.',
        canonicalPath: AppRoutes.newsItem(summary.slug),
        type: 'article',
      ),
      child: Column(
        children: <Widget>[
          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.news),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('All the news'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                const Gap.lg(),

                if (summary.categoryName != null)
                  Text(
                    summary.categoryName!.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.goldDark,
                      letterSpacing: 1.6,
                    ),
                  ),
                const Gap.sm(),
                SelectableText(
                  summary.title,
                  style: context.isMobile
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.displaySmall?.copyWith(height: 1.15),
                ),

                if (summary.excerpt != null) ...<Widget>[
                  const Gap.lg(),
                  SelectableText(
                    summary.excerpt!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],

                const Gap.xl(),
                _Byline(story: story),
                const Gap.xl(),
                const Divider(height: 1),
              ],
            ),
          ),

          // The cover, full width of the reading measure.
          if (summary.coverUrl != null)
            PageSection(
              reading: true,
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: Image.network(
                  summary.coverUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),

          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NewsBody(blocks: story.body, media: story.media),

                // The photographs the body did not place itself.
                if (_gallery.isNotEmpty) ...<Widget>[
                  const Gap.section(),
                  Text('Photographs', style: theme.textTheme.titleLarge),
                  const Gap.lg(),
                  _Gallery(photographs: _gallery),
                ],

                if (story.videos.isNotEmpty) ...<Widget>[
                  const Gap.section(),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.play_circle_outline, color: AppColors.gold),
                      const Gap.hMd(),
                      Text('Watch', style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const Gap.lg(),
                  ...story.videos.map(
                    (NewsMedia video) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: NewsVideo(
                        youtubeId: video.youtubeId!,
                        title: video.videoTitle ?? video.caption,
                      ),
                    ),
                  ),
                ],

                if (story.tags.isNotEmpty) ...<Widget>[
                  const Gap.section(),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: story.tags
                        .map(
                          (({String slug, String name}) tag) =>
                              Chip(label: Text(tag.name)),
                        )
                        .toList(growable: false),
                  ),
                ],

                const Gap.section(),
                _Attribution(story: story),

                if (story.sources.isNotEmpty) ...<Widget>[
                  const Gap.xxl(),
                  _Sources(sources: story.sources),
                ],

                const Gap.xxl(),
                _ShareRow(story: summary),
              ],
            ),
          ),

          if (story.related.isNotEmpty)
            PageSection(
              background: theme.colorScheme.surfaceContainerHigh,
              title: 'More from Ekoli-Yeden',
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.xl,
                children: story.related
                    .map(
                      (NewsSummary related) => SizedBox(
                        width: context.isMobile ? double.infinity : 300,
                        child: NewsCard(story: related, compact: true),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  /// The photographs, minus the cover and minus any the body already placed —
  /// so a picture used inline does not appear a second time underneath.
  List<NewsMedia> get _gallery {
    final Set<String> placed = story.body
        .where((NewsBlock block) => block.type == 'image' && block.mediaId != null)
        .map((NewsBlock block) => block.mediaId!)
        .toSet();

    return story.photographs
        .where((NewsMedia photograph) => !placed.contains(photograph.id))
        .toList(growable: false);
  }
}

/// The date, the place, and who wrote it.
class _Byline extends StatelessWidget {
  const _Byline({required this.story});

  final NewsStory story;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NewsSummary summary = story.summary;

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (summary.newsDate != null)
          _Fact(icon: Icons.event_outlined, text: Formatters.date(summary.newsDate)),
        if (summary.location != null)
          _Fact(icon: Icons.place_outlined, text: summary.location!),
        if (summary.authorName != null)
          _Fact(icon: Icons.edit_outlined, text: summary.authorName!),
        if (summary.publishedAt != null && summary.publishedAt != summary.newsDate)
          Text(
            'Published ${Formatters.relative(summary.publishedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const Gap.hSm(),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// The photographs, in a grid, opening full size on a press.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.photographs});

  final List<NewsMedia> photographs;

  @override
  Widget build(BuildContext context) {
    final int columns = context.isMobile ? 2 : 3;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.md;
        final double size = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: photographs
              .map(
                (NewsMedia photograph) => SizedBox(
                  width: size,
                  child: GestureDetector(
                    onTap: () => _open(context, photograph),
                    child: ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          photograph.url!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  /// The lightbox.
  ///
  /// Carries the caption and the credit, because a photograph seen full size is
  /// exactly the moment somebody wants to know what it shows and who took it.
  void _open(BuildContext context, NewsMedia photograph) {
    final int index = photographs.indexOf(photograph);

    showDialog<void>(
      context: context,
      barrierColor: const Color(0xF2000000),
      builder: (BuildContext dialogContext) =>
          _Lightbox(photographs: photographs, initial: index < 0 ? 0 : index),
    );
  }
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.photographs, required this.initial});

  final List<NewsMedia> photographs;
  final int initial;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _index = widget.initial;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NewsMedia photograph = widget.photographs[_index];

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.network(photograph.url!, fit: BoxFit.contain),
            ),
          ),

          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.lg,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          if (widget.photographs.length > 1) ...<Widget>[
            Positioned(
              left: AppSpacing.sm,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 34),
                  onPressed: _index > 0 ? () => setState(() => _index -= 1) : null,
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 34),
                  onPressed: _index < widget.photographs.length - 1
                      ? () => setState(() => _index += 1)
                      : null,
                ),
              ),
            ),
          ],

          if (photograph.creditLine != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: const Color(0xCC000000),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        photograph.creditLine!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                      if (widget.photographs.length > 1) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          '${_index + 1} of ${widget.photographs.length}',
                          style: theme.textTheme.labelSmall?.copyWith(color: OnDark.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// WHO SENT IT IN, AND WHO PUBLISHED IT.
///
/// Two different statements, and the page makes both. A member's account of
/// what happened, and the Editorial Team's decision to put it out under the
/// community's name, are not the same claim — and the person who was standing
/// there keeps their name on it whatever is edited afterwards.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.story});

  final NewsStory story;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? contributor = story.summary.contributorName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (contributor != null) ...<Widget>[
            Text('SENT IN BY', style: theme.textTheme.labelSmall),
            const Gap.xs(),
            Text(contributor, style: theme.textTheme.titleMedium),
            if (story.sourceNote != null) ...<Widget>[
              const Gap.sm(),
              Text(
                'How they knew: ${story.sourceNote}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Gap.lg(),
          ],
          Text('PUBLISHED BY', style: theme.textTheme.labelSmall),
          const Gap.xs(),
          Text('The Ekoli-Yeden Editorial Team', style: theme.textTheme.bodyLarge),
          const Gap.md(),
          Text(
            contributor != null
                ? 'Edited and published by the Editorial Team. The account above is '
                      '$contributor’s, and their name stays on it.'
                : 'Written and published by the Editorial Team.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the story came from.
class _Sources extends StatelessWidget {
  const _Sources({required this.sources});

  final List<NewsSource> sources;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Sources', style: theme.textTheme.titleMedium),
        const Gap.md(),
        ...sources.map(
          (NewsSource source) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.source_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const Gap.hMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        source.title ?? source.typeLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        <String?>[
                          source.typeLabel,
                          source.author,
                          source.publisher,
                        ].whereType<String>().join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (source.url != null)
                        SelectableText(
                          source.url!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.navyLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Copying the link.
///
/// The archive expects to be shared onward into WhatsApp — that is how news
/// travels here — so the one thing this needs to do well is hand over a link.
class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.story});

  final NewsSummary story;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () async {
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(
              ClipboardData(text: 'https://ekoli.pages.dev${AppRoutes.newsItem(story.slug)}'),
            );
            messenger.showSnackBar(
              const SnackBar(content: Text('Link copied. Share it wherever it should go.')),
            );
          },
          icon: const Icon(Icons.link, size: 18),
          label: const Text('Copy the link'),
        ),
        const Gap.hLg(),
        Flexible(
          child: Text(
            'Share it on WhatsApp or Facebook — the story stays here either way.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
