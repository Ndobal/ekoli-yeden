import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Page metadata for search engines and social sharing.
///
/// Why this matters here more than in most applications: the whole point of the
/// archive is that when somebody searches for Ekoli-Yeden, they find a careful
/// record rather than scattered social media posts. Every page therefore
/// declares its own title, description, canonical URL and share image.
@immutable
class SeoMetadata {
  const SeoMetadata({
    required this.title,
    this.description,
    this.imageUrl,
    this.canonicalPath,
    this.type = 'website',
    this.publishedAt,
    this.noIndex = false,
  });

  final String title;
  final String? description;

  /// Absolute URL of the Open Graph image — what appears when the page is
  /// shared into a WhatsApp group, which is how most of this will spread.
  final String? imageUrl;

  /// Path this page should be canonically indexed at.
  final String? canonicalPath;

  /// `website` or `article`.
  final String type;
  final String? publishedAt;

  /// Keeps a page out of search results.
  ///
  /// For the screens that belong to one person rather than to the archive — an
  /// age grade's own workspace, "the grades I administer". They are behind a
  /// permission on the server either way; this is so they do not turn up in a
  /// search result that then asks the reader to sign in.
  final bool noIndex;

  String get fullTitle =>
      title == AppConfig.appName ? title : '$title — ${AppConfig.appName}';

  String? get canonicalUrl =>
      canonicalPath == null ? null : '${AppConfig.siteUrl}$canonicalPath';

  /// The tag set a server-side renderer or prerenderer would emit.
  ///
  /// Flutter Web renders into a canvas and cannot itself rewrite `<head>`, so
  /// this is the description of what the page *means* — consumed by the
  /// prerendering step documented in docs/architecture.md, and available to any
  /// future SSR layer without the page components changing.
  Map<String, String> toMetaTags() {
    return <String, String>{
      'title': fullTitle,
      'description': ?description,
      'canonical': ?canonicalUrl,
      'og:title': fullTitle,
      'og:description': ?description,
      'og:image': ?imageUrl,
      'og:url': ?canonicalUrl,
      'og:type': type,
      'og:site_name': AppConfig.appName,
      'twitter:card': imageUrl == null ? 'summary' : 'summary_large_image',
      'twitter:title': fullTitle,
      'twitter:description': ?description,
      'twitter:image': ?imageUrl,
      'article:published_time': ?publishedAt,
      if (noIndex) 'robots': 'noindex, nofollow',
    };
  }
}

/// Applies a page's metadata.
///
/// It sets the browser tab title through `Title`, which Flutter routes to the
/// document, and exposes the same metadata to assistive technology as the
/// page's semantic label. Richer `<head>` control belongs to the prerender
/// step; this keeps the page components declaring their intent regardless.
class SeoHead extends StatelessWidget {
  const SeoHead({required this.child, this.metadata, super.key});

  final Widget child;
  final SeoMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    final SeoMetadata meta = metadata ??
        const SeoMetadata(
          title: AppConfig.appName,
          description: AppConfig.tagline,
          canonicalPath: '/',
        );

    return Title(
      title: meta.fullTitle,
      color: Theme.of(context).colorScheme.primary,
      child: Semantics(
        label: meta.description ?? meta.title,
        container: true,
        child: child,
      ),
    );
  }
}
