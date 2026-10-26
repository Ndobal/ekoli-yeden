import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/widgets/async_content.dart';
import '../../models/content_status.dart';
import '../../repositories/cms_repository.dart';
import '../../services/auth/auth_controller.dart';

class SourcesManager extends StatefulWidget {
  const SourcesManager({super.key});
  @override
  State<SourcesManager> createState() => _SourcesManagerState();
}

class _SourcesManagerState extends State<SourcesManager> {
  String _query = '';
  int _reload = 0;
  int _page = 1;
  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthController>().canAny(<String>[
      'sources:create',
      'sources.manage',
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Record where information came from. Attach a source using “Sources” beside an archive record.',
        ),
        if (canCreate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FilledButton.icon(
              onPressed: () async {
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (_) => const CreateSourceDialog(),
                );
                if (saved == true && mounted) {
                  setState(() {
                    _reload++;
                    _page = 1;
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add source'),
            ),
          ),
        TextField(
          onSubmitted: (value) => setState(() {
            _query = value.trim();
            _page = 1;
          }),
          decoration: const InputDecoration(
            labelText: 'Search sources',
            suffixIcon: Icon(Icons.search),
          ),
        ),
        AsyncContent<Map<String, dynamic>>(
          key: ValueKey('$_query:$_reload:$_page'),
          load: () => context.read<CmsRepository>().sources(
            search: _query,
            page: _page,
          ),
          builder: (context, data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (Json.objectList(data, 'sources').isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sources found.'),
                ),
              for (final source in Json.objectList(data, 'sources'))
                Card(
                  child: ListTile(
                    title: Text(Json.str(source, 'title')),
                    subtitle: Text(
                      <String>[
                        Json.str(source, 'author'),
                        Json.str(source, 'source_type'),
                        Json.str(source, 'reliability'),
                        Json.str(source, 'url'),
                        Json.str(source, 'notes'),
                      ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                  ),
                ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: _page > 1 ? () => setState(() => _page--) : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page $_page'),
                  TextButton(
                    onPressed: _page * 30 < Json.intVal(data, 'total')
                        ? () => setState(() => _page++)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CreateSourceDialog extends StatefulWidget {
  const CreateSourceDialog({super.key});
  @override
  State<CreateSourceDialog> createState() => _CreateSourceDialogState();
}

class _CreateSourceDialogState extends State<CreateSourceDialog> {
  final _form = GlobalKey<FormState>();
  static const _labels = <String, String>{
    'title': 'Title',
    'author': 'Author or interviewee',
    'url': 'Web address',
    'publication': 'Publication',
    'publisher': 'Publisher',
    'publication_date': 'Publication date',
    'accessed_date': 'Date accessed',
    'citation_text': 'Full citation',
    'notes': 'Notes',
  };
  final _controllers = <String, TextEditingController>{
    for (final key in _labels.keys) key: TextEditingController(),
  };
  String _type = 'web';
  String _reliability = 'unassessed';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<CmsRepository>().createSource(<String, dynamic>{
        for (final e in _controllers.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        'source_type': _type,
        'reliability': _reliability,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a source'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: AbsorbPointer(
          absorbing: _busy,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final entry in _labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _controllers[entry.key],
                      maxLines:
                          entry.key == 'notes' || entry.key == 'citation_text'
                          ? 3
                          : 1,
                      decoration: InputDecoration(labelText: entry.value),
                      validator: (v) {
                        if (entry.key == 'title' && (v?.trim().isEmpty ?? true)) {
                          return 'Enter a title.';
                        }
                        if (entry.key == 'url' &&
                            (v?.trim().isNotEmpty ?? false)) {
                          final uri = Uri.tryParse(v!.trim());
                          if (uri == null ||
                              !<String>['http', 'https'].contains(uri.scheme) ||
                              uri.host.isEmpty) {
                            return 'Enter an http or https address.';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Source type'),
                  items:
                      <String>[
                            'web',
                            'book',
                            'journal',
                            'oral_interview',
                            'archival_document',
                            'photograph',
                            'government_record',
                            'other',
                          ]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.replaceAll('_', ' ')),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _reliability,
                  decoration: const InputDecoration(labelText: 'Reliability'),
                  items:
                      <String>[
                            'unassessed',
                            'primary',
                            'secondary',
                            'tertiary',
                            'contested',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _reliability = v!),
                ),
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save source'),
      ),
    ],
  );
}

/// The record supplies its type and ID; an editor never needs to copy IDs.
class RecordSourcesDialog extends StatefulWidget {
  const RecordSourcesDialog({
    required this.resource,
    required this.recordId,
    super.key,
  });
  final String resource;
  final String recordId;
  @override
  State<RecordSourcesDialog> createState() => _RecordSourcesDialogState();
}

class _RecordSourcesDialogState extends State<RecordSourcesDialog> {
  final _supports = TextEditingController();
  final _pageReference = TextEditingController();
  String? _source;
  String _query = '';
  int _reload = 0;
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _supports.dispose();
    _pageReference.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    if (_source == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<CmsRepository>().attachSource(<String, dynamic>{
        'source_id': _source,
        'resource_type': widget.resource,
        'resource_id': widget.recordId,
        'supports': _supports.text.trim(),
        'page_reference': _pageReference.text.trim(),
      });
      if (mounted) {
        setState(() {
          _message = 'Source attached.';
          _reload++;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAttach = context.watch<AuthController>().canAny(<String>[
      'sources:update',
      'sources.manage',
    ]);
    return AlertDialog(
      title: const Text('Sources for this record'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AsyncContent<List<CitedSource>>(
                key: ValueKey(_reload),
                load: () => context.read<CmsRepository>().sourcesFor(
                  widget.resource,
                  widget.recordId,
                ),
                builder: (context, sources) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (sources.isEmpty) const Text('No sources attached yet.'),
                    for (final source in sources)
                      ListTile(
                        title: Text(source.display),
                        subtitle: Text(
                          source.supports ?? source.reliabilityLabel,
                        ),
                      ),
                  ],
                ),
              ),
              if (canAttach)
                AbsorbPointer(
                  absorbing: _busy,
                  child: Column(
                    children: <Widget>[
                      TextField(
                        onSubmitted: (v) => setState(() {
                          _query = v.trim();
                          _source = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Search the source library',
                        ),
                      ),
                      AsyncContent<Map<String, dynamic>>(
                        key: ValueKey(_query),
                        load: () => context.read<CmsRepository>().sources(
                          search: _query,
                        ),
                        builder: (context, data) =>
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _source,
                              decoration: const InputDecoration(
                                labelText: 'Source',
                              ),
                              items: Json.objectList(data, 'sources')
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: Json.str(s, 'id'),
                                      child: Text(
                                        Json.str(s, 'title'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _source = v),
                            ),
                      ),
                      const Text(
                        'Search by title to find sources outside the first 30 results.',
                      ),
                      TextField(
                        controller: _supports,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'What does this source support?',
                        ),
                      ),
                      TextField(
                        controller: _pageReference,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Page reference (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              if (_message != null) Text(_message!),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (canAttach)
          FilledButton(
            onPressed: _busy || _source == null ? null : _attach,
            child: Text(_busy ? 'Attaching…' : 'Attach source'),
          ),
      ],
    );
  }
}
