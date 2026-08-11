import 'package:flutter/material.dart';

/// Elevation.
///
/// Shadows are warm rather than neutral grey — a cool shadow over the parchment
/// background looks dirty. They stay soft: the archive should feel like paper
/// on a table, not like floating glass.
class AppShadows {
  const AppShadows._();

  static const Color _tint = Color(0xFF3A2A20);

  static List<BoxShadow> get none => const <BoxShadow>[];

  /// Resting state of a card.
  static List<BoxShadow> get low => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _tint.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Hover, and raised surfaces such as the sticky header.
  static List<BoxShadow> get medium => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.07),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: _tint.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// Dialogs, menus and the mobile navigation drawer.
  static List<BoxShadow> get high => <BoxShadow>[
    BoxShadow(
      color: _tint.withValues(alpha: 0.10),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  /// Dark theme needs a heavier shadow to separate surfaces at all.
  static List<BoxShadow> get darkLow => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> forBrightness(Brightness brightness, {bool raised = false}) {
    if (brightness == Brightness.dark) return darkLow;
    return raised ? medium : low;
  }
}
