import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/content_record.dart';
import '../../repositories/content_repository.dart';
import '../../services/auth/auth_controller.dart';

/// Creating and editing an archive record.
///
/// One form serves every content type. Which fields appear comes from
/// `fieldsFor` below, which mirrors the writable columns the server accepts —
/// so the form can never offer a field the API will reject, and a field the
/// server accepts is one edit away from appearing here.
///
/// The workflow buttons at the bottom show only the transitions this account is
/// permitted to make. The server checks again on every one of them.
class ContentEditorDialog extends StatefulWidget {
  const ContentEditorDialog({
    required this.resource,
    required this.title,
    this.record,
    super.key,
  });

  final String resource;
  final String title;

  /// Null when creating.
  final ContentRecord? record;

  @override
  State<ContentEditorDialog> createState() => _ContentEditorDialogState();
}

/// One editable field.
class ContentField {
  const ContentField({
    required this.key,
    required this.label,
    this.helper,
    this.multiline = false,
    this.lines = 1,
    this.required = false,
    this.options,
  });

  final String key;
  final String label;
  final String? helper;
  final bool multiline;
  final int lines;
  final bool required;

  /// When present the field renders as a dropdown.
  final List<String>? options;
}

/// The fields each content type offers.
///
/// Kept deliberately close to the registry's `writableColumns` on the server.
/// Anything absent here simply is not editable from this form yet; nothing here
/// is absent from the server.
List<ContentField> fieldsFor(String resource) {
  const ContentField title = ContentField(
    key: 'title',
    label: 'Title',
    required: true,
  );
  const ContentField body = ContentField(
    key: 'body',
    label: 'Body',
    multiline: true,
    lines: 12,
    helper: 'The full account. Write what is known; leave out what is not.',
  );

  switch (resource) {
    case 'history':
      return const <ContentField>[
        title,
        ContentField(key: 'summary', label: 'Summary', multiline: true, lines: 3),
        body,
        ContentField(
          key: 'period_label',
          label: 'Period',
          helper: 'Free text — "before 1900", "the colonial period". Precision you do not have is worse than none.',
        ),
        ContentField(key: 'event_date', label: 'Date (YYYY-MM-DD)'),
        ContentField(key: 'category', label: 'Category'),
        ContentField(key: 'location', label: 'Location'),
        ContentField(
          key: 'source_reference',
          label: 'Source',
          multiline: true,
          lines: 2,
          helper: 'Where this came from. An archive that cannot say is not an archive.',
        ),
        ContentField(key: 'contributed_by', label: 'Contributed by'),
        ContentField(
          key: 'verification_status',
          label: 'Verification',
          options: <String>['unverified', 'in_review', 'verified', 'disputed'],
        ),
      ];

    case 'culture':
      return const <ContentField>[
        title,
        ContentField(key: 'subtitle', label: 'Subtitle'),
        ContentField(key: 'excerpt', label: 'Summary', multiline: true, lines: 3),
        body,
        ContentField(key: 'category', label: 'Category'),
        ContentField(
          key: 'verification_status',
          label: 'Verification',
          options: <String>['unverified', 'in_review', 'verified', 'disputed'],
        ),
      ];

    case 'leaders':
      return const <ContentField>[
        ContentField(key: 'name', label: 'Name', required: true),
        ContentField(key: 'traditional_title', label: 'Traditional title'),
        ContentField(key: 'role_description', label: 'Role'),
        ContentField(key: 'area_represented', label: 'Area represented'),
        ContentField(key: 'biography', label: 'Biography', multiline: true, lines: 8),
        ContentField(key: 'contributions', label: 'Contributions', multiline: true, lines: 4),
        ContentField(key: 'reign_start', label: 'From'),
        ContentField(key: 'reign_end', label: 'Until'),
        ContentField(key: 'source_reference', label: 'Source', multiline: true, lines: 2),
        ContentField(
          key: 'verification_status',
          label: 'Verification',
          options: <String>['unverified', 'in_review', 'verified', 'disputed'],
        ),
      ];

    case 'people':
      return const <ContentField>[
        ContentField(key: 'name', label: 'Name', required: true),
        ContentField(key: 'headline', label: 'Headline'),
        ContentField(key: 'profession', label: 'Profession'),
        ContentField(key: 'category', label: 'Category'),
        ContentField(key: 'biography', label: 'Biography', multiline: true, lines: 8),
        ContentField(key: 'achievements', label: 'Achievements', multiline: true, lines: 4),
        ContentField(key: 'city', label: 'City'),
        ContentField(key: 'country', label: 'Country'),
        ContentField(key: 'website_url', label: 'Website'),
        ContentField(
          key: 'consent_reference',
          label: 'Consent record',
          helper: 'How and when this person, or their family, agreed to be listed.',
        ),
      ];

    case 'news':
      return const <ContentField>[
        title,
        ContentField(key: 'excerpt', label: 'Summary', multiline: true, lines: 3),
        body,
        ContentField(key: 'category', label: 'Category'),
        ContentField(key: 'author_name', label: 'Author'),
        ContentField(key: 'published_at', label: 'Publication date (YYYY-MM-DD)'),
      ];

    case 'events':
      return const <ContentField>[
        title,
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 6),
        ContentField(key: 'start_datetime', label: 'Starts (YYYY-MM-DD)'),
        ContentField(key: 'end_datetime', label: 'Ends (YYYY-MM-DD)'),
        ContentField(key: 'venue', label: 'Venue'),
        ContentField(key: 'location', label: 'Location'),
        ContentField(key: 'organiser', label: 'Organiser'),
        ContentField(key: 'contact_info', label: 'Contact'),
        ContentField(key: 'category', label: 'Category'),
      ];

    case 'festivals':
      return const <ContentField>[
        ContentField(key: 'name', label: 'Festival name', required: true),
        ContentField(key: 'year', label: 'Year', required: true),
        ContentField(key: 'theme', label: 'Theme'),
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 8),
        ContentField(key: 'start_date', label: 'Start date (YYYY-MM-DD)'),
        ContentField(key: 'end_date', label: 'End date (YYYY-MM-DD)'),
        ContentField(key: 'location', label: 'Location'),
      ];

    case 'language':
      return const <ContentField>[
        ContentField(key: 'word', label: 'Ekoli word', required: true),
        ContentField(
          key: 'english_meaning',
          label: 'English meaning',
          helper: 'Leave blank unless a native speaker has confirmed it. A guess is worse than a gap.',
        ),
        ContentField(key: 'definition', label: 'Definition', multiline: true, lines: 3),
        ContentField(key: 'example_sentence', label: 'Example sentence'),
        ContentField(key: 'example_translation', label: 'Example translation'),
        ContentField(key: 'part_of_speech', label: 'Part of speech'),
        ContentField(
          key: 'dialect_or_variation',
          label: 'Dialect or variation',
          helper: 'Speech varies between families and quarters. Recording that is part of the work.',
        ),
        ContentField(key: 'speaker', label: 'Speaker'),
        ContentField(key: 'notes', label: 'Notes', multiline: true, lines: 3),
        ContentField(
          key: 'entry_type',
          label: 'Entry type',
          options: <String>[
            'word', 'phrase', 'greeting', 'proverb', 'idiom', 'number', 'name', 'song', 'riddle',
          ],
        ),
        ContentField(
          key: 'verification_status',
          label: 'Verification',
          options: <String>['unverified', 'in_review', 'verified', 'disputed'],
        ),
      ];

    case 'videos':
      return const <ContentField>[
        title,
        ContentField(
          key: 'youtube_video_id',
          label: 'YouTube link or id',
          required: true,
          helper: 'Paste whatever your browser shows — the link is turned into an id for you.',
        ),
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 5),
        ContentField(
          key: 'category',
          label: 'Category',
          options: <String>[
            'leboku', 'history', 'interviews', 'culture', 'community', 'events',
            'documentaries', 'music', 'oral_history',
          ],
        ),
        ContentField(key: 'published_date', label: 'Published (YYYY-MM-DD)'),
        ContentField(key: 'speaker', label: 'Speaker'),
        ContentField(
          key: 'transcript',
          label: 'Transcript',
          multiline: true,
          lines: 10,
          helper: 'A transcript is what makes a recording searchable. It is the most valuable thing you can add.',
        ),
      ];

    case 'galleries':
      return const <ContentField>[
        title,
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 4),
        ContentField(key: 'category', label: 'Category'),
        ContentField(key: 'event_date', label: 'Date (YYYY-MM-DD)'),
        ContentField(key: 'location', label: 'Location'),
      ];

    case 'businesses':
      return const <ContentField>[
        ContentField(key: 'name', label: 'Business name', required: true),
        ContentField(key: 'category', label: 'Category'),
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 5),
        ContentField(key: 'services', label: 'Services', multiline: true, lines: 3),
        ContentField(key: 'owner_name', label: 'Owner'),
        ContentField(key: 'phone', label: 'Phone'),
        ContentField(key: 'email', label: 'Email'),
        ContentField(key: 'website_url', label: 'Website'),
        ContentField(key: 'city', label: 'City'),
      ];

    case 'organizations':
      return const <ContentField>[
        ContentField(key: 'name', label: 'Organization name', required: true),
        ContentField(key: 'organization_type', label: 'Type'),
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 5),
        ContentField(key: 'mission', label: 'Mission', multiline: true, lines: 3),
        ContentField(key: 'founded_year', label: 'Founded'),
        ContentField(key: 'contact_name', label: 'Contact'),
        ContentField(key: 'phone', label: 'Phone'),
        ContentField(key: 'email', label: 'Email'),
      ];

    case 'community':
      return const <ContentField>[
        title,
        ContentField(key: 'description', label: 'Description', multiline: true, lines: 6),
        ContentField(key: 'purpose', label: 'Purpose', multiline: true, lines: 3),
        ContentField(key: 'location', label: 'Location'),
        ContentField(key: 'committee', label: 'Committee'),
        ContentField(key: 'progress_percent', label: 'Progress (0–100)'),
        ContentField(
          key: 'project_status',
          label: 'Project status',
          options: <String>[
            'proposed', 'fundraising', 'in_progress', 'completed', 'paused', 'cancelled',
          ],
        ),
        ContentField(key: 'start_date', label: 'Start date (YYYY-MM-DD)'),
      ];

    default:
      return <ContentField>[title, body];
  }
}

