import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/content_record.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import 'state_views.dart';

/// A card for one archive record.
///
/// Used by history, leadership, people, news, events, businesses,
/// organizations and community projects, so a visitor learns one visual
/// pattern and it holds across the whole site.
class ContentCard extends StatefulWidget {
  const ContentCard({
    required this.record,
    required this.path,
    this.imageUrl,
    this.metaLine,
    this.showVerification = false,
    super.key,
  });

  final ContentRecord record;
  final String path;
  final String? imageUrl;

  /// A short line beneath the title — a date, a place, a title held.
  final String? metaLine;

  /// Whether to show whether the entry has been verified.
  final bool showVerification;

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: _hovered ? AppColors.navy.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.imageUrl != null)
                ArchiveImage(url: widget.imageUrl!, aspectRatio: 3 / 2, label: widget.record.displayTitle),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (widget.record.category != null) ...<Widget>[
                      Text(
                        widget.record.category!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
                      ),
                      const Gap.sm(),
                    ],
                    Text(
                      widget.record.displayTitle,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.metaLine != null) ...<Widget>[
                      const Gap.xs(),
                      Text(widget.metaLine!, style: theme.textTheme.bodySmall),
                    ],
                    if (widget.record.summary != null) ...<Widget>[
                      const Gap.sm(),
                      Text(
                        Formatters.excerpt(widget.record.summary, maxLength: 140),
                        style: theme.textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (widget.showVerification && widget.record.verificationStatus != null) ...<Widget>[
                      const Gap.md(),
                      VerificationBadge(widget.record.verificationStatus!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An image from the archive.
///
/// Shows a labelled placeholder rather than a broken-image icon while loading
/// or on failure. Many visitors will be on a slow connection, and a photograph
/// that has not arrived yet should not look like a defect.
class ArchiveImage extends StatelessWidget {
  const ArchiveImage({
    required this.url,
    required this.label,
    this.aspectRatio = 3 / 2,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;
  final String label;
  final double aspectRatio;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        url,
        fit: fit,
        // The label is what a screen reader announces, so it must describe the
        // photograph rather than repeat a filename.
        semanticLabel: label,
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
          if (progress == null) return child;
          return const _ImagePlaceholder(icon: Icons.image_outlined, label: 'Loading…');
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return const _ImagePlaceholder(
            icon: Icons.image_not_supported_outlined,
            label: 'Image unavailable',
          );
        },
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
            const Gap.xs(),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// A responsive grid of cards.
///
/// Column count comes from the breakpoint, so the same call renders one column
/// on a phone and four on a wide monitor.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    required this.children,
    this.maxColumns = 3,
    this.spacing = AppSpacing.xl,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final int columns = context.gridColumns(max: maxColumns);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double totalSpacing = spacing * (columns - 1);
        final double itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((Widget child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}
