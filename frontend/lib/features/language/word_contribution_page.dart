import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/language_entry.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/language_repository.dart';
import '../about/about_pages.dart';

/// CONTRIBUTING A WORD.
///
/// A separate form from `/contribute`, because a word is a different kind of
/// thing from a photograph. A word arrives with variants, parts of speech, more
/// than one meaning and at least one sentence showing it in use — and none of
/// that survives being squeezed into "title" and "description".
///
/// The form is shaped like the entry it will become, so what a language editor
/// reviews already reads like a dictionary entry rather than a paragraph
/// somebody has to re-type.
class WordContributionPage extends StatelessWidget {
  const WordContributionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final LanguageRepository repository = context.read<LanguageRepository>();

    return AppScaffold(
      currentPath: AppRoutes.contributeWord,
      seo: const SeoMetadata(
        title: 'Contribute a word',
        description:
            'Add a word to the Ekoli-Yeden dictionary: what it means, how it is said, and a '
            'sentence using it. Every entry is checked by a language editor before publication.',
        canonicalPath: AppRoutes.contributeWord,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'The dictionary',
            titleKey: 'page.language.contribute.title',
            titleFallback: 'Contribute a word',
            introKey: 'page.language.contribute.intro',
            introFallback:
                'If you speak the language, you can add to this dictionary. Give the word, what it '
                'means, and a sentence using it. A recording of your own voice saying it is the '
                'most valuable part — it is the thing that written words preserve worst. A '
                'language editor checks every entry before it is published.',
            accent: AppColors.green,
          ),
          PageSection(
            child: AsyncContent<WordFormOptions>(
              load: repository.contributionOptions,
              loadingMessage: 'Preparing the form…',
              builder: (BuildContext context, WordFormOptions options) =>
                  _WordForm(options: options),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordForm extends StatefulWidget {
  const _WordForm({required this.options});

  final WordFormOptions options;

  @override
  State<_WordForm> createState() => _WordFormState();
}

/// One meaning, as the form holds it while it is being typed.
class _SenseDraft {
  _SenseDraft();

  final TextEditingController meaning = TextEditingController();
  final TextEditingController definition = TextEditingController();
  String? partOfSpeech;

  void dispose() {
    meaning.dispose();
    definition.dispose();
  }

  bool get isEmpty => meaning.text.trim().isEmpty && definition.text.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'part_of_speech': partOfSpeech,
        'english_meaning': meaning.text.trim(),
        'definition': definition.text.trim(),
      };
}

/// One example sentence: the pair, plus how to say it.
class _ExampleDraft {
  _ExampleDraft();

  final TextEditingController ekoli = TextEditingController();
  final TextEditingController english = TextEditingController();
  final TextEditingController pronunciation = TextEditingController();

  void dispose() {
    ekoli.dispose();
    english.dispose();
    pronunciation.dispose();
  }

  bool get isEmpty => ekoli.text.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sentence_ekoli': ekoli.text.trim(),
        'sentence_english': english.text.trim(),
        'pronunciation': pronunciation.text.trim(),
      };
}

/// One variant form, with which quarter or family says it that way.
class _VariantDraft {
  _VariantDraft();

  final TextEditingController form = TextEditingController();
  final TextEditingController area = TextEditingController();
  String type = 'dialect';

  void dispose() {
    form.dispose();
    area.dispose();
  }

  bool get isEmpty => form.text.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'variant': form.text.trim(),
        'variant_type': type,
        'dialect_or_area': area.text.trim(),
      };
}

class _WordFormState extends State<_WordForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _word = TextEditingController();
  final TextEditingController _respelling = TextEditingController();
  final TextEditingController _tone = TextEditingController();
  final TextEditingController _literal = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _credentials = TextEditingController();

  final List<_SenseDraft> _senses = <_SenseDraft>[_SenseDraft()];
  final List<_ExampleDraft> _examples = <_ExampleDraft>[_ExampleDraft()];
  final List<_VariantDraft> _variants = <_VariantDraft>[];

  String _entryType = 'word';
  String? _categoryId;
  bool _consent = false;
  bool _submitting = false;
  String? _error;
  WordSubmissionReceipt? _receipt;

