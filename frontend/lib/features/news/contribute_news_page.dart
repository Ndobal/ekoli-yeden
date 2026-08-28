import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/news_repository.dart';
import '../../services/auth/auth_controller.dart';

/// SENDING IN NEWS.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS NOT THE GENERAL CONTRIBUTION FORM
/// ---------------------------------------------------------------------------
///
/// A member who hears that the borehole is finished, or that a scholarship
/// deadline has moved, had nowhere to put it but the general contribution
/// page — where it arrived as an untitled description and sat in a media queue
/// behind photographs. News has a shape: a headline, what happened, when, and
/// where. Asking for that shape is what gets it published instead of filed.
///
/// **"How do you know?" is the question that matters most on this form.** News
/// from somebody who was there is a different thing from news read in a
/// WhatsApp group, and an administrator deciding whether to put something out
/// under the community's name needs to know which. It is asked plainly, and it
/// is not required — somebody who only heard a rumour should still be able to
/// pass it on, labelled as what it is.
class ContributeNewsPage extends StatefulWidget {
  const ContributeNewsPage({super.key});

  @override
  State<ContributeNewsPage> createState() => _ContributeNewsPageState();
}

class _ContributeNewsPageState extends State<ContributeNewsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _excerpt = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _sourceNote = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  List<({String value, String label})> _categories = const <({String value, String label})>[];
  List<String> _guidance = const <String>[];
  String? _category;
  DateTime? _happenedOn;
  bool _busy = false;
  String? _error;
  ({String reference, String message})? _receipt;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  /// The categories, from the server, so the form and the API cannot disagree
  /// about what a category is.
  Future<void> _loadOptions() async {
    try {
      final ({List<({String value, String label})> categories, List<String> guidance}) options =
          await context.read<NewsRepository>().formOptions();
      if (mounted) {
        setState(() {
          _categories = options.categories;
          _guidance = options.guidance;
        });
      }
    } on AppException {
      // The form works without them. A category is optional to the API, and a
      // failed options call must not stop somebody telling us something.
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title,
      _body,
      _excerpt,
      _location,
      _sourceNote,
      _name,
      _email,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ({String reference, String message}) receipt = await context
          .read<NewsRepository>()
          .submit(<String, dynamic>{
            'title': _title.text.trim(),
            'body': _body.text.trim(),
            if (_excerpt.text.trim().isNotEmpty) 'excerpt': _excerpt.text.trim(),
            if (_category != null) 'category': _category,
            if (_happenedOn != null)
              'happened_on': _happenedOn!.toIso8601String().split('T').first,
            if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
            if (_sourceNote.text.trim().isNotEmpty) 'source_note': _sourceNote.text.trim(),
            if (_name.text.trim().isNotEmpty) 'contributor_name': _name.text.trim(),
            if (_email.text.trim().isNotEmpty) 'contributor_email': _email.text.trim(),
            if (_phone.text.trim().isNotEmpty) 'contributor_phone': _phone.text.trim(),
          });

      if (mounted) setState(() => _receipt = receipt);
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

    if (_receipt != null) return _Receipt(receipt: _receipt!);

    return AppScaffold(
      currentPath: AppRoutes.news,
      seo: const SeoMetadata(
        title: 'Send in news',
        description: 'Tell the community what has happened.',
        canonicalPath: AppRoutes.contributeNews,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'News',
        title: 'Tell us what has happened',
        description:
            'Anybody may write news. An administrator reads everything that arrives and decides '
            'what is published — that is what makes this the community’s official channel '
            'rather than a noticeboard.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_guidance.isNotEmpty) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String line in _guidance) ...<Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.check, size: 16),
                            const Gap.hMd(),
                            Expanded(child: Text(line, style: theme.textTheme.bodySmall)),
                          ],
                        ),
                        if (line != _guidance.last) const Gap.md(),
                      ],
                    ],
                  ),
                ),
                const Gap.xxl(),
              ],

              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'The headline',
                  helperText: 'What happened, in one line.',
                ),
                validator: (String? value) => (value ?? '').trim().length < 4
                    ? 'Give it a headline of at least four characters.'
                    : null,
              ),
              const Gap.lg(),

              if (_categories.isNotEmpty) ...<Widget>[
                Text('What kind of news is it?', style: theme.textTheme.titleSmall),
                const Gap.md(),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _categories
                      .map(
                        (({String value, String label}) option) => ChoiceChip(
                          label: Text(option.label),
                          selected: _category == option.value,
                          onSelected: (bool selected) =>
                              setState(() => _category = selected ? option.value : null),
                        ),
                      )
                      .toList(growable: false),
                ),
                const Gap.xl(),
              ],

              TextFormField(
                controller: _body,
                minLines: 8,
                maxLines: 20,
                maxLength: 20000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What happened',
                  alignLabelWithHint: true,
                  helperText: 'Write it as you would tell somebody. It can be edited before it '
                      'is published.',
                  helperMaxLines: 2,
                ),
                validator: (String? value) => (value ?? '').trim().length < 20
                    ? 'Please write a little more — at least twenty characters.'
                    : null,
              ),
              const Gap.lg(),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _happenedOn ?? now,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 1),
                          helpText: 'When did it happen?',
                        );
                        if (picked != null) setState(() => _happenedOn = picked);
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _happenedOn == null
                            ? 'When it happened (optional)'
                            : Formatters.date(_happenedOn!.toIso8601String()),
                      ),
                    ),
                  ),
                  const Gap.hMd(),
                  Expanded(
                    child: TextFormField(
                      controller: _location,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Where (optional)'),
                    ),
                  ),
                ],
              ),
              const Gap.lg(),

              TextFormField(
                controller: _sourceNote,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'How do you know?',
                  alignLabelWithHint: true,
                  helperText: 'I was there · The chairman told me · I saw it in a WhatsApp '
                      'group. All three are useful — the last one is useful because it says so.',
                  helperMaxLines: 3,
                ),
              ),
              const Gap.xxl(),

              Text('How we can reach you', style: theme.textTheme.titleSmall),
              const Gap.xs(),
              Text(
                auth.isSignedIn
                    ? 'Left empty, we use the details on your account.'
                    : 'Optional, but an administrator often has one question before publishing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap.md(),
              TextFormField(
                controller: _name,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                  const Gap.hMd(),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...<Widget>[
                const Gap.lg(),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const Gap.xl(),
              Row(
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: const Text('Send it in'),
                  ),
                  const Gap.hLg(),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.news),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference, and what it is for.
///
/// Shown large and selectable, because it is the only way somebody without an
/// account can find out what happened to what they sent.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.receipt});

  final ({String reference, String message}) receipt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.news,
      seo: const SeoMetadata(title: 'Thank you', noIndex: true),
      child: PageSection(
        reading: true,
        eyebrow: 'News',
        title: 'Thank you',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(receipt.message, style: theme.textTheme.bodyLarge),
            const Gap.xl(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.mdAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('KEEP THIS REFERENCE', style: theme.textTheme.labelSmall),
                  const Gap.sm(),
                  SelectableText(
                    receipt.reference,
                    style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2),
                  ),
                  const Gap.md(),
                  Text(
                    'It is how you can check what happened to this, whether or not you have an '
                    'account here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Gap.xl(),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: () => context.go(AppRoutes.news),
                  child: const Text('Back to the news'),
                ),
                const Gap.hLg(),
                TextButton(
                  onPressed: () => context.go(AppRoutes.contributeNews),
                  child: const Text('Send in something else'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
