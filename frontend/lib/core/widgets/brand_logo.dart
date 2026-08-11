import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// The EKOLI YEDEN logo.
///
/// The supplied mark is a navy ring on a transparent background, which reads
/// well on light surfaces but disappears against the navy footer. On dark
/// surfaces it is therefore given a white plate to sit on — the same asset,
/// still legible, rather than a second recoloured version to keep in step.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.size = 48,
    this.onDarkBackground = false,
    this.semanticLabel = 'Ekoli Yeden',
    super.key,
  });

  final double size;
  final bool onDarkBackground;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      BrandAssets.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      // The header must still render if the asset fails to load, so the mark
      // falls back to its initials rather than a broken-image icon.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _LogoFallback(size: size, onDarkBackground: onDarkBackground),
    );

    if (!onDarkBackground) return image;

    return Container(
      padding: EdgeInsets.all(size * 0.08),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: image,
    );
  }
}

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
        borderRadius: AppRadius.smAll,
      ),
      alignment: Alignment.center,
      child: Text(
        'EY',
        style: TextStyle(
          color: onDarkBackground ? AppColors.navy : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The three words carried on the logo, rendered as a row of coloured pills.
///
/// Used on the About and Preservation Team pages. The words are the
/// community's own, taken from its logo — not something this codebase invented.
class BrandPillars extends StatelessWidget {
  const BrandPillars({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List<Widget>.generate(BrandMotto.pillars.length, (int index) {
        final Color color = BrandMotto.pillarColors[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            BrandMotto.pillars[index],
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        );
      }),
    );
  }
}
