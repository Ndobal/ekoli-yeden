import 'package:flutter/widgets.dart';

/// Corner radii.
///
/// Modest by design: a heavily rounded interface reads as playful, and this is
/// a community's historical record.
class AppRadius {
  const AppRadius._();

  static const double none = 0;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Top-only rounding, for a card whose image sits flush at the top.
  static const BorderRadius topMd = BorderRadius.only(
    topLeft: Radius.circular(md),
    topRight: Radius.circular(md),
  );
}
