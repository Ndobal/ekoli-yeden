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
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/submission_repository.dart';
import '../about/about_pages.dart';

/// CONTRIBUTE TO EKOLI YEDEN.
///
/// Open to anyone — an elder's grandchild with a photograph on their phone
/// should not have to create an account first. Everything submitted enters
/// `pending_review` and is invisible on the public site until a moderator
/// approves it. The form says so plainly, because a contributor who expects
/// instant publication and does not get it will assume the site is broken.
class ContributePage extends StatefulWidget {
  const ContributePage({this.presetType, this.about, super.key});

  /// Pre-selects a submission type, used by the "suggest a correction" links.
  final String? presetType;

  /// What the correction is about, pre-filled into the description.
  final String? about;

  @override
  State<ContributePage> createState() => _ContributePageState();
}

class _ContributePageState extends State<ContributePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _relationship = TextEditingController();

  late String _type;
  bool _consent = false;
  bool _submitting = false;
  String? _error;
  SubmissionReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _type = widget.presetType ?? 'historical_photograph';
    if (widget.about != null) {
      _description.text = 'Regarding: ${widget.about}\n\n';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_consent) {
      setState(() => _error = 'Please confirm you have the right to share this material.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final SubmissionReceipt receipt =
          await context.read<SubmissionRepository>().submit(
                submissionType: _type,
                title: _title.text.trim(),
                consentGiven: true,
                description: _description.text.trim().isEmpty ? null : _description.text.trim(),
                submitterName: _name.text.trim().isEmpty ? null : _name.text.trim(),
                submitterEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
                submitterPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                submitterRelationship:
                    _relationship.text.trim().isEmpty ? null : _relationship.text.trim(),
              );
      if (mounted) setState(() => _receipt = receipt);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentPath: AppRoutes.contribute,
      seo: const SeoMetadata(
        title: 'Contribute to Ekoli-Yeden',
        description:
            'Share old photographs, documents, stories, oral history and language recordings with '
            'the Ekoli Yeden Digital Home. Every contribution is reviewed before publication.',
        canonicalPath: AppRoutes.contribute,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'Contribute',
            titleKey: 'page.contribute.title',
            titleFallback: 'Contribute to Ekoli-Yeden',
            introKey: 'page.contribute.intro',
            introFallback:
                'Every Ekoli-Yeden person can help build this archive. Nothing you send is '
                'published automatically — it is reviewed by the Preservation Team first.',
            accent: AppColors.green,
          ),
          PageSection(
            reading: true,
            child: _receipt != null ? _Receipt(receipt: _receipt!) : _buildForm(context),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _WhatHappensNext(),
          const Gap.xxl(),

          Text('What are you sharing?', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: SubmissionTypes.all
                .map(
                  (String slug) => DropdownMenuItem<String>(
                    value: slug,
                    child: Text(SubmissionTypes.label(slug)),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) => setState(() => _type = value ?? _type),
          ),
          const Gap.xl(),

          TextFormField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title *',
              helperText: 'A short name for what you are sharing.',
            ),
            validator: (String? value) {
              if (value == null || value.trim().length < 3) {
                return 'Please give this a title of at least 3 characters.';
              }
              return null;
            },
          ),
          const Gap.lg(),

          TextFormField(
            controller: _description,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              helperText:
                  'Anything you can tell us: who is in it, where, when, and how you came by it. '
                  'Even a partial answer is valuable.',
              alignLabelWithHint: true,
            ),
          ),
          const Gap.xxl(),

          Text('About you', style: theme.textTheme.titleMedium),
          const Gap.xs(),
          Text(
            'So the Preservation Team can credit you and follow up if they have questions. '
            'You may leave these blank.',
            style: theme.textTheme.bodySmall,
          ),
          const Gap.lg(),

          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const Gap.lg(),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) return null;
              final bool valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value.trim());
              return valid ? null : 'That does not look like an email address.';
            },
          ),
          const Gap.lg(),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          const Gap.lg(),
          TextFormField(
            controller: _relationship,
            decoration: const InputDecoration(
              labelText: 'Your connection to Ekoli-Yeden',
              helperText: 'For example: born here, family from here, researcher, visitor.',
            ),
          ),
          const Gap.xxl(),

          // Consent is required rather than assumed. An archive that publishes
          // family photographs without permission is not trustworthy.
          CheckboxListTile(
            value: _consent,
            onChanged: (bool? value) => setState(() => _consent = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I have the right to share this material with the archive, and I agree it may be '
              'published here with acknowledgement.',
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
                : const Text('Send to the archive'),
          ),
          const Gap.md(),
          Text(
            'Photograph, document and audio uploads are added in the next stage of the platform. '
            'For now, describe what you have and the Preservation Team will contact you to collect it.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WhatHappensNext extends StatelessWidget {
  const _WhatHappensNext();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<String> steps = <String>[
      'You send the material.',
      'It is recorded as pending review — it does not appear on the website yet.',
      'The Ekoli-Yeden Preservation Team checks it.',
      'Once approved and published, it becomes part of the archive, with you credited.',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What happens next', style: theme.textTheme.titleMedium),
          const Gap.md(),
          ...steps.map(
            (String step) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('· '),
                  Expanded(child: Text(step, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
          const Gap.md(),
          Text(
            'Please only send material you have the right to share.',
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// The confirmation, with the reference code the contributor keeps.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.receipt});

  final SubmissionReceipt receipt;

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
                'Keep this code. You can use it to ask the Preservation Team how your '
                'contribution is progressing.',
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
              onPressed: () => context.go(AppRoutes.contribute),
              child: const Text('Send something else'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to the archive'),
            ),
          ],
        ),
      ],
    );
  }
}
