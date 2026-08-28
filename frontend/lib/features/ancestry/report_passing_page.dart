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
import '../../models/member.dart';
import '../../repositories/kinship_repository.dart';
import '../../repositories/member_repository.dart';
import '../../repositories/remembrance_repository.dart';
import '../../services/auth/auth_controller.dart';

/// RECORDING THAT SOMEBODY HAS DIED.
///
/// ---------------------------------------------------------------------------
/// THIS PAGE EXPLAINS ITSELF BEFORE IT ASKS FOR ANYTHING, ON PURPOSE
/// ---------------------------------------------------------------------------
///
/// Recording a living person as dead is the most damaging thing anybody can do
/// on this platform, and the people most likely to do it by accident are
/// well-meaning: a mix-up between two people with the same name, a rumour from
/// a WhatsApp group, a half-heard message.
///
/// So the page says, before the first field, exactly what this does and does
/// not do: it is a claim, it changes nothing on its own, somebody who was
/// already family has to confirm it, and the person it is about is told and can
/// say it is wrong. Somebody who is not sure reads that and waits, which is the
/// outcome this design wants.
///
/// The person does NOT need an account here. Most of the community's dead never
/// used this platform, and a form that insisted on a member record would refuse
/// exactly the elders this archive most wants remembered.
class ReportPassingPage extends StatefulWidget {
  const ReportPassingPage({super.key});

  @override
  State<ReportPassingPage> createState() => _ReportPassingPageState();
}

