import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/responsive.dart';

/// Constrains page content to a readable width and applies page padding.
///
/// Every public page uses this so that a history entry read on a 27-inch
/// monitor keeps a comfortable line length instead of stretching edge to edge.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.padded = true,
    super.key,
  });

  /// Narrower measure, for long-form prose.
  const ContentContainer.reading({required this.child, this.padded = true, super.key})
    : maxWidth = AppSpacing.maxReadingWidth;

  final Widget child;
  final double maxWidth;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final double width = context.screenWidth;
    return Center(
      child: Padding(
        padding: padded ? AppSpacing.pagePadding(width) : EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// A titled band of a page, with consistent vertical rhythm.
class PageSection extends StatelessWidget {
  const PageSection({
    required this.child,
    this.title,
    this.eyebrow,
    this.description,
    this.action,
    this.background,
    this.reading = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? eyebrow;
  final String? description;
  final Widget? action;
  final Color? background;

  /// Constrains to the narrower reading measure.
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = AppSpacing.sectionGap(context.screenWidth);

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow != null) ...<Widget>[
          Text(eyebrow!.toUpperCase(), style: theme.textTheme.labelSmall),
          const Gap.sm(),
        ],
        if (title != null) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title!,
                  style: context.isMobile
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.headlineLarge,
                ),
              ),
              if (action != null) ...<Widget>[const Gap.hLg(), action!],
            ],
          ),
          const Gap.md(),
        ],
        if (description != null) ...<Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
            child: Text(
              description!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Gap.xl(),
        ],
        child,
      ],
    );

    return Container(
      width: double.infinity,
      color: background,
      padding: EdgeInsets.symmetric(vertical: gap / 2),
      child: reading
          ? ContentContainer.reading(child: body)
          : ContentContainer(child: body),
    );
  }
}