class _ContentEditorDialogState extends State<ContentEditorDialog> {
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  final Map<String, String> _dropdowns = <String, String>{};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _busy = false;
  String? _error;
  late List<ContentField> _fields;

  bool get _isNew => widget.record == null;

  @override
  void initState() {
    super.initState();
    _fields = fieldsFor(widget.resource);

    for (final ContentField field in _fields) {
      final dynamic existing = widget.record?.raw[field.key];
      final String value = existing?.toString() ?? '';
      if (field.options != null) {
        _dropdowns[field.key] = field.options!.contains(value) ? value : field.options!.first;
      } else {
        _controllers[field.key] = TextEditingController(text: value);
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collect() {
    final Map<String, dynamic> values = <String, dynamic>{};
    for (final ContentField field in _fields) {
      if (field.options != null) {
        values[field.key] = _dropdowns[field.key];
        continue;
      }
      final String text = _controllers[field.key]?.text.trim() ?? '';
      // `year`, `founded_year` and `progress_percent` are integers server-side.
      if (text.isEmpty) continue;
      if (<String>['year', 'founded_year', 'progress_percent'].contains(field.key)) {
        final int? parsed = int.tryParse(text);
        if (parsed != null) values[field.key] = parsed;
        continue;
      }
      values[field.key] = text;
    }
    return values;
  }

  Future<void> _save({String? thenSetStatus}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ContentRepository repository = context.contentRepository(widget.resource);
      final Map<String, dynamic> values = _collect();

      final ContentRecord saved = _isNew
          ? await repository.create(values)
          : await repository.update(widget.record!.id, values);

      if (thenSetStatus != null) {
        await repository.changeStatus(saved.id, thenSetStatus);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _error = <String>[
            error.message,
            ...error.fieldErrors.entries.map(
              (MapEntry<String, List<String>> e) => '${e.key}: ${e.value.join(', ')}',
            ),
          ].join('\n');
        });
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    return AlertDialog(
      title: Text(_isNew ? 'New ${widget.title.toLowerCase()}' : 'Edit ${widget.title.toLowerCase()}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!_isNew) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Text('Current status: ', style: theme.textTheme.bodySmall),
                      Text(
                        ContentStatus.label(widget.record!.status),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const Gap.md(),
                ],

                ..._fields.map(_buildField),

                if (_error != null) ...<Widget>[
                  const Gap.md(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save draft'),
        ),
        if (auth.can('content.submit') || auth.canPublish)
          OutlinedButton(
            onPressed: _busy ? null : () => _save(thenSetStatus: ContentStatus.pendingReview),
            child: const Text('Save & submit'),
          ),
        // Publishing appears only where the account holds it. The server
        // re-checks; this only avoids offering a button that would 403.
        if (auth.canPublish)
          FilledButton(
            onPressed: _busy ? null : () => _save(thenSetStatus: ContentStatus.published),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save & publish'),
          ),
      ],
    );
  }

  Widget _buildField(ContentField field) {
    if (field.options != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: DropdownButtonFormField<String>(
          initialValue: _dropdowns[field.key],
          decoration: InputDecoration(labelText: field.label, helperText: field.helper),
          items: field.options!
              .map(
                (String option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option.replaceAll('_', ' ')),
                ),
              )
              .toList(growable: false),
          onChanged: (String? value) =>
              setState(() => _dropdowns[field.key] = value ?? _dropdowns[field.key]!),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: _controllers[field.key],
        maxLines: field.multiline ? field.lines : 1,
        minLines: field.multiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          helperText: field.helper,
          helperMaxLines: 3,
          alignLabelWithHint: field.multiline,
        ),
        validator: field.required
            ? (String? value) =>
                (value == null || value.trim().isEmpty) ? '${field.label} is required.' : null
            : null,
      ),
    );
  }
}

/// The colour used for a workflow action button.
Color workflowColour(String status) => AppColors.forStatus(status);
