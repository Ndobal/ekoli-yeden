import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/site_settings_controller.dart';
import '../../core/errors/app_exception.dart';
import '../../models/content_status.dart';
import '../../repositories/settings_repository.dart';
import '../../services/auth/auth_controller.dart';

class SettingsForm extends StatefulWidget {
  const SettingsForm({required this.groups, super.key});
  final Map<String, dynamic> groups;
  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final _form = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  final _booleans = <String, bool>{};
  final _original = <String, dynamic>{};
  bool _busy = false;
  String? _message;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    for (final rows in widget.groups.values) {
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        final key = Json.str(row, 'key');
        if (row['type'] == 'boolean') {
          _booleans[key] = row['value'] == 'true' || row['value'] == '1';
          _original[key] = _booleans[key];
        } else {
          final value = Json.str(row, 'value');
          _text[key] = TextEditingController(text: value);
          _original[key] = value;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final changes = <String, dynamic>{};
    for (final entry in _booleans.entries) {
      if (entry.value != _original[entry.key]) changes[entry.key] = entry.value;
    }
    for (final entry in _text.entries) {
      final value = entry.value.text.trim();
      if (value != _original[entry.key]) {
        changes[entry.key] = value.isEmpty ? null : value;
      }
    }
    if (changes.isEmpty) {
      setState(() {
        _message = 'No changes to save.';
        _failed = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await context.read<SettingsRepository>().update(changes);
      if (!mounted) return;
      // Apply the write response: the public GET may still be cached.
      context.read<SiteSettingsController>().applySavedValues(
        (data['values'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
      for (final entry in _text.entries) {
        _original[entry.key] = entry.value.text.trim();
      }
      _original.addAll(_booleans);
      setState(() {
        _message = 'Settings saved.';
        _failed = false;
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthController>().canAny(<String>[
      'settings:update',
      'settings.manage',
    ]);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Edit site details and feature switches. Changes take effect when saved.',
          ),
          for (final group in widget.groups.entries) ...<Widget>[
            const SizedBox(height: 24),
            Text(
              group.key.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final row
                in (group.value as List).whereType<Map<String, dynamic>>())
              _field(row, canEdit),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _message!,
                style: TextStyle(
                  color: _failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ),
          if (canEdit)
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save settings'),
            ),
        ],
      ),
    );
  }

  Widget _field(Map<String, dynamic> row, bool canEdit) {
    final key = Json.str(row, 'key');
    final label = key.replaceAll('_', ' ');
    if (row['type'] == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(Json.str(row, 'description')),
        value: _booleans[key]!,
        onChanged: !canEdit || _busy
            ? null
            : (v) => setState(() => _booleans[key] = v),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: _text[key],
        enabled: canEdit && !_busy,
        maxLines: row['type'] == 'json' ? 4 : 1,
        keyboardType: row['type'] == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: Json.strOrNull(row, 'description'),
          helperMaxLines: 3,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return null;
          if (row['type'] == 'number' &&
              (num.tryParse(text) == null || !num.parse(text).isFinite)) {
            return 'Enter a valid number.';
          }
          if (row['type'] == 'json') {
            try {
              jsonDecode(text);
            } catch (_) {
              return 'Enter valid JSON.';
            }
          }
          return null;
        },
      ),
    );
  }
}
