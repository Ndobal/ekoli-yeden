import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale.
///
/// Two families: a serif for display and headings, which gives the archive the
/// weight of a printed record, and a clean sans for everything a visitor
/// actually reads at length.
///
/// Both are resolved from the platform's own font stack rather than downloaded.
/// Much of this site will be opened over a mobile connection in Nigeria after
/// being shared on WhatsApp, and a web-font round trip is a real cost there. If
/// the community later chooses a typeface, this file is where it is added.
class AppTypography {
  const AppTypography._();

  static const List<String> serifStack = <String>[
    'Georgia',
    'Times New Roman',
    'Noto Serif',
    'serif',
  ];

  static const List<String> sansStack = <String>[
    'Segoe UI',
    'Helvetica Neue',
    'Noto Sans',
    'Arial',
    'sans-serif',
  ];

  static const String displayFamily = 'Georgia';
  static const String bodyFamily = 'Segoe UI';

  static TextTheme textTheme(Color primary, Color muted) {
    return TextTheme(
      // --- Display: page titles and hero headings ---------------------------
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifStack,
        fontSize: 57,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifStack,
        fontSize: 45,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifStack,
        fontSize: 36,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
      ),

      // --- Headline: section headings ---------------------------------------
      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifStack,
        fontSize: 32,
        height: 1.22,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifStack,
        fontSize: 26,
        height: 1.26,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifStack,
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),

      // --- Title: cards and list items --------------------------------------
      titleLarge: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primary,
      ),

      // --- Body -------------------------------------------------------------
      bodyLarge: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 17,
        // Generous leading: a lot of this archive is long-form history and
        // oral-history transcript, read end to end.
        height: 1.65,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 15,
        height: 1.6,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: muted,
      ),

      // --- Label: buttons, chips, captions -----------------------------------
      labelLarge: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: sansStack,
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: muted,
      ),
    );
  }

  /// The small uppercase label that sits above a section heading.
  static TextStyle eyebrow(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      letterSpacing: 1.6,
      color: AppColors.gold,
      fontWeight: FontWeight.w700,
    );
  }

  /// Used for Ekoli words in the language section, so a word is visually
  /// distinct from its English meaning.
  static TextStyle ekoliWord(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall!.copyWith(
      fontStyle: FontStyle.italic,
      color: AppColors.green,
    );
  }
}