class _ReportPassingPageState extends State<ReportPassingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _memberSearch = TextEditingController();
  final TextEditingController _place = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _relationshipText = TextEditingController();

  List<({String label, List<({String value, String label})> options})>? _relationshipGroups;
  String? _relationship;
  MemberProfile? _member;
  List<MemberProfile> _matches = const <MemberProfile>[];
  bool _searching = false;
  DateTime? _dateOfDeath;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  /// The relationship vocabulary, if it can be reached.
  ///
  /// A plain text field takes over if it cannot. This field is a claim the
  /// confirmation step re-checks against real recorded relationships, so a
  /// free-typed answer costs nothing — and blocking the whole form because a
  /// dropdown would not load would cost a great deal.
  Future<void> _loadRelationships() async {
    try {
      final List<({String label, List<({String value, String label})> options})> groups =
          await context.read<KinshipRepository>().relationshipOptions();
      if (mounted) setState(() => _relationshipGroups = groups);
    } on AppException {
      if (mounted) setState(() => _relationshipGroups = const <({String label, List<({String value, String label})> options})>[]);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _memberSearch.dispose();
    _place.dispose();
    _detail.dispose();
    _relationshipText.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    if (term.trim().length < 2) {
      setState(() => _matches = const <MemberProfile>[]);
      return;
    }

    setState(() => _searching = true);
    try {
      final result = await context.read<MemberRepository>().directory(
        query: term.trim(),
        perPage: 6,
      );
      if (mounted) setState(() => _matches = result.items);
    } on AppException {
      if (mounted) setState(() => _matches = const <MemberProfile>[]);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bool sure = await _confirm();
    if (!sure || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String message = await context.read<RemembranceRepository>().report(
        subjectName: _name.text.trim(),
        subjectUserId: _member?.userId,
        relationship: _relationship ??
            (_relationshipText.text.trim().isEmpty ? null : _relationshipText.text.trim()),
        dateOfDeath: _dateOfDeath?.toIso8601String().split('T').first,
        placeOfDeath: _place.text.trim().isEmpty ? null : _place.text.trim(),
        detail: _detail.text.trim().isEmpty ? null : _detail.text.trim(),
      );
      if (mounted) setState(() => _done = message);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The last chance to stop, with the name spelled back.
  ///
  /// A mix-up between two people with the same name is the commonest way this
  /// goes wrong, and seeing the name repeated on its own is what catches it.
  Future<bool> _confirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Before you send this'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'You are telling the archive that ${_name.text.trim()} has died.',
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const Gap.lg(),
                  const Text(
                    'Nothing happens to their account on this alone. A family member who was '
                    'already recorded as family has to confirm it, and they are told and can '
                    'say it is wrong.',
                  ),
                  const Gap.md(),
                  const Text('If you are not certain it is the right person, please wait.'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Yes, send it'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    if (!auth.isSignedIn) {
      return AppScaffold(
        currentPath: AppRoutes.ancestry,
        seo: const SeoMetadata(title: 'Record a passing', noIndex: true),
        child: PageSection(
          reading: true,
          title: 'Please sign in first',
          description:
              'A report of a death is recorded against the person making it. That is part of '
              'what keeps this safe.',
          child: FilledButton(
            onPressed: () =>
                context.go(AppRoutes.signInReturningTo(AppRoutes.reportPassing)),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    if (_done != null) {
      return AppScaffold(
        currentPath: AppRoutes.ancestry,
        seo: const SeoMetadata(title: 'Recorded', noIndex: true),
        child: PageSection(
          reading: true,
          title: 'Thank you for telling us',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_done!, style: theme.textTheme.bodyLarge),
              const Gap.lg(),
              Text(
                'Nothing has changed on their account. The family will be asked, and the '
                'Preservation Team looks at every report before a page is published.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap.xl(),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.ancestry),
                    child: const Text('The Ancestry Records'),
                  ),
                  const Gap.hLg(),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.account),
                    child: const Text('Back to your account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      currentPath: AppRoutes.ancestry,
      seo: const SeoMetadata(
        title: 'Record a passing',
        description: 'Tell the archive that somebody has died.',
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'Remembrance',
        title: 'Tell us somebody has died',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _WhatHappensNext(),
              const Gap.xxl(),

              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Their name',
                  helperText: 'As the community knew them.',
                ),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? 'Please give their name.' : null,
              ),
              const Gap.lg(),

              // --- Optional: link it to an account ------------------------
              Text('Did they have an account here?', style: theme.textTheme.titleSmall),
              const Gap.xs(),
              Text(
                'Most of the people this archive remembers never used it. Leave this empty if '
                'they did not, or if you are not sure.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap.md(),
              if (_member != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.person_outline, size: 18),
                      const Gap.hMd(),
                      Expanded(
                        child: Text(
                          '${_member!.name} · @${_member!.handle}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _member = null;
                          _memberSearch.clear();
                        }),
                        child: const Text('Not them'),
                      ),
                    ],
                  ),
                )
              else ...<Widget>[
                TextField(
                  controller: _memberSearch,
                  onChanged: _search,
                  decoration: InputDecoration(
                    labelText: 'Search members by name (optional)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_matches.isNotEmpty) ...<Widget>[
                  const Gap.sm(),
                  ..._matches.map(
                    (MemberProfile match) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: Text(match.name),
                      subtitle: Text('@${match.handle}'),
                      onTap: () => setState(() {
                        _member = match;
                        _matches = const <MemberProfile>[];
                      }),
                    ),
                  ),
                ],
              ],
              const Gap.xl(),

              // --- The reporter's relationship ----------------------------
              if (_relationshipGroups == null)
                const LinearProgressIndicator()
              else if (_relationshipGroups!.isEmpty)
                TextFormField(
                  controller: _relationshipText,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'How are you related to them?',
                    helperText: 'Their son, their neighbour, an officer of their age grade.',
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'How are you related to them?',
                    helperText: 'Recorded as your claim. Confirming a report needs more.',
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final ({String label, List<({String value, String label})> options}) group
                        in _relationshipGroups!)
                      ...group.options.map(
                        (({String value, String label}) option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text('${group.label} · ${option.label}'),
                        ),
                      ),
                  ],
                  onChanged: (String? value) => setState(() => _relationship = value),
                ),
              const Gap.lg(),

              // --- When and where -----------------------------------------
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _dateOfDeath ?? now,
                          firstDate: DateTime(now.year - 120),
                          lastDate: now,
                          helpText: 'When did they die?',
                        );
                        if (picked != null) setState(() => _dateOfDeath = picked);
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _dateOfDeath == null
                            ? 'The date, if you know it'
                            : Formatters.date(_dateOfDeath!.toIso8601String()),
                      ),
                    ),
                  ),
                  if (_dateOfDeath != null) ...<Widget>[
                    const Gap.hMd(),
                    TextButton(
                      onPressed: () => setState(() => _dateOfDeath = null),
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
              const Gap.sm(),
              Text(
                'Leave the date empty rather than guessing. An empty date is the truth; a '
                'guessed one becomes the archive’s answer.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _place,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Where, if you know (optional)'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _detail,
                minLines: 3,
                maxLines: 8,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Anything the family would want recorded (optional)',
                  alignLabelWithHint: true,
                ),
              ),

              if (_error != null) ...<Widget>[
                const Gap.lg(),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const Gap.xl(),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Send it to the family'),
                  ),
                  const Gap.hLg(),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.ancestry),
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

/// The four things standing between this form and a memorial.
///
/// Written out rather than summarised, because somebody about to make a claim
/// about another person's life should be able to see exactly what it sets in
/// motion — and because reading it is what makes an unsure person wait.
class _WhatHappensNext extends StatelessWidget {
  const _WhatHappensNext();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({String title, String body})> steps = <({String title, String body})>[
      (
        title: 'This changes nothing by itself',
        body: 'It is recorded as something you have told us, and their account is untouched.',
      ),
      (
        title: 'Somebody who was already family has to confirm it',
        body:
            'Not somebody who says they are family now — a relationship recorded and accepted '
            'before this report was made.',
      ),
      (
        title: 'They are told, and can say it is wrong',
        body:
            'If they have an account, they are notified and one press restores everything, '
            'with no deadline and no review.',
      ),
      (
        title: 'The Preservation Team decides about a page',
        body:
            'A memorial in the Ancestry Records is a separate decision, and can be undone at '
            'any point.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What happens after you send this', style: theme.textTheme.titleMedium),
          const Gap.lg(),
          for (int index = 0; index < steps.length; index += 1) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(steps[index].title, style: theme.textTheme.titleSmall),
                      const Gap.xs(),
                      Text(
                        steps[index].body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index < steps.length - 1) const Gap.lg(),
          ],
        ],
      ),
    );
  }
}
