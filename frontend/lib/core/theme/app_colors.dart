import 'package:flutter/material.dart';

/// The digital brand palette.
///
/// These colours are taken from the supplied EKOLI YEDEN logo — the navy of
/// the ring and wordmark, the green of "YEDEN" and the unity mark, the gold of
/// the development mark, and the light blue of the skyline.
///
/// A deliberate note on what these are NOT: this is the platform's digital
/// brand palette, derived from a logo. It is not presented as a set of official
/// or traditional Ekoli-Yeden colours, and no motif in this codebase is offered
/// as an authentic Ekoli-Yeden emblem. Everything is centralised here so the
/// community can change the palette later without touching a single screen.
class AppColors {
  const AppColors._();

  // --- Brand ---------------------------------------------------------------

  /// Deep navy — primary brand, headings, navigation.
  static const Color navy = Color(0xFF0A345C);
  static const Color navyDark = Color(0xFF06233F);
  static const Color navyLight = Color(0xFF1B4E7F);

  /// Heritage green — culture, community, growth.
  static const Color green = Color(0xFF2D6A1D);
  static const Color greenDark = Color(0xFF1F4B14);
  static const Color greenLight = Color(0xFF4A8F35);

  /// Gold — highlights and important actions.
  static const Color gold = Color(0xFFB8912D);
  static const Color goldDark = Color(0xFF8C6C1E);
  static const Color goldLight = Color(0xFFD9B75C);

  /// Light blue — secondary accents.
  static const Color skyBlue = Color(0xFFA9D2F3);
  static const Color skyBlueDark = Color(0xFF7FB6E3);

  // --- Neutrals ------------------------------------------------------------

  static const Color ink = Color(0xFF10202F);
  static const Color inkSoft = Color(0xFF3A4A59);
  static const Color inkMuted = Color(0xFF64757F);

  /// Very light blue-white — the page background.
  ///
  /// Pure white is avoided: scanned photographs and aged documents look washed
  /// out on it, and this archive is largely made of scanned material.
  static const Color background = Color(0xFFF7FAFD);
  static const Color backgroundDeep = Color(0xFFEDF3F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDCE6EF);
  static const Color borderStrong = Color(0xFFBECEDD);

  // --- Dark theme ----------------------------------------------------------

  static const Color darkBackground = Color(0xFF071523);
  static const Color darkSurface = Color(0xFF0D2135);
  static const Color darkSurfaceRaised = Color(0xFF143049);
  static const Color darkBorder = Color(0xFF1E4363);
  static const Color darkText = Color(0xFFE8F1F9);
  static const Color darkTextMuted = Color(0xFF95AEC4);

  // --- Status --------------------------------------------------------------

  static const Color success = Color(0xFF2D6A1D);
  static const Color warning = Color(0xFFB8912D);
  static const Color danger = Color(0xFFB3261E);
  static const Color info = Color(0xFF0A345C);

  /// Colours for the editorial workflow badges.
  static const Map<String, Color> statusColors = <String, Color>{
    'draft': inkMuted,
    'pending_review': warning,
    'approved': navyLight,
    'published': success,
    'archived': inkMuted,
    'rejected': danger,
  };

  static Color forStatus(String status) => statusColors[status] ?? inkMuted;

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: navy,
    onPrimary: Color(0xFFF5FAFF),
    primaryContainer: Color(0xFFDCEAF7),
    onPrimaryContainer: navyDark,
    secondary: green,
    onSecondary: Color(0xFFF4FBF1),
    secondaryContainer: Color(0xFFDDEDD6),
    onSecondaryContainer: greenDark,
    tertiary: gold,
    onTertiary: Color(0xFF241A02),
    tertiaryContainer: Color(0xFFF6EBD0),
    onTertiaryContainer: goldDark,
    error: danger,
    onError: Color(0xFFFFF8F7),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: surface,
    onSurface: ink,
    surfaceContainerLowest: surface,
    surfaceContainerLow: background,
    surfaceContainer: background,
    surfaceContainerHigh: backgroundDeep,
    surfaceContainerHighest: backgroundDeep,
    onSurfaceVariant: inkSoft,
    outline: borderStrong,
    outlineVariant: border,
    shadow: Color(0x1A10202F),
    scrim: Color(0x9910202F),
    inverseSurface: navyDark,
    onInverseSurface: background,
    inversePrimary: skyBlue,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: skyBlue,
    onPrimary: Color(0xFF05203A),
    primaryContainer: Color(0xFF10395E),
    onPrimaryContainer: Color(0xFFD3E7F9),
    secondary: Color(0xFF8CC474),
    onSecondary: Color(0xFF0F2A08),
    secondaryContainer: Color(0xFF204F14),
    onSecondaryContainer: Color(0xFFD8EBD0),
    tertiary: goldLight,
    onTertiary: Color(0xFF2E2205),
    tertiaryContainer: Color(0xFF5A4712),
    onTertiaryContainer: Color(0xFFF5E7C3),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: darkSurface,
    onSurface: darkText,
    surfaceContainerLowest: darkBackground,
    surfaceContainerLow: darkSurface,
    surfaceContainer: darkSurface,
    surfaceContainerHigh: darkSurfaceRaised,
    surfaceContainerHighest: darkSurfaceRaised,
    onSurfaceVariant: darkTextMuted,
    outline: darkBorder,
    outlineVariant: Color(0xFF17334C),
    shadow: Color(0xFF000000),
    scrim: Color(0xCC000000),
    inverseSurface: background,
    onInverseSurface: ink,
    inversePrimary: navy,
  );
}

/// The three words carried on the logo.
///
/// Used as a visual motif in the header and footer. They come from the
/// community's own logo, not from anything this codebase invented.
class BrandMotto {
  const BrandMotto._();

  static const List<String> pillars = <String>['Unity', 'Progress', 'Development'];
  static const List<Color> pillarColors = <Color>[
    AppColors.green,
    AppColors.navy,
    AppColors.gold,
  ];
}

/// Paths to the supplied brand assets.
class BrandAssets {
  const BrandAssets._();

  /// The logo on a transparent background — the default everywhere.
  static const String logo = 'assets/images/branding/ekoli_yeden_logo.png';

  /// The logo on its own background, for surfaces where transparency would
  /// leave the mark sitting on an unsuitable colour.
  static const String logoWithBackground =
      'assets/images/branding/ekoli_yeden_logo_background.png';
}