  /// The id of the recording, once it has been uploaded.
  String? _audioUploadId;
  String? _audioFilename;
  bool _uploadingAudio = false;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _word,
      _respelling,
      _tone,
      _literal,
      _notes,
      _name,
      _email,
      _phone,
      _credentials,
    ]) {
      controller.dispose();
    }
    for (final _SenseDraft sense in _senses) {
      sense.dispose();
    }
    for (final _ExampleDraft example in _examples) {
      example.dispose();
    }
    for (final _VariantDraft variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  Future<void> _pickRecording() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: <String>['mp3', 'm4a', 'aac', 'ogg', 'wav', 'webm'],
    );
    final PlatformFile? file = picked?.files.isNotEmpty ?? false ? picked!.files.first : null;
    final Uint8List? bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    setState(() {
      _uploadingAudio = true;
      _error = null;
    });

    try {
      final String id = await context.read<AccountRepository>().uploadContribution(
            bytes: bytes,
            filename: file.name,
            folder: MediaFolders.language,
            caption: 'Pronunciation of ${_word.text.trim()}',
            contributorName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            contributorEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
            usagePermission: 'public_display_with_credit',
          );
      if (mounted) {
        setState(() {
          _audioUploadId = id;
          _audioFilename = file.name;
        });
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _uploadingAudio = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final List<Map<String, dynamic>> senses = _senses
        .where((_SenseDraft sense) => !sense.isEmpty)
        .map((_SenseDraft sense) => sense.toJson())
        .toList(growable: false);

    if (senses.isEmpty) {
      setState(() {
        _error = 'Please give at least one meaning for this word, in English.';
      });
      return;
    }
    if (!_consent) {
      setState(() {
        _error = 'Please confirm that this word may be recorded in the community dictionary.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final WordSubmissionReceipt receipt =
          await context.read<LanguageRepository>().contributeWord(
                word: _word.text.trim(),
                entryType: _entryType,
                senses: senses,
                partsOfSpeech: _senses
                    .where((_SenseDraft sense) => !sense.isEmpty && sense.partOfSpeech != null)
                    .map((_SenseDraft sense) => sense.partOfSpeech!)
                    .toSet()
                    .toList(growable: false),
                examples: _examples
                    .where((_ExampleDraft example) => !example.isEmpty)
                    .map((_ExampleDraft example) => example.toJson())
                    .toList(growable: false),
                variants: _variants
                    .where((_VariantDraft variant) => !variant.isEmpty)
                    .map((_VariantDraft variant) => variant.toJson())
                    .toList(growable: false),
                phoneticRespelling: _textOrNull(_respelling),
                tonePattern: _textOrNull(_tone),
                literalTranslation: _textOrNull(_literal),
                usageNotes: _textOrNull(_notes),
                categoryId: _categoryId,
                audioUploadId: _audioUploadId,
                contributorName: _textOrNull(_name),
                contributorEmail: _textOrNull(_email),
                contributorPhone: _textOrNull(_phone),
                speakerCredentials: _textOrNull(_credentials),
              );
      if (mounted) setState(() => _receipt = receipt);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _textOrNull(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    if (_receipt != null) return _WordReceipt(receipt: _receipt!);

    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.options.guidance.isNotEmpty) ...<Widget>[
            _Guidance(points: widget.options.guidance),
            const Gap.xxl(),
          ],

          // --- The word ---------------------------------------------------
          _FormSection(
            title: 'The word',
            description: 'Write it the way you say it.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _word,
                  decoration: const InputDecoration(
                    labelText: 'The word *',
                    helperText: 'A single word, a greeting, a proverb — whatever you are adding.',
                  ),
                  validator: (String? value) =>
                      (value == null || value.trim().isEmpty) ? 'Please give the word.' : null,
                ),
                const Gap.lg(),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _entryType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'What kind of entry?'),
                        items: LanguageEntryTypes.all
                            .map(
                              (String type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(LanguageEntryTypes.label(type)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) =>
                            setState(() => _entryType = value ?? _entryType),
                      ),
                    ),
                    if (widget.options.categories.isNotEmpty)
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Group (optional)'),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(value: null, child: Text('Not sure')),
                            ...widget.options.categories.map(
                              (LanguageCategory category) => DropdownMenuItem<String?>(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            ),
                          ],
                          onChanged: (String? value) => setState(() => _categoryId = value),
                        ),
                      ),
                  ],
                ),
                const Gap.lg(),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _respelling,
                        decoration: const InputDecoration(
                          labelText: 'How is it said?',
                          helperText: 'Write the sound out, e.g. "lee-DAM".',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        controller: _tone,
                        decoration: const InputDecoration(
                          labelText: 'Tone',
                          helperText: 'High/low, if you know it.',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Meanings ---------------------------------------------------
          _FormSection(
            title: 'What it means',
            description:
                'If the word means more than one thing, add a meaning for each. That is what makes '
                'the second meaning findable rather than buried in a note.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ..._senses.asMap().entries.map(
                      (MapEntry<int, _SenseDraft> entry) => _SenseFields(
                        index: entry.key,
                        sense: entry.value,
                        partsOfSpeech: widget.options.partsOfSpeech,
                        removable: _senses.length > 1,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _senses.removeAt(entry.key).dispose()),
                      ),
                    ),
                const Gap.md(),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _senses.add(_SenseDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add another meaning'),
                ),
                const Gap.lg(),
                TextFormField(
                  controller: _literal,
                  decoration: const InputDecoration(
                    labelText: 'What does it literally say? (optional)',
                    helperText:
                        'Where the words literally say something different from what they mean. '
                        'Often the most interesting line in an entry.',
                  ),
                ),
              ],
            ),
          ),

          // --- Sentences ---------------------------------------------------
          _FormSection(
            title: 'A sentence using it',
            description:
                'Worth more than a definition: it shows how the word is really used. Give the '
                'sentence, how it is said, and what it means in English.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ..._examples.asMap().entries.map(
                      (MapEntry<int, _ExampleDraft> entry) => _ExampleFields(
                        index: entry.key,
                        example: entry.value,
                        removable: _examples.length > 1,
                        onRemove: () => setState(() => _examples.removeAt(entry.key).dispose()),
                      ),
                    ),
                const Gap.md(),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _examples.add(_ExampleDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add another sentence'),
                ),
              ],
            ),
          ),

          // --- Variants ----------------------------------------------------
          _FormSection(
            title: 'Other ways it is said',
            description:
                'If another quarter or another family says it differently, record that here. A '
                'variant written down as its own form is findable by somebody who only knows that '
                'form; a variant mentioned in a note is not.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ..._variants.asMap().entries.map(
                      (MapEntry<int, _VariantDraft> entry) => _VariantFields(
                        variant: entry.value,
                        types: widget.options.variantTypes,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _variants.removeAt(entry.key).dispose()),
                      ),
                    ),
                if (_variants.isNotEmpty) const Gap.md(),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _variants.add(_VariantDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_variants.isEmpty ? 'Add another form' : 'Add one more'),
                ),
              ],
            ),
          ),

          // --- The recording -----------------------------------------------
          _FormSection(
            title: 'Say it out loud',
            description:
                'The most valuable part of the entry. Written words preserve everything about a '
                'language except its sound — record yourself saying the word, or the sentence, and '
                'the archive keeps a voice as well as a spelling.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _uploadingAudio ? null : _pickRecording,
                  icon: _uploadingAudio
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mic_none_outlined, size: 18),
                  label: Text(_uploadingAudio ? 'Sending…' : 'Attach a recording'),
                ),
                if (_audioFilename != null) ...<Widget>[
                  const Gap.sm(),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.check, size: 14, color: AppColors.green),
                      const Gap.hSm(),
                      Expanded(
                        child: Text(
                          '${_audioFilename!} received',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.greenDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // --- About you ----------------------------------------------------
          _FormSection(
            title: 'About you',
            description:
                "A word's authority rests on who said it, so this is the part a language editor "
                'reads first. You may leave these blank, but the entry is stronger with them.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
                const Gap.lg(),
                TextFormField(
                  controller: _credentials,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'How do you know this word?',
                    alignLabelWithHint: true,
                    helperText:
                        'For example: born and raised here, my grandmother taught me this, I teach '
                        'the language.',
                  ),
                ),
                const Gap.lg(),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email address'),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) return null;
                          final bool valid =
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value.trim());
                          return valid ? null : 'That does not look like an email address.';
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone number'),
                      ),
                    ),
                  ],
                ),
                const Gap.lg(),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Anything else about this word',
                    alignLabelWithHint: true,
                    helperText:
                        'When it is used, who says it, an occasion it belongs to — anything a '
                        'dictionary entry would be poorer without.',
                  ),
                ),
              ],
            ),
          ),

          const Gap.xl(),
          CheckboxListTile(
            value: _consent,
            onChanged: (bool? value) => setState(() => _consent = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'This word may be recorded in the community dictionary, and I agree to be credited '
              'as the person who supplied it.',
              style: theme.textTheme.bodyMedium,
            ),
          ),

          if (_error != null) ...<Widget>[
            const Gap.lg(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],

          const Gap.xl(),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send this entry'),
          ),
          const Gap.md(),
          Text(
            'Nothing is published automatically. A language editor reads every entry first.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child, this.description});

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          if (description != null) ...<Widget>[
            const Gap.xs(),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Gap.lg(),
          child,
        ],
      ),
    );
  }
}

