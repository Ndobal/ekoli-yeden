import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/opportunity_repository.dart';
import '../../services/auth/auth_controller.dart';
import 'opportunities_pages.dart' show FraudWarning;

/// POSTING AN OPPORTUNITY.
///
/// Any member may put a job, scholarship or training place in front of the
/// community. It goes to review before anybody sees it — the same rule as every
/// other contribution to this archive, and more important here than anywhere
/// else, because a fraudulent listing costs somebody money rather than accuracy.
///
/// The form asks who the poster is to the opportunity. That single question
/// does more against fraud than any validation could: somebody forwarding a
/// message they received on WhatsApp will say so, and a reviewer reading "saw
/// it in a WhatsApp group" treats it very differently from "I work there".
class PostOpportunityPage extends StatefulWidget {
  const PostOpportunityPage({super.key});

  @override
  State<PostOpportunityPage> createState() => _PostOpportunityPageState();
}

class _PostOpportunityPageState extends State<PostOpportunityPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _organisation = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _requirements = TextEditingController();
  final TextEditingController _locationText = TextEditingController();
  final TextEditingController _payMin = TextEditingController();
  final TextEditingController _payMax = TextEditingController();
  final TextEditingController _applicationUrl = TextEditingController();
  final TextEditingController _applicationEmail = TextEditingController();
  final TextEditingController _applicationNote = TextEditingController();
  final TextEditingController _relationship = TextEditingController();

  String _kind = 'job';
  String _tier = 'ekoli_yeden';
  String _payPeriod = 'month';
  DateTime? _closesAt;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _title, _organisation, _summary, _description, _requirements, _locationText,
      _payMin, _payMax, _applicationUrl, _applicationEmail, _applicationNote, _relationship,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String message = await context.read<OpportunityRepository>().create(<String, dynamic>{
        'kind': _kind,
        'title': _title.text.trim(),
        'organisation': _organisation.text.trim(),
        'summary': _summary.text.trim().isEmpty ? null : _summary.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'requirements': _requirements.text.trim().isEmpty ? null : _requirements.text.trim(),
        'location_tier': _tier,
        'location_text': _locationText.text.trim().isEmpty ? null : _locationText.text.trim(),
        'pay_min': double.tryParse(_payMin.text.trim()),
        'pay_max': double.tryParse(_payMax.text.trim()),
        'pay_period': _payPeriod,
        'application_url':
            _applicationUrl.text.trim().isEmpty ? null : _applicationUrl.text.trim(),
        'application_email':
            _applicationEmail.text.trim().isEmpty ? null : _applicationEmail.text.trim(),
        'application_note':
            _applicationNote.text.trim().isEmpty ? null : _applicationNote.text.trim(),
        'closes_at': _closesAt?.toIso8601String().split('T').first,
        'poster_relationship':
            _relationship.text.trim().isEmpty ? null : _relationship.text.trim(),
      });

      if (mounted) setState(() => _done = message);
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

    return AppScaffold(
      currentPath: AppRoutes.opportunities,
      seo: const SeoMetadata(
        title: 'Post an opportunity',
        description: 'Put a job, scholarship or training place in front of Ekoli-Yeden.',
        canonicalPath: AppRoutes.postOpportunity,
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'Yakoli',
        title: 'Post an opportunity',
        description:
            'A job, scholarship, training place or grant that somebody here might be right for.',
        child: _done != null
            ? _Submitted(message: _done!)
            : !auth.isSignedIn
                ? const _MembersOnly()
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const FraudWarning(),
                        const Gap.xl(),
                        DropdownButtonFormField<String>(
                          initialValue: _kind,
                          decoration: const InputDecoration(labelText: 'What kind is it?'),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(value: 'job', child: Text('Job')),
                            DropdownMenuItem<String>(
                              value: 'scholarship',
                              child: Text('Scholarship'),
                            ),
                            DropdownMenuItem<String>(value: 'training', child: Text('Training')),
                            DropdownMenuItem<String>(
                              value: 'apprenticeship',
                              child: Text('Apprenticeship'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'internship',
                              child: Text('Internship'),
                            ),
                            DropdownMenuItem<String>(value: 'grant', child: Text('Grant')),
                            DropdownMenuItem<String>(
                              value: 'volunteer',
                              child: Text('Volunteering'),
                            ),
                          ],
                          onChanged:
                              _busy ? null : (String? v) => setState(() => _kind = v ?? _kind),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'What is it called?'),
                          validator: _required,
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _organisation,
                          decoration: const InputDecoration(
                            labelText: 'Who is offering it?',
                            helperText: 'The employer, school or organisation.',
                          ),
                          validator: _required,
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _summary,
                          decoration: const InputDecoration(
                            labelText: 'One line about it',
                            helperText: 'What a member reads on the card before opening it.',
                          ),
                        ),

                        const Gap.xxl(),
                        Text('Where', style: theme.textTheme.titleSmall),
                        const Gap.md(),
                        DropdownButtonFormField<String>(
                          initialValue: _tier,
                          decoration: const InputDecoration(labelText: 'Roughly where is it?'),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'ekoli_yeden',
                              child: Text('In Ekoli-Yeden'),
                            ),
                            DropdownMenuItem<String>(value: 'yakurr', child: Text('In Yakurr')),
                            DropdownMenuItem<String>(
                              value: 'cross_river',
                              child: Text('In Cross River'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'nigeria',
                              child: Text('Elsewhere in Nigeria'),
                            ),
                            DropdownMenuItem<String>(value: 'remote', child: Text('Remote')),
                            DropdownMenuItem<String>(
                              value: 'international',
                              child: Text('Outside Nigeria'),
                            ),
                          ],
                          onChanged:
                              _busy ? null : (String? v) => setState(() => _tier = v ?? _tier),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _locationText,
                          decoration: const InputDecoration(
                            labelText: 'The town or address (optional)',
                          ),
                        ),

                        const Gap.xxl(),
                        Text('What it pays', style: theme.textTheme.titleSmall),
                        const Gap.xs(),
                        Text(
                          'This is the question most listings dodge and the one members most need '
                          'answered. Give a range if you do not know exactly.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Gap.md(),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                controller: _payMin,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'From',
                                  prefixText: 'NGN ',
                                ),
                              ),
                            ),
                            const Gap.hMd(),
                            Expanded(
                              child: TextFormField(
                                controller: _payMax,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'To',
                                  prefixText: 'NGN ',
                                ),
                              ),
                            ),
                            const Gap.hMd(),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _payPeriod,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Per'),
                                items: const <DropdownMenuItem<String>>[
                                  DropdownMenuItem<String>(value: 'month', child: Text('month')),
                                  DropdownMenuItem<String>(value: 'year', child: Text('year')),
                                  DropdownMenuItem<String>(value: 'week', child: Text('week')),
                                  DropdownMenuItem<String>(value: 'day', child: Text('day')),
                                  DropdownMenuItem<String>(value: 'once', child: Text('in total')),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (String? v) => setState(() => _payPeriod = v ?? _payPeriod),
                              ),
                            ),
                          ],
                        ),

                        const Gap.xxl(),
                        TextFormField(
                          controller: _description,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'About it',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _requirements,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'What it asks for',
                            alignLabelWithHint: true,
                          ),
                        ),

                        const Gap.xxl(),
                        Text('How to apply', style: theme.textTheme.titleSmall),
                        const Gap.md(),
                        TextFormField(
                          controller: _applicationUrl,
                          decoration: const InputDecoration(labelText: 'A link (optional)'),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _applicationEmail,
                          decoration: const InputDecoration(labelText: 'An email (optional)'),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _applicationNote,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Or say how in words',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const Gap.lg(),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final DateTime? chosen = await showDatePicker(
                                    context: context,
                                    initialDate: _closesAt ??
                                        DateTime.now().add(const Duration(days: 30)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 730)),
                                  );
                                  if (chosen != null) setState(() => _closesAt = chosen);
                                },
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(
                            _closesAt == null
                                ? 'When does it close? (optional)'
                                : 'Closes ${_closesAt!.toIso8601String().split('T').first}',
                          ),
                        ),

                        const Gap.xxl(),
                        // The single most useful question on this form.
                        TextFormField(
                          controller: _relationship,
                          decoration: const InputDecoration(
                            labelText: 'How do you know about this?',
                            helperText:
                                'Be honest — "I work there", "my cousin told me", "I saw it in a '
                                'WhatsApp group". It helps the reviewers, and it is not published.',
                          ),
                        ),

                        if (_error != null) ...<Widget>[
                          const Gap.lg(),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.error),
                          ),
                        ],

                        const Gap.xxl(),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const Text('Sending…')
                              : const Text('Send it for review'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Please fill this in.' : null;
}

class _Submitted extends StatelessWidget {
  const _Submitted({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Thank you', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          Text(message, style: theme.textTheme.bodyMedium),
          const Gap.lg(),
          FilledButton(
            onPressed: () => context.go(AppRoutes.opportunities),
            child: const Text('Back to opportunities'),
          ),
        ],
      ),
    );
  }
}

/// Shown to somebody who is NOT SIGNED IN. Never to a member.
///
/// This used to test `canContribute`, which reads a membership flag that only
/// `/api/auth/me` ever set — so a member who had just signed in was told to
/// become a member they already were, and posting worked only after a page
/// reload. The flag is fixed at both ends now, and this gate no longer depends
/// on it: being signed in is the question, and the Worker decides the rest.
///
/// That is the right division anyway. The client hides a control to save
/// somebody a pointless journey; it is not what stops anyone posting.
class _MembersOnly extends StatelessWidget {
  const _MembersOnly();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Posting an opportunity is for members. Every listing has an accountable person behind '
          'it — that is most of what keeps fraudulent listings off this board.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Gap.xl(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton(
              onPressed: () =>
                  context.go(AppRoutes.signInReturningTo(AppRoutes.postOpportunity)),
              child: const Text('Sign in'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.join),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}
