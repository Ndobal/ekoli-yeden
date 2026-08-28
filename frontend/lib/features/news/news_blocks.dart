import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/video/youtube_embed.dart';
import '../../models/news.dart';

/// RENDERING A STORY.
///
/// ---------------------------------------------------------------------------
/// NATIVE WIDGETS, NOT AN HTML VIEW
/// ---------------------------------------------------------------------------
///
/// A story's body is a list of typed blocks — see `news.dart` and, on the
/// server, `news-content.ts`. Nothing in it can contain markup, so there is no
/// HTML to render and nothing to sanitise at this end: a paragraph is text, a
/// heading is text and a level, a link is a range with an address.
///
/// The consequences are worth stating, because they are why the design is this
/// way rather than a `WebView` with some sanitised HTML in it:
///
///   The story picks up the archive's own typography, spacing and dark mode
///   for free, and reads the same on a phone as on a desktop.
///
///   Text is selectable and searchable by the browser.
///
///   There is no path by which anything an editor pastes becomes script.
class NewsBody extends StatelessWidget {
  const NewsBody({required this.blocks, this.media = const <NewsMedia>[], super.key});

  final List<NewsBlock> blocks;

  /// The story's attachments, so an inline image block can be resolved to the
  /// photograph it names.
  final List<NewsMedia> media;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map((NewsBlock block) => _Block(block: block, media: media))
          .toList(growable: false),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block, required this.media});

  final NewsBlock block;
  final List<NewsMedia> media;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    switch (block.type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.md),
          child: SelectableText(
            block.text ?? '',
            style: switch (block.level) {
              2 => theme.textTheme.headlineSmall,
              3 => theme.textTheme.titleLarge,
              _ => theme.textTheme.titleMedium,
            },
          ),
        );

      case 'quote':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              border: const Border(left: BorderSide(color: AppColors.gold, width: 4)),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.md)),
            ),
            child: _RichText(
              text: block.text ?? '',
              marks: block.marks,
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );

      case 'bullet_list':
      case 'numbered_list':
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < block.items.length; index += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 28,
                        child: block.type == 'numbered_list'
                            ? Text(
                                '${index + 1}.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(top: 9, left: 4),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                      ),
                      Expanded(
                        child: SelectableText(
                          block.items[index],
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case 'image':
        final NewsMedia? photograph = _find(block.mediaId);
        if (photograph?.url == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: NewsPhotograph(photograph: photograph!, caption: block.caption),
        );

      case 'video':
        if (block.youtubeId == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: NewsVideo(
            youtubeId: block.youtubeId!,
            title: block.caption,
          ),
        );

      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Divider(height: 1),
        );

      case 'table':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: (block.rows.isEmpty ? const <String>[] : block.rows.first)
                  .map((String heading) => DataColumn(label: Text(heading)))
                  .toList(growable: false),
              rows: block.rows
                  .skip(1)
                  .map(
                    (List<String> row) => DataRow(
                      cells: row.map((String cell) => DataCell(Text(cell))).toList(growable: false),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _RichText(
            text: block.text ?? '',
            marks: block.marks,
            // Generous line height. This is long-form prose that people will
            // read on a phone, and cramped lines are where they stop.
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
            align: block.align,
          ),
        );
    }
  }

  NewsMedia? _find(String? id) {
    if (id == null) return null;
    for (final NewsMedia item in media) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// Text with bold, italic and links applied over ranges.
///
/// Built by walking the marks and cutting the string at every boundary, rather
/// than by nesting spans: marks may overlap, and overlapping ranges are exactly
/// where a nesting approach produces either a crash or silently dropped
/// formatting.
class _RichText extends StatelessWidget {
  const _RichText({required this.text, required this.marks, this.style, this.align});

  final String text;
  final List<NewsMark> marks;
  final TextStyle? style;
  final String? align;

  @override
  Widget build(BuildContext context) {
    final TextAlign textAlign = switch (align) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.start,
    };

    if (marks.isEmpty) {
      return SelectableText(text, style: style, textAlign: textAlign);
    }

    // Every point where formatting starts or stops.
    final Set<int> boundaries = <int>{0, text.length};
    for (final NewsMark mark in marks) {
      if (mark.start >= 0 && mark.start <= text.length) boundaries.add(mark.start);
      if (mark.end >= 0 && mark.end <= text.length) boundaries.add(mark.end);
    }

    final List<int> points = boundaries.toList()..sort();
    final List<InlineSpan> spans = <InlineSpan>[];

    for (int index = 0; index < points.length - 1; index += 1) {
      final int start = points[index];
      final int end = points[index + 1];
      if (end <= start) continue;

      final List<NewsMark> active = marks
          .where((NewsMark mark) => mark.start <= start && mark.end >= end)
          .toList(growable: false);

      final bool bold = active.any((NewsMark mark) => mark.type == 'bold');
      final bool italic = active.any((NewsMark mark) => mark.type == 'italic');
      final NewsMark? link = active
          .where((NewsMark mark) => mark.type == 'link' && mark.href != null)
          .firstOrNull;

      TextStyle segment = (style ?? const TextStyle()).copyWith(
        fontWeight: bold ? FontWeight.w700 : null,
        fontStyle: italic ? FontStyle.italic : null,
      );

      if (link != null) {
        segment = segment.copyWith(
          color: AppColors.navyLight,
          decoration: TextDecoration.underline,
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: segment,
          recognizer: link == null
              ? null
              : (TapGestureRecognizer()
                  ..onTap = () {
                    final String href = link.href!;
                    // A path on this site is navigated in place. An external
                    // address is left to the browser rather than opened by the
                    // app, which is the only sensible thing a Flutter page can
                    // do with somebody else's URL.
                    if (href.startsWith('/')) context.go(href);
                  }),
        ),
      );
    }

    return SelectableText.rich(TextSpan(children: spans), textAlign: textAlign);
  }
}

/// One photograph, with its caption and its credit.
///
/// The credit belongs to the photograph and not to the article: eleven pictures
/// of one meeting are often taken by three people, and an article-level
/// "photographs by" line quietly takes two of them off the record.
class NewsPhotograph extends StatelessWidget {
  const NewsPhotograph({required this.photograph, this.caption, this.onTap, super.key});

  final NewsMedia photograph;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? line = caption ?? photograph.caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: GestureDetector(
            onTap: onTap,
            child: Semantics(
              label: photograph.altText ?? line,
              image: true,
              child: Image.network(
                photograph.url!,
                width: double.infinity,
                fit: BoxFit.cover,
                // Lazy by nature on the web: the browser does not fetch what is
                // not in view, and a story with fourteen photographs must not
                // cost fourteen images on first paint.
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
                  if (progress == null) return child;
                  return AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (line != null || photograph.photographer != null) ...<Widget>[
          const Gap.sm(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(width: 3, height: 32, color: AppColors.gold),
              const Gap.hMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (line != null)
                      Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (photograph.photographer != null)
                      Text(
                        'Photograph: ${photograph.photographer}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A YouTube video, embedded.
///
/// ---------------------------------------------------------------------------
/// THE STILL FIRST, THE PLAYER ON PRESS
/// ---------------------------------------------------------------------------
///
/// The iframe is not created until somebody presses play. A story with three
/// videos would otherwise open three connections to Google before anybody had
/// decided to watch anything — costly on a phone connection, and a promise
/// broken to every visitor who read the privacy policy.
///
/// The video itself stays on YouTube. This archive holds the record.
class NewsVideo extends StatefulWidget {
  const NewsVideo({required this.youtubeId, this.title, super.key});

  final String youtubeId;
  final String? title;

  @override
  State<NewsVideo> createState() => _NewsVideoState();
}

class _NewsVideoState extends State<NewsVideo> {
  bool _playing = false;

  String get youtubeId => widget.youtubeId;
  String? get title => widget.title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _playing && YoutubeEmbed.isSupported
                ? YoutubeEmbed.player(youtubeId, title: title)
                : _Still(
                    youtubeId: youtubeId,
                    title: title,
                    onPlay: YoutubeEmbed.isSupported
                        ? () => setState(() => _playing = true)
                        : null,
                  ),
          ),
        ),
        if (title != null) ...<Widget>[
          const Gap.sm(),
          Row(
            children: <Widget>[
              const Icon(Icons.play_circle_outline, size: 15, color: AppColors.gold),
              const Gap.hSm(),
              Expanded(
                child: Text(
                  title!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The still, with a play button over it.
///
/// Where embedding is not supported — the test runner, a future non-web target
/// — the button is absent and the caption offers YouTube honestly, rather than
/// leaving a play triangle that does nothing.
class _Still extends StatelessWidget {
  const _Still({required this.youtubeId, required this.title, required this.onPlay});

  final String youtubeId;
  final String? title;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GestureDetector(
      onTap: onPlay,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.network(
            'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
          ),
          const ColoredBox(color: Color(0x33000000)),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: Color(0xE6000000), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
            ),
          ),
          if (onPlay == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: const Color(0xCC000000),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    'Open on YouTube to watch',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
