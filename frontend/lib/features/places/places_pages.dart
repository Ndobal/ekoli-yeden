import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/place.dart';
import '../../repositories/place_repository.dart';

/// THE PLACES OF EKORI.
///
/// ---------------------------------------------------------------------------
/// THE PAGE IS A TREE BECAUSE THE PLACE IS A TREE
/// ---------------------------------------------------------------------------
///
/// Ekori is Ajere and Ntan and Epenti and Afrekpe; inside Ajere is Edang, and
/// inside Edang is Ukekeya. Somebody from Ukekeya is from all four at once.
///
/// A flat A–Z list of place names would be easier to build and would lose
/// exactly the thing worth recording — which place is inside which. So the
/// index nests, and every place page carries its lineage in its first line.
///
/// **The list grows from what people type.** No list an administrator writes
/// will ever contain every compound in Ekori. When a member says where they are
/// from, their words are recorded; a name two different people give becomes a
/// real place on its own. That is said on this page, because somebody who
/// cannot find their compound should know it will be there once a neighbour
/// agrees with them.
class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaceRepository repository = context.read<PlaceRepository>();

    return AppScaffold(
      currentPath: AppRoutes.places,
      seo: const SeoMetadata(
        title: 'The places of Ekori',
        description:
            'Ajere, Ntan, Epenti, Afrekpe — the wards, quarters and compounds of Ekori, and '
            'who is from each.',
        canonicalPath: AppRoutes.places,
      ),
      child: PageSection(
        eyebrow: 'Ekori',
        title: 'The places of Ekori',
        description:
            'Ekori is not one place. This is how it fits together — the wards, the quarters '
            'inside them, and the compounds inside those. Somebody from Ukekeya is from '
            'Ukekeya, from Edang, from Ajere and from Ekori, all at once.',
        child: AsyncContent<List<Place>>(
          load: repository.all,
          loadingMessage: 'Opening the map…',
          isEmpty: (List<Place> places) => places.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyView(
            icon: Icons.place_outlined,
            showContributeAction: false,
            title: 'No places recorded yet',
            message: 'The wards of Ekori will appear here.',
          ),
          builder: (BuildContext context, List<Place> places) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Tree(places: places),
              const Gap.xxl(),
              const _HowTheListGrows(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tree, assembled from the flat list the server sends.
///
/// Built here rather than nested by the API because the same flat list is what
/// a picker wants, and one shape that serves both is one shape to keep right.
class _Tree extends StatelessWidget {
  const _Tree({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final Map<String?, List<Place>> byParent = <String?, List<Place>>{};
    for (final Place place in places) {
      byParent.putIfAbsent(place.parentId, () => <Place>[]).add(place);
    }

    // The root is whatever has no parent — Ekori itself, ordinarily.
    final List<Place> roots = byParent[null] ?? const <Place>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: roots
          .map((Place root) => _Branch(place: root, byParent: byParent, depth: 0))
          .toList(growable: false),
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({required this.place, required this.byParent, required this.depth});

  final Place place;
  final Map<String?, List<Place>> byParent;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final List<Place> children = byParent[place.id] ?? const <Place>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PlaceRow(place: place, depth: depth, childCount: children.length),
        ...children.map(
          (Place child) => _Branch(place: child, byParent: byParent, depth: depth + 1),
        ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.depth, required this.childCount});

  final Place place;
  final int depth;
  final int childCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Indentation is capped so a deep compound is still readable on a phone.
    final double indent = (depth.clamp(0, 4)) * (context.isMobile ? 14.0 : 28.0);

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: AppSpacing.sm),
      child: Material(
        color: depth == 0 ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surface,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: () => context.go(AppRoutes.place(place.slug)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  depth == 0 ? Icons.account_balance_outlined : Icons.place_outlined,
                  size: 18,
                  color: depth == 0 ? AppColors.navy : theme.colorScheme.onSurfaceVariant,
                ),
                const Gap.hMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        place.name,
                        style: depth == 0
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.bodyLarge,
                      ),
                      const Gap.xs(),
                      Text(
                        <String>[
                          place.kindLabel,
                          if (childCount > 0)
                            childCount == 1 ? '1 inside it' : '$childCount inside it',
                          if (place.memberCount > 0)
                            place.memberCount == 1
                                ? '1 member from here'
                                : '${Formatters.number(place.memberCount)} members from here',
                        ].join('  ·  '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Said on the page, because somebody whose compound is missing needs to know
/// what to do about it — and what to do is simply to say where they are from.
class _HowTheListGrows extends StatelessWidget {
  const _HowTheListGrows();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Is your compound missing?', style: theme.textTheme.titleMedium),
          const Gap.md(),
          Text(
            'No list written by anybody will ever contain every compound in Ekori. So this one '
            'grows from what people actually say: when you fill in where you are from, your '
            'words are kept exactly as you typed them, and a name two different people give '
            'becomes a place here on its own.',
            style: theme.textTheme.bodyMedium,
          ),
          const Gap.md(),
          Text(
            'Two people, not one — one person typing something is a spelling; two people '
            'typing the same thing is a place.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.lg(),
          FilledButton.tonal(
            onPressed: () => context.go(AppRoutes.accountProfile),
            child: const Text('Say where you are from'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One place
// ---------------------------------------------------------------------------

class PlaceDetailPage extends StatelessWidget {
  const PlaceDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final PlaceRepository repository = context.read<PlaceRepository>();

    return AsyncContent<Place>(
      key: ValueKey<String>(slug),
      load: () => repository.find(slug),
      loadingMessage: 'Opening the record…',
      builder: (BuildContext context, Place place) => _PlaceView(place: place),
    );
  }
}

class _PlaceView extends StatelessWidget {
  const _PlaceView({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.places,
      seo: SeoMetadata(
        title: place.name,
        description: place.description ?? '${place.kindLabel} of Ekori.',
        canonicalPath: AppRoutes.place(place.slug),
      ),
      child: PageSection(
        reading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.places),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('All the places'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.lg(),
            SelectableText(place.name, style: theme.textTheme.headlineMedium),

            // The lineage, first, because it is the thing the tree exists to
            // record. A page about Ukekeya that does not say it is in Edang, in
            // Ajere, in Ekori has thrown that away.
            if (place.lineage != null) ...<Widget>[
              const Gap.sm(),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const Gap.hSm(),
                  Flexible(
                    child: Text(
                      'In ${place.lineage}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const Gap.lg(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                Chip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(place.kindLabel),
                ),
                if (place.memberCount > 0)
                  Chip(
                    avatar: const Icon(Icons.groups_outlined, size: 16),
                    label: Text(
                      place.memberCount == 1
                          ? '1 member from here'
                          : '${Formatters.number(place.memberCount)} members from here or inside it',
                    ),
                  ),
              ],
            ),

            if (place.description != null) ...<Widget>[
              const Gap.xxl(),
              SelectableText(place.description!, style: theme.textTheme.bodyLarge),
            ],
            if (place.history != null) ...<Widget>[
              const Gap.xl(),
              Text('Its history', style: theme.textTheme.titleMedium),
              const Gap.md(),
              SelectableText(place.history!, style: theme.textTheme.bodyMedium),
            ],
            if (place.knownFor != null) ...<Widget>[
              const Gap.xl(),
              Text('Known for', style: theme.textTheme.titleMedium),
              const Gap.md(),
              SelectableText(place.knownFor!, style: theme.textTheme.bodyMedium),
            ],

            // The archive says plainly that it holds nothing yet, rather than
            // rendering a page that looks finished and says nothing.
            if (place.description == null &&
                place.history == null &&
                place.knownFor == null) ...<Widget>[
              const Gap.xxl(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Nothing has been written about ${place.name} yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Gap.sm(),
                    Text(
                      'What it is known for, who founded it, what happened here — if you know, '
                      'the archive would rather have it from you than guess.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap.md(),
                    OutlinedButton(
                      onPressed: () => context.go(
                        AppRoutes.suggestCorrection(place.kindLabel, place.name),
                      ),
                      child: const Text('Tell us about it'),
                    ),
                  ],
                ),
              ),
            ],

            if (place.children.isNotEmpty) ...<Widget>[
              const Gap.section(),
              Text('Inside ${place.name}', style: theme.textTheme.titleMedium),
              const Gap.lg(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: place.children
                    .map(
                      (Place child) => ActionChip(
                        avatar: const Icon(Icons.place_outlined, size: 16),
                        label: Text(child.name),
                        onPressed: () => context.go(AppRoutes.place(child.slug)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],

            if (place.groups.isNotEmpty) ...<Widget>[
              const Gap.xxl(),
              Text('Groups from here', style: theme.textTheme.titleMedium),
              const Gap.lg(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: place.groups
                    .map(
                      (PlaceGroup group) => ActionChip(
                        avatar: const Icon(Icons.groups_outlined, size: 16),
                        label: Text(group.title),
                        onPressed: () => context.go(AppRoutes.group(group.slug)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
