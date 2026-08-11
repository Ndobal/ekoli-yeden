import 'package:flutter/widgets.dart';

/// Breakpoints and responsive helpers.
///
/// Mobile first, and not as a slogan: this archive will mostly be opened from a
/// WhatsApp link on a phone. The phone layout is the primary one; wider screens
/// get more columns, not a different design.
enum ScreenSize { mobile, tablet, laptop, desktop, wide }

class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 905;
  static const double laptop = 1240;
  static const double desktop = 1600;

  static ScreenSize of(double width) {
    if (width < mobile) return ScreenSize.mobile;
    if (width < tablet) return ScreenSize.tablet;
    if (width < laptop) return ScreenSize.laptop;
    if (width < desktop) return ScreenSize.desktop;
    return ScreenSize.wide;
  }
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  ScreenSize get screenSize => Breakpoints.of(screenWidth);

  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet => screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;
  bool get isLaptop => screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.laptop;
  bool get isDesktop => screenWidth >= Breakpoints.laptop;

  /// True where a horizontal navigation bar fits; below this the site uses a
  /// drawer instead.
  bool get hasRoomForNavBar => screenWidth >= Breakpoints.tablet;

  /// Picks a value per breakpoint, falling back to the next smallest supplied.
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? laptop,
    T? desktop,
    T? wide,
  }) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.laptop:
        return laptop ?? tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? laptop ?? tablet ?? mobile;
      case ScreenSize.wide:
        return wide ?? desktop ?? laptop ?? tablet ?? mobile;
    }
  }

  /// Column count for a card grid.
  int gridColumns({int max = 4}) {
    final int columns = responsive<int>(
      mobile: 1,
      tablet: 2,
      laptop: 3,
      desktop: 4,
      wide: 4,
    );
    return columns > max ? max : columns;
  }
}

/// Builds a different widget per breakpoint.
///
/// Used sparingly: most layouts adapt with `Wrap`, `Flexible` and a grid
/// column count. Reach for this only when a phone genuinely needs a different
/// structure, such as navigation.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= Breakpoints.tablet && desktop != null) return desktop!(context);
    if (width >= Breakpoints.mobile && tablet != null) return tablet!(context);
    return mobile(context);
  }
}
