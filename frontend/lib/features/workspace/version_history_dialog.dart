import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_content.dart';
import '../../models/content_status.dart';
import '../../repositories/cms_repository.dart';

class VersionHistoryDialog extends StatelessWidget {
  const VersionHistoryDialog({
    required this.resource,
    required this.recordId,
    super.key,
  });
  final String resource;
  final String recordId;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Version history'),
    content: SizedBox(
      width: 680,
      height: 480,
      child: AsyncContent<Map<String, dynamic>>(
        load: () =>
            context.read<CmsRepository>().versionsFor(resource, recordId),
        builder: (context, data) {
          final versions = Json.objectList(data, 'versions');
          if (versions.isEmpty) {
            return const Text(
              'No previous versions have been recorded yet. Changes will appear here after the next saved edit.',
            );
          }
          return ListView(
            children: <Widget>[
              const Text(
                'Each snapshot preserves the record before the listed change. Viewing it does not change the current version.',
              ),
              for (final version in versions)
                _VersionTile(
                  resource: resource,
                  recordId: recordId,
                  version: version,
                ),
            ],
          );
        },
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _VersionTile extends StatefulWidget {
  const _VersionTile({
    required this.resource,
    required this.recordId,
    required this.version,
  });
  final String resource;
  final String recordId;
  final Map<String, dynamic> version;
  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(
      'Version ${widget.version['versionNumber']} · ${Json.str(widget.version, 'changeSummary')}',
    ),
    subtitle: Text(
      '${Json.str(widget.version, 'changedByName', fallback: 'Unknown editor')} · ${Json.str(widget.version, 'createdAt')}',
    ),
    onExpansionChanged: (v) => setState(() => _expanded = v),
    children: <Widget>[
      if (_expanded)
        AsyncContent<Map<String, dynamic>>(
          load: () => context.read<CmsRepository>().version(
            widget.resource,
            widget.recordId,
            Json.intVal(widget.version, 'versionNumber'),
          ),
          builder: (context, data) {
            final snapshot =
                data['snapshot'] as Map<String, dynamic>? ??
                <String, dynamic>{};
            final changes =
                data['changedFields'] as Map<String, dynamic>? ??
                <String, dynamic>{};
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final change in changes.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText(
                        '${change.key.replaceAll('_', ' ')}\nBefore: ${_display((change.value as Map)['from'])}\nAfter: ${_display((change.value as Map)['to'])}',
                      ),
                    ),
                  const Divider(),
                  Text(
                    'Full earlier record',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final field in snapshot.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SelectableText(
                        '${field.key.replaceAll('_', ' ')}: ${_display(field.value)}',
                      ),
                    ),
                ],
              ),
            );
          },
        ),
    ],
  );
  String _display(dynamic value) => value == null
      ? 'Not set'
      : value is Map || value is List
      ? const JsonEncoder.withIndent('  ').convert(value)
      : value.toString();
}
