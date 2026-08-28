/// DISCOVER EKORI — §16 of the proposal.
///
/// ---------------------------------------------------------------------------
/// WHY THERE IS NO BASEMAP
/// ---------------------------------------------------------------------------
///
/// The usual way to build this is a slippy map over street tiles. That would
/// mean a large new dependency in a project whose dependency list is eleven
/// packages and deliberately so, and every visitor's browser fetching tiles
/// from a third party on a page about a village.
///
/// What the proposal actually asks for is "an interactive map showing important
/// landmarks… visitors can click a location and learn its history". At the
/// scale of one community — wards, quarters, compounds and two beaches — the
/// useful information is where these sit in relation to each other, and that is
/// a drawing, not a street atlas.
///
/// So the map is painted here, from the coordinates the community records, with
/// no tiles and no network calls. If Ekori ever wants satellite imagery behind
/// it, that is a layer to add underneath rather than a rewrite.
///
/// ---------------------------------------------------------------------------
/// AND WHY MOST OF IT IS EMPTY
/// ---------------------------------------------------------------------------
///
/// None of the fourteen recorded places has coordinates yet. The archive will
/// not invent them: a pin dropped in roughly the right area looks exactly as
/// authoritative as a surveyed one, and the people best placed to notice it is
/// wrong are the people this archive is asking to trust it.
///
/// So unmarked places are listed below the map rather than hidden, and the page
/// says what is missing.
library;

import 'dart:math' as math;

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
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/map_place.dart';
import '../../repositories/discover_repository.dart';

class DiscoverMapPage extends StatelessWidget {
  const DiscoverMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DiscoverRepository repository = context.read<DiscoverRepository>();

    return AppScaffold(
      currentPath: AppRoutes.map,
      seo: const SeoMetadata(
        title: 'Discover Ekori — the map',
        description:
            'The wards, quarters, compounds and landmarks of Ekori, and where they sit in '
            'relation to one another.',
        canonicalPath: AppRoutes.map,
      ),
      child: PageSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const CmsText(
              'page.map.title',
              fallback: 'Discover Ekori',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.15),
            ),
            const Gap.md(),
            const CmsText(
              'page.map.intro',
              fallback:
                  'The wards, quarters, compounds and landmarks of Ekori, and where they sit '
                  'in relation to one another. Choose a place to read what is known about it.',
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const Gap.xxl(),
            AsyncContent<MapOverview>(
              load: repository.map,
              loadingMessage: 'Drawing the map…',
              builder: (BuildContext context, MapOverview overview) =>
                  _MapBody(overview: overview),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends StatefulWidget {
  const _MapBody({required this.overview});

  final MapOverview overview;

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  MapPlace? _selected;

  @override
  Widget build(BuildContext context) {
    final MapOverview overview = widget.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (overview.hasAnyPosition)
          _MapCanvas(
            places: overview.placed,
            bounds: overview.bounds!.padded(),
            selected: _selected,
            onSelect: (MapPlace place) => setState(() => _selected = place),
          )
        else
          const _NothingMappedYet(),

        if (_selected != null) ...<Widget>[
          const Gap.lg(),
          _SelectedPlaceCard(
            place: _selected!,
            onClose: () => setState(() => _selected = null),
          ),
        ],

        if (overview.unplaced.isNotEmpty) ...<Widget>[
          const Gap.xxl(),
          _UnplacedList(places: overview.unplaced, placedCount: overview.placedCount),
        ],
      ],
    );
  }
}

/// The map itself.
class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.places,
    required this.bounds,
    required this.selected,
    required this.onSelect,
  });

  final List<MapPlace> places;
  final MapBounds bounds;
  final MapPlace? selected;
  final ValueChanged<MapPlace> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = math.min(math.max(width * 0.68, 320), 560);
        final Size size = Size(width, height);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTapUp: (TapUpDetails details) {
              final MapPlace? hit = _hitTest(details.localPosition, size);
              if (hit != null) onSelect(hit);
            },
            child: CustomPaint(
              size: size,
              painter: _MapPainter(
                places: places,
                bounds: bounds,
                selected: selected,
                labelStyle: theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12),
                gridColour: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                textColour: theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Nearest marker within a finger's width.
  MapPlace? _hitTest(Offset point, Size size) {
    MapPlace? best;
    double bestDistance = 34;

    for (final MapPlace place in places) {
      final Offset centre = _project(place, bounds, size);
      final double distance = (centre - point).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = place;
      }
    }
    return best;
  }
}

