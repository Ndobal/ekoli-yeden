import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/cms_controller.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_content.dart';
import '../../models/content_status.dart';
import '../../repositories/cms_repository.dart';
import '../../services/auth/auth_controller.dart';
import '../editorial/editorial_shell.dart';
import 'media_selection_field.dart';
import 'version_history_dialog.dart';

/// Both layout editors keep proposed changes separate from the public site.
class LayoutWorkspacePage extends StatefulWidget {
  const LayoutWorkspacePage({required this.kind, super.key});
  final String kind;
  @override
  State<LayoutWorkspacePage> createState() => _LayoutWorkspacePageState();
}

class _LayoutWorkspacePageState extends State<LayoutWorkspacePage> {
  int _reload = 0;
  bool get _hero => widget.kind == 'hero';
  @override
  Widget build(BuildContext context) => WorkspaceShell(
    currentPath: _hero
        ? AppRoutes.editorialHomepage
        : AppRoutes.editorialNavigation,
    title: _hero ? 'Homepage carousel' : 'Navigation menus',
    workspaceName: 'Editorial',
    accent: AppColors.skyBlue,
    navigation: editorialNavigation,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Save a draft, submit it for review, then publish the approved change. Visitors continue to see the current version until publication.',
        ),
        if (_hero)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.editorialHomepageText),
              icon: const Icon(Icons.text_fields),
              label: const Text('Edit homepage text'),
            ),
          ),
        AsyncContent<Map<String, dynamic>>(
          key: ValueKey('${widget.kind}:$_reload'),
          load: () => _hero
              ? context.read<CmsRepository>().editorialHero()
              : context.read<CmsRepository>().editorialNavigation(),
          builder: (context, data) {
            final rows = Json.objectList(data, _hero ? 'slides' : 'items');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (rows.isEmpty)
                  const Text(
                    'No layout items found. Apply the database migrations first.',
                  ),
                for (final row in rows)
                  _LayoutCard(
                    key: ValueKey('${widget.kind}:${row['id']}:$_reload'),
                    kind: widget.kind,
                    row: row,
                    onChanged: () => setState(() => _reload++),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _LayoutCard extends StatefulWidget {
  const _LayoutCard({
    required this.kind,
    required this.row,
    required this.onChanged,
    super.key,
  });
  final String kind;
  final Map<String, dynamic> row;
  final VoidCallback onChanged;
  @override
  State<_LayoutCard> createState() => _LayoutCardState();
}

class _LayoutCardState extends State<_LayoutCard> {
  bool _busy = false;
  String? _error;
  bool get _hero => widget.kind == 'hero';
  String get _id =>
      (_hero ? widget.row['slide_number'] : widget.row['id']).toString();
  Map<String, dynamic> get _draft =>
      (widget.row['draft'] as Map<String, dynamic>?) ?? <String, dynamic>{};

  Future<void> _action(String action) async {
    if (action == 'discard') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this draft?'),
          content: const Text('The current public version will stay as it is.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep draft'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard draft'),
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
      await context.read<CmsRepository>().layoutAction(
        widget.kind,
        _id,
        action,
        Json.intVal(_draft, 'revision'),
      );
      if (!mounted) return;
      if (action == 'publish') await context.read<CmsController>().refresh();
      if (mounted) widget.onChanged();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canEdit = auth.canAny(
      _hero
          ? <String>['hero:update', 'homepage.edit', 'content.manage']
          : <String>['navigation:update', 'navigation.edit', 'content.manage'],
    );
    final canHistory = auth.canAny(<String>[
      'versions:read',
      'content.read',
      'content.edit',
      'content.manage',
    ]);
    final state = Json.strOrNull(_draft, 'state');
    final pending = _draft['values'] as Map<String, dynamic>?;
    final values = <String, dynamic>{...widget.row, ...?pending};
    final currentDetail = _hero
        ? ''
        : ' · ${widget.row['path']} · order ${widget.row['sort_order']}';
    final proposedDetail = _hero
        ? ''
        : ' · ${values['path']} · order ${values['sort_order']}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _hero
                  ? 'Slide ${widget.row['slide_number']}: ${values['title']}'
                  : '${widget.row['menu']}: ${values['label']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Current public version: ${widget.row['status'] == 'published' ? 'visible' : 'hidden'}$currentDetail',
            ),
            if (pending != null)
              Text(
                'Proposed change: ${state?.replaceAll('_', ' ')} · ${values['status'] == 'published' ? 'visible' : 'hidden'}$proposedDetail',
              ),
            if (_hero && values['description'] != null)
              Text(values['description'].toString()),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final saved = await showDialog<bool>(
                              context: context,
                              builder: (_) => _LayoutEditor(
                                kind: widget.kind,
                                id: _id,
                                row: values,
                                revision: Json.intVal(_draft, 'revision'),
                              ),
                            );
                            if (saved == true && mounted) widget.onChanged();
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      pending == null ? 'Prepare change' : 'Edit draft',
                    ),
                  ),
                if (canEdit && <String>['draft', 'rejected'].contains(state))
                  TextButton(
                    onPressed: _busy ? null : () => _action('submit'),
                    child: const Text('Submit for review'),
                  ),
                if (auth.canReview && state == 'pending_review') ...<Widget>[
                  TextButton(
                    onPressed: _busy ? null : () => _action('approve'),
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _action('reject'),
                    child: const Text('Request revision'),
                  ),
                ],
                if (auth.canPublish && state == 'approved')
                  FilledButton(
                    onPressed: _busy ? null : () => _action('publish'),
                    child: const Text('Publish change'),
                  ),
                if (canEdit && pending != null)
                  TextButton(
                    onPressed: _busy ? null : () => _action('discard'),
                    child: const Text('Discard draft'),
                  ),
                if (canHistory)
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => VersionHistoryDialog(
                        resource: _hero ? 'hero_slide' : 'navigation_item',
                        recordId: _id,
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
    );
  }
}

class _LayoutEditor extends StatefulWidget {
  const _LayoutEditor({
    required this.kind,
    required this.id,
    required this.row,
    required this.revision,
  });
  final String kind;
  final String id;
  final Map<String, dynamic> row;
  final int revision;
  @override
  State<_LayoutEditor> createState() => _LayoutEditorState();
}

class _LayoutEditorState extends State<_LayoutEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late bool _visible;
  late bool _cta;
  bool _busy = false;
  String? _error;
  String? _imageUrl;
  bool get _hero => widget.kind == 'hero';
  static const _heroFields = <String, String>{
    'eyebrow': 'Eyebrow',
    'title': 'Heading',
    'description': 'Description',
    'image_alt_text': 'Image description',
    'primary_button_label': 'Main button label',
    'primary_button_path': 'Main button destination',
    'secondary_button_label': 'Second button label',
    'secondary_button_path': 'Second button destination',
  };
  static const _navFields = <String, String>{
    'label': 'Menu label',
    'path': 'Destination',
    'description': 'Description',
    'sort_order': 'Order (0–999)',
  };
  @override
  void initState() {
    super.initState();
    for (final key in (_hero ? _heroFields : _navFields).keys) {
      _controllers[key] = TextEditingController(
        text: widget.row[key]?.toString() ?? '',
      );
    }
    if (_hero) {
      _controllers['image_media_id'] = TextEditingController(
        text: widget.row['image_media_id']?.toString() ?? '',
      );
    }
    _imageUrl = widget.row['image_url'] as String?;
    _visible = widget.row['status'] == 'published';
    _cta = Json.boolVal(widget.row, 'is_cta');
  }

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
      final values = <String, dynamic>{
        for (final e in _controllers.entries)
          e.key: e.key == 'sort_order'
              ? int.parse(e.value.text.trim())
              : e.value.text.trim(),
        'status': _visible ? 'published' : 'archived',
        'expected_revision': widget.revision,
        if (!_hero) 'is_cta': _cta,
      };
      final cms = context.read<CmsRepository>();
      if (_hero) {
        await cms.updateHeroSlide(int.parse(widget.id), values);
      } else {
        await cms.updateNavigationItem(widget.id, values);
      }
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
      title: Text(_hero ? 'Prepare slide change' : 'Prepare menu change'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _busy,
            child: Form(
              key: _form,
              onChanged: () => setState(() {}),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_hero)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('Slide preview'),
                            if (_imageUrl != null)
                              Image.network(
                                _imageUrl!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Text('Image preview unavailable'),
                              ),
                            Text(
                              _controllers['title']!.text,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(_controllers['description']!.text),
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                for (final prefix in <String>[
                                  'primary',
                                  'secondary',
                                ])
                                  if (_controllers['${prefix}_button_label']!
                                      .text
                                      .isNotEmpty)
                                    Chip(
                                      label: Text(
                                        _controllers['${prefix}_button_label']!
                                            .text,
                                      ),
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final e in (_hero ? _heroFields : _navFields).entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextFormField(
                        controller: _controllers[e.key],
                        maxLines: e.key == 'description' ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: e.value,
                          helperText: e.key.endsWith('_path') || e.key == 'path'
                              ? 'A site path, for example /history'
                              : null,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (<String>[
                                'title',
                                'label',
                                'path',
                                'sort_order',
                              ].contains(e.key) &&
                              text.isEmpty) {
                            return 'This field is required.';
                          }
                          if (e.key == 'sort_order') {
                            final n = int.tryParse(text);
                            if (n == null || n < 0 || n > 999) {
                              return 'Enter a whole number from 0 to 999.';
                            }
                          }
                          if ((e.key.endsWith('_path') || e.key == 'path') &&
                              text.isNotEmpty &&
                              (!text.startsWith('/') ||
                                  text.startsWith('//') ||
                                  text.contains(RegExp(r'[\\\s]')))) {
                            return 'Use a site path beginning with /.';
                          }
                          return null;
                        },
                      ),
                    ),
                  if (_hero)
                    MediaSelectionField(
                      label: 'Slide image',
                      onSelected: (media) =>
                          setState(() => _imageUrl = media?.url),
                      kind: 'image',
                      controller: _controllers['image_media_id']!,
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible after publication'),
                    value: _visible,
                    onChanged: (v) => setState(() => _visible = v),
                  ),
                  if (!_hero)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Emphasise as a button'),
                      value: _cta,
                      onChanged: (v) => setState(() => _cta = v),
                    ),
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
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save draft'),
        ),
      ],
    ),
  );
}
