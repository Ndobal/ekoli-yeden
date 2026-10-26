import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_content.dart';
import '../../models/map_place.dart';
import '../../repositories/discover_repository.dart';
import '../../services/auth/auth_controller.dart';
import '../editorial/editorial_shell.dart';
import 'version_history_dialog.dart';

class MapCoordinatesPage extends StatefulWidget {
  const MapCoordinatesPage({super.key});
  @override
  State<MapCoordinatesPage> createState() => _MapCoordinatesPageState();
}

class _MapCoordinatesPageState extends State<MapCoordinatesPage> {
  int _reload = 0;
  String _search = '';
  @override
  Widget build(BuildContext context) => WorkspaceShell(
    currentPath: AppRoutes.editorialMap,
    title: 'Map locations',
    workspaceName: 'Editorial',
    accent: AppColors.skyBlue,
    navigation: editorialNavigation,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Record verified coordinates for a place. Saving updates its map position immediately; leave an unknown position unmarked. Both latitude and longitude are required together.',
        ),
        TextField(
          onChanged: (value) =>
              setState(() => _search = value.toLowerCase().trim()),
          decoration: const InputDecoration(
            labelText: 'Find a place',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        AsyncContent<MapOverview>(
          key: ValueKey(_reload),
          load: () => context.read<DiscoverRepository>().editorialMap(),
          builder: (context, overview) {
            final places = overview.items
                .where((p) => p.name.toLowerCase().contains(_search))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '${overview.placedCount} marked · ${overview.unplacedCount} unmarked',
                ),
                if (places.isEmpty) const Text('No matching places.'),
                for (final place in places)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            place.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('${place.kindLabel} · ${place.status}'),
                          SelectableText(
                            place.isPlaced
                                ? '${place.latitude}, ${place.longitude}'
                                : 'No coordinates recorded',
                          ),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              if (context.watch<AuthController>().canAny(
                                <String>[
                                  'history:update',
                                  'people:update',
                                  'content.edit',
                                  'content.manage',
                                ],
                              ))
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final saved = await showDialog<bool>(
                                      context: context,
                                      builder: (_) =>
                                          _CoordinatesDialog(place: place),
                                    );
                                    if (saved == true && mounted) {
                                      setState(() => _reload++);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.edit_location_alt_outlined,
                                  ),
                                  label: const Text('Edit position'),
                                ),
                              if (context.watch<AuthController>().canAny(
                                <String>[
                                  'versions:read',
                                  'content.read',
                                  'content.edit',
                                  'content.manage',
                                ],
                              ))
                                TextButton.icon(
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => VersionHistoryDialog(
                                      resource: 'places',
                                      recordId: place.id,
                                    ),
                                  ),
                                  icon: const Icon(Icons.history),
                                  label: const Text('History'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog({required this.place});
  final MapPlace place;
  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _latitude = TextEditingController(
      text: widget.place.latitude?.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: widget.place.longitude?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    if (!clear && !(_form.currentState?.validate() ?? false)) return;
    if (clear) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear this position?'),
          content: const Text(
            'The place stays in the archive but its pin will be removed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear position'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<DiscoverRepository>().setCoordinates(
        widget.place.id,
        latitude: clear ? null : double.parse(_latitude.text.trim()),
        longitude: clear ? null : double.parse(_longitude.text.trim()),
        previousLatitude: widget.place.latitude,
        previousLongitude: widget.place.longitude,
      );
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.place.name),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Enter decimal degrees from a verified source. Latitude: −90 to 90. Longitude: −180 to 180.',
                ),
                _field('Latitude', _latitude, 90),
                _field('Longitude', _longitude, 180),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.place.isPlaced)
          TextButton(
            onPressed: _busy ? null : () => _save(clear: true),
            child: const Text('Clear position'),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save coordinates'),
        ),
      ],
    ),
  );
  Widget _field(String label, TextEditingController controller, double limit) =>
      TextFormField(
        controller: controller,
        enabled: !_busy,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(labelText: label),
        validator: (text) {
          final n = double.tryParse(text?.trim() ?? '');
          return n == null || !n.isFinite || n < -limit || n > limit
              ? 'Enter a number from −$limit to $limit.'
              : null;
        },
      );
}
