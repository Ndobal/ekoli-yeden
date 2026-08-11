import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/cms_controller.dart';

/// Reads website text from the CMS.
///
/// Used instead of a bare `Text` wherever a visitor can read the words. The
/// Editorial Team can then change them from the editorial dashboard, and the
/// change reaches the site without anybody touching Dart.
///
/// `fallback` is what the page shows if the key has not been seeded — so a
/// fresh checkout with an empty database still renders a complete, sensible
/// website rather than a grid of blank labels.
class CmsText extends StatelessWidget {
  const CmsText(
    this.textKey, {
    required this.fallback,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.transform,
    super.key,
  });

  /// The CMS key, e.g. `home.s1.title`.
  final String textKey;

  /// Shown when the key has no value in the database.
  final String fallback;

  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Applied after the value is read, e.g. to upper-case an eyebrow label.
  /// Kept out of the stored value so an editor writes normal prose.
  final String Function(String value)? transform;

  @override
  Widget build(BuildContext context) {
    final String value = context.select<CmsController, String>(
      (CmsController cms) => cms.text(textKey, fallback: fallback),
    );

    return Text(
      transform?.call(value) ?? value,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Reads a CMS value without building a widget.
///
/// For places that need the string itself — a tooltip, a semantic label, a
/// hint, an SEO field.
extension CmsAccess on BuildContext {
  String cms(String key, {required String fallback}) =>
      read<CmsController>().text(key, fallback: fallback);

  /// Watches, so the widget rebuilds if the CMS reloads.
  String cmsWatch(String key, {required String fallback}) =>
      watch<CmsController>().text(key, fallback: fallback);
}