class _SenseFields extends StatelessWidget {
  const _SenseFields({
    required this.index,
    required this.sense,
    required this.partsOfSpeech,
    required this.removable,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _SenseDraft sense;
  final List<PartOfSpeech> partsOfSpeech;
  final bool removable;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Meaning ${index + 1}', style: theme.textTheme.labelLarge),
              const Spacer(),
              if (removable)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove this meaning',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const Gap.sm(),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  initialValue: sense.partOfSpeech,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Part of speech', isDense: true),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Not sure')),
                    ...partsOfSpeech.map(
                      (PartOfSpeech part) => DropdownMenuItem<String?>(
                        value: part.slug,
                        child: Text(part.label),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    sense.partOfSpeech = value;
                    onChanged();
                  },
                ),
              ),
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: sense.meaning,
                  decoration: const InputDecoration(
                    labelText: 'In English',
                    isDense: true,
                    helperText: 'The short answer: "a gathering".',
                  ),
                ),
              ),
            ],
          ),
          const Gap.md(),
          TextFormField(
            controller: sense.definition,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'A fuller explanation (optional)',
              alignLabelWithHint: true,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleFields extends StatelessWidget {
  const _ExampleFields({
    required this.index,
    required this.example,
    required this.removable,
    required this.onRemove,
  });

  final int index;
  final _ExampleDraft example;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Sentence ${index + 1}', style: theme.textTheme.labelLarge),
              const Spacer(),
              if (removable)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove this sentence',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const Gap.sm(),
          TextFormField(
            controller: example.ekoli,
            decoration: const InputDecoration(
              labelText: 'The sentence, in the language',
              isDense: true,
            ),
          ),
          const Gap.md(),
          TextFormField(
            controller: example.pronunciation,
            decoration: const InputDecoration(
              labelText: 'How the sentence is said',
              isDense: true,
              helperText: 'Written out so somebody can read it aloud.',
            ),
          ),
          const Gap.md(),
          TextFormField(
            controller: example.english,
            decoration: const InputDecoration(
              labelText: 'What it means in English',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantFields extends StatelessWidget {
  const _VariantFields({
    required this.variant,
    required this.types,
    required this.onChanged,
    required this.onRemove,
  });

  final _VariantDraft variant;
  final List<({String value, String label})> types;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 200,
            child: TextFormField(
              controller: variant.form,
              decoration: const InputDecoration(labelText: 'The other form', isDense: true),
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: variant.type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'What kind of form', isDense: true),
              items: (types.isEmpty
                      ? VariantTypes.all
                          .map(
                            (String slug) =>
                                (value: slug, label: VariantTypes.label(slug)),
                          )
                          .toList(growable: false)
                      : types)
                  .map(
                    (({String value, String label}) type) => DropdownMenuItem<String>(
                      value: type.value,
                      child: Text(type.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                variant.type = value ?? variant.type;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: TextFormField(
              controller: variant.area,
              decoration: const InputDecoration(
                labelText: 'Who says it this way',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove this form',
          ),
        ],
      ),
    );
  }
}

class _Guidance extends StatelessWidget {
  const _Guidance({required this.points});

  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Before you start', style: theme.textTheme.titleMedium),
          const Gap.md(),
          ...points.map(
            (String point) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('· '),
                  Expanded(child: Text(point, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The confirmation, with the reference code the contributor keeps.
class _WordReceipt extends StatelessWidget {
  const _WordReceipt({required this.receipt});

  final WordSubmissionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 32, color: AppColors.green),
              const Gap.md(),
              Text('Thank you', style: theme.textTheme.headlineSmall),
              const Gap.sm(),
              Text(receipt.message, style: theme.textTheme.bodyLarge),
              const Gap.xl(),
              Text('Your reference code', style: theme.textTheme.titleSmall),
              const Gap.xs(),
              SelectableText(
                receipt.referenceCode,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.greenDark,
                  letterSpacing: 2,
                ),
              ),
              const Gap.sm(),
              Text(
                'Keep this code. You can use it to ask how your entry is progressing.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Gap.xxl(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            FilledButton(
              onPressed: () => context.go(AppRoutes.contributeWord),
              child: const Text('Add another word'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.language),
              child: const Text('Back to the dictionary'),
            ),
          ],
        ),
      ],
    );
  }
}
