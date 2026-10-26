import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_content.dart';
import '../../models/media_asset.dart';
import '../../repositories/media_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';

/// Select an existing file by its title; database IDs stay out of the form.
class MediaSelectionField extends StatefulWidget {
  const MediaSelectionField({
    required this.label,
    required this.kind,
    required this.controller,
    this.onSelected,
    super.key,
  });
  final String label;
  final String kind;
  final TextEditingController controller;
  final ValueChanged<MediaAsset?>? onSelected;

  @override
  State<MediaSelectionField> createState() => _MediaSelectionFieldState();
}

class _MediaSelectionFieldState extends State<MediaSelectionField> {
  String? _title;

  Future<void> _pick() async {
    final media = await showDialog<MediaAsset>(
      context: context,
      builder: (_) => _MediaPicker(kind: widget.kind),
    );
    if (!mounted || media == null) return;
    widget.onSelected?.call(media);
    setState(() {
      widget.controller.text = media.id;
      _title = media.displayTitle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canBrowse = context.watch<AuthController>().canAny(<String>[
      'media:read',
      'media.manage',
      'media.metadata.edit',
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          Text(
            widget.controller.text.isEmpty
                ? 'No file selected'
                : (_title ?? 'Saved file attached'),
          ),
          Wrap(
            spacing: 8,
            children: <Widget>[
              if (canBrowse)
                OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.perm_media_outlined),
                  label: const Text('Choose from media library'),
                ),
              if (widget.controller.text.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    widget.onSelected?.call(null);
                    widget.controller.clear();
                    _title = null;
                  }),
                  child: const Text('Remove attachment'),
                ),
            ],
          ),
          if (!canBrowse)
            const Text(
              'Ask a media manager to attach a file, or use a YouTube link for an interview.',
            ),
        ],
      ),
    );
  }
}

class _MediaPicker extends StatefulWidget {
  const _MediaPicker({required this.kind});
  final String kind;
  @override
  State<_MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<_MediaPicker> {
  int _page = 1;
  String _search = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Choose ${widget.kind}'),
    content: SizedBox(
      width: 520,
      height: 440,
      child: Column(
        children: <Widget>[
          TextField(
            onSubmitted: (value) => setState(() {
              _search = value.trim();
              _page = 1;
            }),
            decoration: const InputDecoration(
              labelText: 'Search files',
              suffixIcon: Icon(Icons.search),
            ),
          ),
          Expanded(
            child: AsyncContent<PaginatedResult<MediaAsset>>(
              key: ValueKey('$_page:$_search'),
              load: () => context.read<MediaRepository>().list(
                page: _page,
                perPage: 20,
                status: 'published',
                search: _search,
              ),
              builder: (context, result) {
                final files = result.items
                    .where(
                      (m) => widget.kind == 'audio' ? m.isAudio : m.isImage,
                    )
                    .toList();
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: files.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching files on this page. Upload and publish files in the Media library first.',
                              ),
                            )
                          : ListView(
                              children: files
                                  .map(
                                    (m) => ListTile(
                                      title: Text(m.displayTitle),
                                      subtitle: Text(
                                        '${m.status} · ${m.mimeType}',
                                      ),
                                      onTap: () => Navigator.of(context).pop(m),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        TextButton(
                          onPressed: _page > 1
                              ? () => setState(() => _page--)
                              : null,
                          child: const Text('Previous'),
                        ),
                        Text(
                          'Page $_page of ${result.totalPages == 0 ? 1 : result.totalPages}',
                        ),
                        TextButton(
                          onPressed: result.hasMore
                              ? () => setState(() => _page++)
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}
