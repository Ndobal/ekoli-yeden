import 'package:flutter/widgets.dart';

/// Spacing scale.
///
/// One 4px-based scale for the whole application. Screens use these names
/// rather than raw numbers so that spacing stays consistent as new sections
/// are added by different contributors.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;
  static const double section = 96;

  /// Horizontal page padding, which tightens on a phone.
  static EdgeInsets pagePadding(double width) {
    if (width < 600) return const EdgeInsets.symmetric(horizontal: lg);
    if (width < 1024) return const EdgeInsets.symmetric(horizontal: xxl);
    return const EdgeInsets.symmetric(horizontal: xxxl);
  }

  /// Vertical rhythm between major sections of a page.
  static double sectionGap(double width) => width < 600 ? xxl : section;

  /// The widest a column of body text is allowed to become.
  ///
  /// A history entry read across a 27-inch monitor at full width is unreadable;
  /// this keeps the measure at a comfortable line length.
  static const double maxContentWidth = 1200;
  static const double maxReadingWidth = 720;
}

/// Named gaps, so layout code reads as prose.
class Gap extends StatelessWidget {
  const Gap.xs({super.key}) : _size = AppSpacing.xs, _horizontal = false;
  const Gap.sm({super.key}) : _size = AppSpacing.sm, _horizontal = false;
  const Gap.md({super.key}) : _size = AppSpacing.md, _horizontal = false;
  const Gap.lg({super.key}) : _size = AppSpacing.lg, _horizontal = false;
  const Gap.xl({super.key}) : _size = AppSpacing.xl, _horizontal = false;
  const Gap.xxl({super.key}) : _size = AppSpacing.xxl, _horizontal = false;
  const Gap.xxxl({super.key}) : _size = AppSpacing.xxxl, _horizontal = false;

  const Gap.hSm({super.key}) : _size = AppSpacing.sm, _horizontal = true;
  const Gap.hMd({super.key}) : _size = AppSpacing.md, _horizontal = true;
  const Gap.hLg({super.key}) : _size = AppSpacing.lg, _horizontal = true;
  const Gap.hXl({super.key}) : _size = AppSpacing.xl, _horizontal = true;

  final double _size;
  final bool _horizontal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _horizontal ? _size : null,
      height: _horizontal ? null : _size,
    );
  }
}