/// Equirectangular, which is correct enough at the scale of one community and
/// has the useful property of being obvious.
///
/// Longitude is scaled by cos(latitude) so the drawing does not stretch
/// east-west; at Ekori's latitude that is a real difference of a few per cent.
Offset _project(MapPlace place, MapBounds bounds, Size size) {
  const double inset = 44;
  final double w = size.width - inset * 2;
  final double h = size.height - inset * 2;

  final double midLat = (bounds.minLat + bounds.maxLat) / 2;
  final double lngScale = math.cos(midLat * math.pi / 180).abs().clamp(0.1, 1.0);

  final double lngSpan = (bounds.maxLng - bounds.minLng) * lngScale;
  final double latSpan = bounds.maxLat - bounds.minLat;

  final double x = lngSpan == 0
      ? w / 2
      : ((place.longitude! - bounds.minLng) * lngScale / lngSpan) * w;
  // Screen y grows downwards; latitude grows northwards.
  final double y = latSpan == 0
      ? h / 2
      : (1 - (place.latitude! - bounds.minLat) / latSpan) * h;

  return Offset(inset + x, inset + y);
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.places,
    required this.bounds,
    required this.selected,
    required this.labelStyle,
    required this.gridColour,
    required this.textColour,
  });

  final List<MapPlace> places;
  final MapBounds bounds;
  final MapPlace? selected;
  final TextStyle labelStyle;
  final Color gridColour;
  final Color textColour;

  static const Map<String, Color> _kindColours = <String, Color>{
    'village': AppColors.navy,
    'ward': AppColors.green,
    'quarter': AppColors.gold,
    'compound': AppColors.navyLight,
    'beach': AppColors.skyBlueDark,
  };

  Color _colourFor(MapPlace place) => _kindColours[place.kind] ?? AppColors.inkMuted;

  @override
  void paint(Canvas canvas, Size size) {
    // A faint graticule, so the drawing reads as a map rather than a diagram.
    final Paint grid = Paint()
      ..color = gridColour
      ..strokeWidth = 1;
    const int lines = 6;
    for (int i = 1; i < lines; i++) {
      final double x = size.width * i / lines;
      final double y = size.height * i / lines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Parent → child hairlines, so a compound reads as being inside its quarter.
    final Map<String, MapPlace> byId = <String, MapPlace>{
      for (final MapPlace place in places) place.id: place,
    };
    final Paint tie = Paint()
      ..color = gridColour
      ..strokeWidth = 1.4;
    for (final MapPlace place in places) {
      final MapPlace? parent = place.parentId == null ? null : byId[place.parentId];
      if (parent == null) continue;
      canvas.drawLine(
        _project(place, bounds, size),
        _project(parent, bounds, size),
        tie,
      );
    }

    for (final MapPlace place in places) {
      final Offset centre = _project(place, bounds, size);
      final bool isSelected = selected?.id == place.id;
      final Color colour = _colourFor(place);
      final double radius = place.kind == 'village' ? 11 : 8;

      if (isSelected) {
        canvas.drawCircle(
          centre,
          radius + 7,
          Paint()..color = colour.withValues(alpha: 0.22),
        );
      }

      canvas.drawCircle(centre, radius, Paint()..color = colour);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      final TextPainter label = TextPainter(
        text: TextSpan(
          text: place.name,
          style: labelStyle.copyWith(
            color: textColour,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 130);

      // Keep the label on the canvas when a pin sits near an edge.
      double labelX = centre.dx - label.width / 2;
      labelX = labelX.clamp(2, math.max(2, size.width - label.width - 2));
      label.paint(canvas, Offset(labelX, centre.dy + radius + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.selected?.id != selected?.id ||
      old.places.length != places.length ||
      old.textColour != textColour;
}

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({required this.place, required this.onClose});

  final MapPlace place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(place.kindLabel.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
                    Text(place.name, style: theme.textTheme.headlineSmall),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          if ((place.description ?? '').isNotEmpty) ...<Widget>[
            const Gap.sm(),
            Text(place.description!, style: theme.textTheme.bodyMedium),
          ],
          if ((place.knownFor ?? '').isNotEmpty) ...<Widget>[
            const Gap.sm(),
            Text('Known for: ${place.knownFor}', style: theme.textTheme.bodySmall),
          ],
          const Gap.md(),
          FilledButton.tonalIcon(
            onPressed: () => context.go(AppRoutes.place(place.slug)),
            icon: const Icon(Icons.arrow_forward),
            label: Text('Read about ${place.name}'),
          ),
        ],
      ),
    );
  }
}

class _NothingMappedYet extends StatelessWidget {
  const _NothingMappedYet();

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
          Icon(Icons.explore_outlined, size: 44, color: theme.colorScheme.onSurfaceVariant),
          const Gap.md(),
          Text('The map is waiting on the community',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const Gap.sm(),
          const CmsText(
            'page.map.empty',
            fallback:
                'No positions have been recorded yet. The map will fill in as the community '
                'marks where each ward, quarter and landmark stands — and until somebody who '
                'knows records it, this archive will not guess.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _UnplacedList extends StatelessWidget {
  const _UnplacedList({required this.places, required this.placedCount});

  final List<MapPlace> places;
  final int placedCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          placedCount == 0 ? 'The places of Ekori' : 'Still to be marked',
          style: theme.textTheme.titleLarge,
        ),
        const Gap.sm(),
        Text(
          placedCount == 0
              ? 'Every place the archive knows about. None has a recorded position yet — '
                  'anybody who knows where these stand can help put them on the map.'
              : '${places.length} of the places the archive knows about have no recorded '
                  'position yet.',
          style: theme.textTheme.bodyMedium,
        ),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final MapPlace place in places)
              ActionChip(
                avatar: const Icon(Icons.place_outlined, size: 17),
                label: Text('${place.name} · ${place.kindLabel}'),
                onPressed: () => context.go(AppRoutes.place(place.slug)),
              ),
          ],
        ),
      ],
    );
  }
}
