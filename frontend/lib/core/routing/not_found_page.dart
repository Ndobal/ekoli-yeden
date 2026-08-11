import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_spacing.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/page_shell.dart';
import '../widgets/seo_head.dart';
import 'app_routes.dart';

/// The 404 page.
///
/// A permanent archive should assume a broken link is its own fault as often as
/// the visitor's — someone may be following a link from an old WhatsApp message
/// or a printed festival programme. So this offers a search and the main
/// sections rather than a bare apology.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: location,
      seo: const SeoMetadata(
        title: 'Page not found',
        description: 'That page could not be found in the Ekoli Yeden Digital Home.',
      ),
      child: PageSection(
        reading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Page not found', style: theme.textTheme.displaySmall),
            const Gap.lg(),
            Text(
              'We could not find anything at that address. It may have been moved, or the link '
              'you followed may be out of date.',
              style: theme.textTheme.bodyLarge,
            ),
            const Gap.xxl(),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.search),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search the archive'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go to the homepage'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
