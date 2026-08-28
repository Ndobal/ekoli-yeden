import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/opportunity.dart';
import '../../repositories/opportunity_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';

/// YAKOLI OPPORTUNITIES (Module 6).
///
/// Jobs, scholarships, training and grants, ordered by what the member can do
/// and how near it is.
///
/// THE FRAUD WARNING IS NOT DECORATION. Fake recruiters asking for a
/// "processing fee" are among the most common frauds people here meet, and a
/// listing carrying this archive's name borrows its credibility to do it. The
/// warning appears on the board and on every listing, and reporting is one
/// press. Please do not quietly remove either.
class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  String? _kind;
  bool _savedOnly = false;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    if (!auth.isSignedIn) return const _SignInRequired();

    final OpportunityRepository repository = context.read<OpportunityRepository>();

    return AppScaffold(
      currentPath: AppRoutes.opportunities,
      seo: const SeoMetadata(
        title: 'Opportunities',
        description: 'Jobs, scholarships, training and grants for members of Ekoli-Yeden.',
        canonicalPath: AppRoutes.opportunities,
        noIndex: true,
      ),
      child: PageSection(
        eyebrow: 'Yakoli',
        title: 'Opportunities',
        description:
            'Jobs, scholarships, training and grants — shown to you in the order they suit you: '
            'what you can do, and how near it is.',
        action: FilledButton.icon(
          onPressed: () => context.go(AppRoutes.postOpportunity),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Post one'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const FraudWarning(),
            const Gap.xl(),
            _Filters(
              kind: _kind,
              savedOnly: _savedOnly,
              onKind: (String? kind) => setState(() {
                _kind = kind;
                _page = 1;
              }),
              onSaved: (bool saved) => setState(() {
                _savedOnly = saved;
                _page = 1;
              }),
            ),
            const Gap.xl(),
            AsyncContent<PaginatedResult<Opportunity>>(
              key: ValueKey<String>('${_kind ?? 'all'}:$_savedOnly:$_page'),
              load: () => repository.list(
                page: _page,
                perPage: 20,
                kind: _kind,
                savedOnly: _savedOnly,
              ),
              loadingMessage: 'Finding what suits you…',
              isEmpty: (PaginatedResult<Opportunity> r) => r.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: Icons.work_outline,
                title: _savedOnly ? 'You have not kept any yet' : 'Nothing listed yet',
                message: _savedOnly
                    ? 'Anything you keep for later appears here.'
                    : 'Opportunities appear here as members and the Preservation Team add them. '
                        'If you know of one, post it — somebody here may be right for it.',
              ),
              builder: (BuildContext context, PaginatedResult<Opportunity> result) {
                final bool matchingOff =
                    result.items.isNotEmpty && !result.items.first.matchingActive;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // A member with no skills recorded matches nothing, and
                    // would otherwise see a page of zeroes with no explanation.
                    if (matchingOff) ...<Widget>[
                      const _MatchingOffNotice(),
                      const Gap.lg(),
                    ],
                    Text(
                      '${Formatters.number(result.total)} open',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Gap.md(),
                    ...result.items.map(
                      (Opportunity item) => OpportunityCard(opportunity: item),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The warning that belongs on every page of this module.
class FraudWarning extends StatelessWidget {
  const FraudWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.gpp_maybe_outlined, size: 20),
          const Gap.hMd(),
          Expanded(
            child: Text(
              'No genuine employer, school or training provider will ever ask you to pay a fee to '
              'apply, to be interviewed, or to be given a job. If a listing here asks you for '
              'money, do not pay it — report the listing instead. It takes one press, and it '
              'protects everybody after you.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchingOffNotice extends StatelessWidget {
  const _MatchingOffNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.tips_and_updates_outlined, size: 18),
          const Gap.hMd(),
          Expanded(
            child: Text(
              'Add your skills and where you are, and this page starts ordering itself around '
              'you. Until then it is just a list.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.accountProfile),
            child: const Text('Add them'),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.kind,
    required this.savedOnly,
    required this.onKind,
    required this.onSaved,
  });

  final String? kind;
  final bool savedOnly;
  final ValueChanged<String?> onKind;
  final ValueChanged<bool> onSaved;

  static const List<({String? value, String label})> _kinds = <({String? value, String label})>[
    (value: null, label: 'Everything'),
    (value: 'job', label: 'Jobs'),
    (value: 'scholarship', label: 'Scholarships'),
    (value: 'training', label: 'Training'),
    (value: 'apprenticeship', label: 'Apprenticeships'),
    (value: 'grant', label: 'Grants'),
    (value: 'internship', label: 'Internships'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        ..._kinds.map(
          (({String? value, String label}) option) => FilterChip(
            selected: !savedOnly && kind == option.value,
            showCheckmark: false,
            label: Text(option.label),
            onSelected: (bool _) {
              onSaved(false);
              onKind(option.value);
            },
          ),
        ),
        FilterChip(
          selected: savedOnly,
          showCheckmark: false,
          avatar: const Icon(Icons.bookmark_outline, size: 16),
          label: const Text('Kept'),
          onSelected: (bool _) => onSaved(!savedOnly),
        ),
      ],
    );
  }
}

/// One listing in a list.
///
/// Compact enough to reuse on the dashboard, where a member sees the few that
/// suit them best without leaving their own page.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({required this.opportunity, this.dense = false, super.key});

  final Opportunity opportunity;

  /// Trims it for the dashboard, where several appear in a narrow column.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? match = opportunity.matchFraction;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.opportunity(opportunity.slug)),
        child: Padding(
          padding: EdgeInsets.all(dense ? AppSpacing.md : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          opportunity.title,
                          style: dense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          opportunity.organisation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Whether the archive has checked it. Shown always, so an
                  // unverified listing looks unverified rather than simply
                  // lacking a badge nobody notices.
                  _VerificationBadge(status: opportunity.verificationStatus),
                ],
              ),
              const Gap.sm(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  _Fact(icon: Icons.badge_outlined, text: opportunity.kindLabel),
                  _Fact(icon: Icons.place_outlined, text: opportunity.placeLabel),
                  if (opportunity.payLabel != null)
                    _Fact(icon: Icons.payments_outlined, text: opportunity.payLabel!),
                  if (opportunity.closesAt != null)
                    _Fact(
                      icon: Icons.event_outlined,
                      text: 'Closes ${Formatters.shortDate(opportunity.closesAt)}',
                    ),
                ],
              ),
              if (match != null && opportunity.totalSkills > 0) ...<Widget>[
                const Gap.sm(),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: match,
                        minHeight: 5,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const Gap.hSm(),
                    Text(
                      '${opportunity.matchedSkills} of ${opportunity.totalSkills} skills you have',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
              if (opportunity.reportCount > 0) ...<Widget>[
                const Gap.sm(),
                Text(
                  'Members have reported this listing.',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool verified = status == 'verified';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: (verified ? AppColors.success : theme.colorScheme.onSurfaceVariant)
            .withValues(alpha: 0.14),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(verified ? Icons.verified_outlined : Icons.help_outline, size: 12),
          const Gap.hXs(),
          Text(
            verified ? 'Checked' : 'Not checked',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const Gap.hXs(),
        Text(text, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentPath: AppRoutes.opportunities,
      child: PageSection(
        reading: true,
        eyebrow: 'Yakoli',
        title: 'Opportunities',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'This board matches jobs, scholarships and training to what you can do and where '
              'you are — so there is nothing useful to show until it knows who you are.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Gap.xl(),
            Wrap(
              spacing: AppSpacing.md,
              children: <Widget>[
                FilledButton(
                  onPressed: () => context.go(AppRoutes.register),
                  child: const Text('Create an account'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      context.go(AppRoutes.signInReturningTo(AppRoutes.opportunities)),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One listing
// ---------------------------------------------------------------------------

class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({required this.slug, super.key});

  final String slug;

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  int _reloads = 0;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    if (!auth.isSignedIn) return const _SignInRequired();

    final OpportunityRepository repository = context.read<OpportunityRepository>();

    return AsyncContent<Opportunity>(
      key: ValueKey<int>(_reloads),
      load: () => repository.show(widget.slug),
      loadingMessage: 'Opening…',
      builder: (BuildContext context, Opportunity item) {
        final ThemeData theme = Theme.of(context);

        return AppScaffold(
          currentPath: AppRoutes.opportunities,
          seo: SeoMetadata(
            title: item.title,
            description: item.summary ?? '${item.kindLabel} at ${item.organisation}',
            canonicalPath: AppRoutes.opportunity(item.slug),
            noIndex: true,
          ),
          child: PageSection(
            reading: true,
            eyebrow: item.kindLabel,
            title: item.title,
            description: item.organisation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.opportunities),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('All opportunities'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                const Gap.lg(),
                if (_notice != null) ...<Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(_notice!, style: theme.textTheme.bodyMedium),
                  ),
                  const Gap.lg(),
                ],
                const FraudWarning(),
                const Gap.xl(),
                Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _Fact(icon: Icons.place_outlined, text: item.placeLabel),
                    if (item.payLabel != null)
                      _Fact(icon: Icons.payments_outlined, text: item.payLabel!)
                    else
                      // Stated rather than left blank. A listing that does not
                      // say what it pays should look like one.
                      const _Fact(icon: Icons.payments_outlined, text: 'Pay not stated'),
                    if (item.closesAt != null)
                      _Fact(
                        icon: Icons.event_outlined,
                        text: 'Closes ${Formatters.date(item.closesAt)}',
                      ),
                    if (item.posterName != null)
                      _Fact(icon: Icons.person_outline, text: 'Posted by ${item.posterName}'),
                  ],
                ),
                if (item.skills.isNotEmpty) ...<Widget>[
                  const Gap.xxl(),
                  Text('What it asks for', style: theme.textTheme.titleMedium),
                  const Gap.sm(),
                  Text(
                    'Ticked means you have already recorded it. A gap is not a refusal — it is '
                    'what you would need to learn.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap.md(),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: item.skills
                        .map(
                          (OpportunitySkill skill) => Chip(
                            avatar: Icon(
                              skill.youHaveIt ? Icons.check_circle_outline : Icons.circle_outlined,
                              size: 15,
                              color: skill.youHaveIt ? AppColors.success : null,
                            ),
                            label: Text(skill.name),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (item.description != null) ...<Widget>[
                  const Gap.xxl(),
                  Text('About it', style: theme.textTheme.titleMedium),
                  const Gap.sm(),
                  Text(item.description!, style: theme.textTheme.bodyLarge),
                ],
                if (item.requirements != null) ...<Widget>[
                  const Gap.xl(),
                  Text('Requirements', style: theme.textTheme.titleMedium),
                  const Gap.sm(),
                  Text(item.requirements!, style: theme.textTheme.bodyMedium),
                ],
                const Gap.xxl(),
                _ApplySection(opportunity: item),
                const Gap.xxl(),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () async {
                        item.isSaved
                            ? await repository.unsave(item.id)
                            : await repository.save(item.id);
                        setState(() => _reloads += 1);
                      },
                      icon: Icon(
                        item.isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        size: 18,
                      ),
                      label: Text(item.isSaved ? 'Kept' : 'Keep for later'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _report(context, item),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Report this listing'),
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _report(BuildContext context, Opportunity item) async {
    final OpportunityRepository repository = context.read<OpportunityRepository>();
    final TextEditingController detail = TextEditingController();
    String reason = 'asks_for_money';

    final bool send = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setInner) => AlertDialog(
              title: const Text('Report this listing'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Thank you for telling us. Enough reports and it comes down straight away, '
                      'before anybody else is caught by it.',
                    ),
                    const Gap.lg(),
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(labelText: 'What is wrong with it?'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'asks_for_money',
                          child: Text('It asks for money'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'not_genuine',
                          child: Text('I do not think it is genuine'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'misleading',
                          child: Text('It is misleading'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'expired',
                          child: Text('It has already closed'),
                        ),
                        DropdownMenuItem<String>(value: 'other', child: Text('Something else')),
                      ],
                      onChanged: (String? value) => setInner(() => reason = value ?? reason),
                    ),
                    const Gap.lg(),
                    TextField(
                      controller: detail,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Anything you can tell us (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Report it'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!send || !context.mounted) return;

    try {
      await repository.report(
        item.id,
        reason: reason,
        detail: detail.text.trim().isEmpty ? null : detail.text.trim(),
      );
      if (mounted) {
        setState(() {
          _notice = 'Thank you. The Preservation Team has been told.';
          _reloads += 1;
        });
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

/// How to apply — and the warning repeated where the money would change hands.
class _ApplySection extends StatelessWidget {
  const _ApplySection({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('How to apply', style: theme.textTheme.titleMedium),
          const Gap.md(),
          if (opportunity.applicationNote != null) ...<Widget>[
            Text(opportunity.applicationNote!, style: theme.textTheme.bodyMedium),
            const Gap.md(),
          ],
          if (opportunity.applicationUrl != null)
            SelectableText(
              opportunity.applicationUrl!,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.navyLight),
            ),
          if (opportunity.applicationEmail != null)
            SelectableText(opportunity.applicationEmail!, style: theme.textTheme.bodyMedium),
          if (opportunity.applicationPhone != null)
            SelectableText(opportunity.applicationPhone!, style: theme.textTheme.bodyMedium),
          if (opportunity.applicationUrl == null &&
              opportunity.applicationEmail == null &&
              opportunity.applicationPhone == null &&
              opportunity.applicationNote == null)
            Text(
              'This listing does not say how to apply. Ask the Preservation Team before acting '
              'on it.',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          const Gap.lg(),
          Text(
            'Do not pay anybody to apply for this.',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}
