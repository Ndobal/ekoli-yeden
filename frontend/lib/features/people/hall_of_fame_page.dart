/// THE EKORI HALL OF FAME — §13 of the proposal.
///
/// ---------------------------------------------------------------------------
/// THREE STATES, NOT TWO
/// ---------------------------------------------------------------------------
///
/// A page like this normally has a list and an empty state. This one has three,
/// and the difference matters:
///
///   1. The community has not switched it on.       → explain, do not apologise
///   2. It is on, and nobody has been named yet.    → explain how naming works
///   3. It is on and there are people in it.        → show them
///
/// `people.is_hall_of_fame` and the `feature_hall_of_fame` setting have both
/// existed since early in the project, and nothing read either of them, so
/// marking somebody had no effect anywhere. The switch now does something.
///
/// It stays off until the community turns it on. Who belongs in a hall of fame
/// is a judgement for Ekori to make, and a website that arrives with the
/// feature already enabled has quietly made it first.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/content_record.dart';
import '../../repositories/discover_repository.dart';

class HallOfFamePage extends StatelessWidget {
  const HallOfFamePage({super.key});

  @override
  Widget build(BuildContext context) {
    final DiscoverRepository repository = context.read<DiscoverRepository>();

    return AppScaffold(
      currentPath: AppRoutes.hallOfFame,
      seo: const SeoMetadata(
        title: 'Ekori Hall of Fame',
        description:
            'A permanent record of people who have contributed positively to Ekori and '
            'beyond.',
        canonicalPath: AppRoutes.hallOfFame,
      ),
      child: PageSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const CmsText(
              'page.hall.title',
              fallback: 'Ekori Hall of Fame',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.15),
            ),
            const Gap.md(),
            const CmsText(
              'page.hall.intro',
              fallback:
                  'A permanent record of people who have contributed positively to Ekori and '
                  'beyond. Entry is decided by the community, not by this website.',
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const Gap.xxl(),
            AsyncContent<List<ContentRecord>?>(
              load: repository.hallOfFame,
              loadingMessage: 'Opening the Hall of Fame…',
              builder: (BuildContext context, List<ContentRecord>? people) {
                if (people == null) return const _NotYetEnabled();
                if (people.isEmpty) return const _NobodyNamedYet();
                return ResponsiveCardGrid(
                  maxColumns: 3,
                  children: people
                      .map((ContentRecord person) => _HonoureeCard(person: person))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// State 1 — the community has not switched it on.
class _NotYetEnabled extends StatelessWidget {
  const _NotYetEnabled();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.emoji_events_outlined, size: 44, color: AppColors.gold),
          const Gap.md(),
          Text(
            'The Hall of Fame is not open yet',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const Gap.sm(),
          Text(
            'Deciding who belongs in a hall of fame is a serious thing for a community to do, '
            'and it is not a decision this website should make on Ekori’s behalf. The section '
            'is built and waiting; it opens when the community says so, and the criteria are '
            'theirs to set.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const Gap.lg(),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.people),
            icon: const Icon(Icons.people_outline),
            label: const Text('People of Ekori'),
          ),
        ],
      ),
    );
  }
}

/// State 2 — on, but nobody named.
class _NobodyNamedYet extends StatelessWidget {
  const _NobodyNamedYet();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.emoji_events_outlined, size: 44, color: AppColors.gold),
          const Gap.md(),
          Text('Nobody has been named yet',
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const Gap.sm(),
          Text(
            'The Hall of Fame is open and empty. Somebody is added by being recorded in the '
            'People of Ekori section first — with their story, their contribution and a source '
            'for it — and then marked by the Preservation Team.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const Gap.lg(),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.contributePerson),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add somebody to the archive'),
          ),
        ],
      ),
    );
  }
}

class _HonoureeCard extends StatelessWidget {
  const _HonoureeCard({required this.person});

  final ContentRecord person;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = person.title ?? 'Unnamed';
    final String? portrait = person.raw['portrait_url'] as String?;

    return InkWell(
      onTap: person.slug == null ? null : () => context.go(AppRoutes.person(person.slug!)),
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Portrait(url: portrait, name: name),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((person.summary ?? '').isNotEmpty)
                        Text(
                          person.summary!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if ((person.raw['achievements'] as String? ?? '').isNotEmpty) ...<Widget>[
              const Gap.md(),
              Text(
                person.raw['achievements'] as String,
                style: theme.textTheme.bodySmall,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (url != null && url!.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
          image: DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
        ),
      );
    }

    final String initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part[0].toUpperCase())
        .join();

    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navy,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
