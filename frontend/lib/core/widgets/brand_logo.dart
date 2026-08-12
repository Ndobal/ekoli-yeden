import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// The EKOLI YEDEN logo.
///
/// The supplied artwork is a circular emblem — a navy ring around the wordmark
/// — on a transparent background. Two things follow from that:
///
///   • On a light surface it is drawn as-is.
///   • On a dark surface the navy ring disappears into the background, so the
///     mark is given a white plate to sit on. The plate is circular to match
///     the artwork, and the image is clipped to it so the square canvas's
///     corners cannot spill outside the circle.
///
/// The asset is also served in two sizes. Anything rendered small takes the
/// 128px copy rather than the 512px one, because the header logo loads on every
/// page and most visitors are on a phone connection.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.size = 48,
    this.onDarkBackground = false,
    this.semanticLabel = 'Ekoli Yeden',
    super.key,
  });

  final double size;

  /// Places the mark on a white circular plate so it stays legible.
  final bool onDarkBackground;

  final String semanticLabel;

  /// Below this the small asset is indistinguishable from the large one.
  static const double _smallAssetThreshold = 72;

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final bool useSmall = size <= _smallAssetThreshold;

    final Widget image = Image.asset(
      useSmall ? BrandAssets.logoSmall : BrandAssets.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      // Decode at the size actually drawn rather than at full resolution.
      cacheWidth: (size * devicePixelRatio).round(),
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _LogoFallback(size: size, onDarkBackground: onDarkBackground),
    );

    if (!onDarkBackground) return image;

    // The plate is slightly larger than the mark so the navy ring is not
    // touching the edge of the white, which would read as a printing error.
    final double plate = size;
    final double inset = size * 0.06;

    return Container(
      width: plate,
      height: plate,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      // Clipped so the square image cannot escape the circular plate.
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: image,
      ),
    );
  }
}

/// Shown only if the asset genuinely fails to load.
///
/// It has earned its place: the asset was absent from the bundle for a while
/// because `pubspec.yaml` did not list the branding subdirectory, and this is
/// what stood in for it. A visible, on-brand stand-in is better than a broken
/// image icon — but it should never be what a visitor actually sees.
class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.size, required this.onDarkBackground});

  final double size;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDarkBackground ? Colors.white : AppColors.navy,
        shape: BoxShape.circle,
        border: Border.all(
          color: onDarkBackground ? AppColors.navy : Colors.white,
          width: size * 0.04,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'EY',
        style: TextStyle(
          color: onDarkBackground ? AppColors.navy : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }
}

/// The three words carried on the logo, rendered as a row of coloured pills.
///
/// The words are the community's own, taken from its logo — not something this
/// codebase invented.
class BrandPillars extends StatelessWidget {
  const BrandPillars({this.onDarkBackground = false, super.key});

  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List<Widget>.generate(BrandMotto.pillars.length, (int index) {
        // On navy the palette's own greens and golds are too dark to read, so
        // dark surfaces get a single light treatment instead of three.
        final Color colour =
            onDarkBackground ? OnDark.link : BrandMotto.pillarColors[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: onDarkBackground ? 0.14 : 0.10),
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: colour.withValues(alpha: 0.4)),
          ),
          child: Text(
            BrandMotto.pillars[index],
            style: theme.textTheme.labelMedium?.copyWith(
              color: colour,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        );
      }),
    );
  }
}
