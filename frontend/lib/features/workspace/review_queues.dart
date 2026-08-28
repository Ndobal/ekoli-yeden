import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/ancestry.dart';
import '../../models/opportunity.dart';
import '../../models/submissions.dart';
import '../../repositories/news_repository.dart';
import '../../repositories/opportunity_repository.dart';
import '../../repositories/people_repository.dart';
import '../../repositories/remembrance_repository.dart';
import '../../services/api/api_response.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// THE FOUR QUEUES THAT ANSWER THE COMMUNITY.
///
/// ---------------------------------------------------------------------------
/// WHY THESE ARE PAGES AND NOT A SINGLE "SUBMISSIONS" LIST
/// ---------------------------------------------------------------------------
///
/// Each of these asks a different question of whoever is reading it, and the
/// answer needs different things in front of them:
///
///   A **profile** cannot be published until somebody has settled how the
///   archive may publish a page about a person who might be alive. The queue
///   says so before the reviewer presses anything, because the server will
///   refuse and an unexplained refusal reads as a bug.
///
///   **News** is the community's official channel, so an administrator may
///   reword it — and must not lose who sent it, which is why the contributor
///   sits beside the text rather than behind a click.
///
///   A **reported listing** is usually about money. That reason is marked
///   first, because a fraudulent job costs somebody their savings and a wrongly
///   hidden one costs them a few hours.
///
///   A **death report** is the most consequential thing on this platform, and
///   its queue shows how far it has got through the four safeguards rather than
///   offering a publish button beside a name.
///
/// A single list could hold all four. It could not put the right thing in front
/// of the person deciding.

// ---------------------------------------------------------------------------
// Profiles sent in for the People section
// ---------------------------------------------------------------------------

class PersonSubmissionsPage extends StatefulWidget {
  const PersonSubmissionsPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<PersonSubmissionsPage> createState() => _PersonSubmissionsPageState();
}

class _PersonSubmissionsPageState extends State<PersonSubmissionsPage> {
  String _status = 'pending_review';
  int _reloads = 0;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final PeopleRepository repository = context.read<PeopleRepository>();
    final ThemeData theme = Theme.of(context);

    return _QueueShell(
      workspace: widget.workspace,
      currentPath: AppRoutes.adminPersonSubmissions,
      title: 'Profiles sent in',
      intro:
          'People the community has asked us to record. The profile builder collects the same '
          'fields the People section stores, so accepting one is a single action rather than a '
          're-typing.',
      notice: _notice,
      statuses: const <({String value, String label})>[
        (value: 'pending_review', label: 'Waiting'),
        (value: 'in_review', label: 'Being read'),
        (value: 'needs_more', label: 'More needed'),
        (value: 'promoted', label: 'Published'),
        (value: 'rejected', label: 'Declined'),
        (value: 'duplicate', label: 'Already here'),
      ],
      status: _status,
      onStatus: (String value) => setState(() {
        _status = value;
        _reloads += 1;
        _notice = null;
      }),
      child: AsyncContent<PaginatedResult<PersonSubmission>>(
        key: ValueKey<String>('$_status:$_reloads'),
        load: () => repository.submissions(status: _status),
        loadingMessage: 'Opening the queue…',
        isEmpty: (PaginatedResult<PersonSubmission> r) => r.isEmpty,
        emptyBuilder: (BuildContext context) => EmptyView(
          icon: Icons.person_outline,
          showContributeAction: false,
          title: _status == 'pending_review' ? 'Nothing waiting' : 'Nothing in this list',
          message: _status == 'pending_review'
              ? 'Profiles the community sends in arrive here.'
              : 'No submissions in this state.',
        ),
        builder: (BuildContext context, PaginatedResult<PersonSubmission> result) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${Formatters.number(result.total)} ${result.total == 1 ? 'profile' : 'profiles'}',
              style: theme.textTheme.labelMedium,
            ),
            const Gap.md(),
            ...result.items.map(
              (PersonSubmission item) => _PersonCard(
                submission: item,
                onChanged: (String message) => setState(() {
                  _reloads += 1;
                  _notice = message;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.submission, required this.onChanged});

  final PersonSubmission submission;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Card(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(submission.name, style: theme.textTheme.titleMedium),
                  if (submission.headline != null) ...<Widget>[
                    const Gap.xs(),
                    Text(
                      submission.headline!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            StatusBadge(submission.status),
          ],
        ),
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (submission.lifespan != null) _Fact(label: 'Life', value: submission.lifespan!),
            if (submission.profession != null)
              _Fact(label: 'What they do', value: submission.profession!),
            if (submission.communityArea != null)
              _Fact(label: 'From', value: submission.communityArea!),
            if (submission.city != null || submission.country != null)
              _Fact(
                label: 'Lives',
                value: <String?>[
                  submission.city,
                  submission.country,
                ].whereType<String>().join(', '),
              ),
            _Fact(label: 'Reference', value: submission.reference),
          ],
        ),

        // The gate, stated before the button rather than as a server error
        // after it. The reviewer can act on this — asking the contributor, or
        // recording what they already know — and an unexplained refusal is
        // what stops them.
        if (submission.blocksPublication) ...<Widget>[
          const Gap.lg(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.privacy_tip_outlined, size: 18, color: theme.colorScheme.error),
                const Gap.hMd(),
                Expanded(
                  child: Text(
                    'This cannot be published yet. Nobody has said how the archive may publish '
                    'a page about them, and they may be living. Ask the contributor, or record '
                    'what you know, before publishing.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ] else ...<Widget>[
          const Gap.md(),
          _Fact(label: 'How we may publish', value: submission.consentLabel),
        ],

        if (submission.biography != null) ...<Widget>[
          const Gap.lg(),
          Text('Their life', style: theme.textTheme.labelMedium),
          const Gap.xs(),
          SelectableText(
            Formatters.excerpt(submission.biography, maxLength: 900),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (submission.whyNotable != null) ...<Widget>[
          const Gap.lg(),
          Text('Why they should be recorded', style: theme.textTheme.labelMedium),
          const Gap.xs(),
          Text(submission.whyNotable!, style: theme.textTheme.bodyMedium),
        ],

        const Gap.lg(),
        _Contributor(
          name: submission.contributorName,
          email: submission.contributorEmail,
          phone: submission.contributorPhone,
          relationship: submission.contributorRelationship,
          sentAt: submission.createdAt,
        ),

        if (submission.reviewNotes != null) ...<Widget>[
          const Gap.md(),
          Text('Review notes: ${submission.reviewNotes}', style: theme.textTheme.bodySmall),
        ],

        if (submission.status != 'promoted') ...<Widget>[
          const Gap.lg(),
          const Divider(height: 1),
          const Gap.lg(),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              FilledButton.icon(
                onPressed: submission.blocksPublication
                    ? null
                    : () async {
                        try {
                          final String slug = await context.read<PeopleRepository>().promote(
                            submission.id,
                          );
                          onChanged(
                            slug.isEmpty
                                ? 'Published.'
                                : 'Published — ${submission.name} is in the People section.',
                          );
                        } on AppException catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error.message)));
                          }
                        }
                      },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Publish this profile'),
              ),
              OutlinedButton(
                onPressed: () => _review(context, submission.id, 'needs_more', onChanged),
                child: const Text('Ask for more'),
              ),
              OutlinedButton(
                onPressed: () => _review(context, submission.id, 'duplicate', onChanged),
                child: const Text('Already in the archive'),
              ),
              TextButton(
                onPressed: () => _review(context, submission.id, 'rejected', onChanged),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _review(
    BuildContext context,
    String id,
    String status,
    ValueChanged<String> onDone,
  ) async {
    final String? notes = await _askForNotes(
      context,
      title: switch (status) {
        'needs_more' => 'What else do you need?',
        'duplicate' => 'Which record is this already?',
        _ => 'Why are you declining it?',
      },
      hint: 'The contributor can read this when they check their reference.',
    );
    if (notes == null || !context.mounted) return;

    try {
      await context.read<PeopleRepository>().review(id, status: status, notes: notes);
      onDone('Saved.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// News the community has sent in
// ---------------------------------------------------------------------------

class NewsSubmissionsPage extends StatefulWidget {
  const NewsSubmissionsPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<NewsSubmissionsPage> createState() => _NewsSubmissionsPageState();
}

class _NewsSubmissionsPageState extends State<NewsSubmissionsPage> {
  String _status = 'pending_review';
  int _reloads = 0;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final NewsRepository repository = context.read<NewsRepository>();

    return _QueueShell(
      workspace: widget.workspace,
      currentPath: AppRoutes.adminNewsSubmissions,
      title: 'News sent in',
      intro:
          'Anybody may write news; an administrator decides what goes out under the community’s '
          'name. You can reword a piece before publishing it — what you cannot do is lose who '
          'sent it, and that travels with it automatically.',
      notice: _notice,
      statuses: const <({String value, String label})>[
        (value: 'pending_review', label: 'Waiting'),
        (value: 'in_review', label: 'Being read'),
        (value: 'needs_more', label: 'More needed'),
        (value: 'promoted', label: 'Published'),
        (value: 'rejected', label: 'Declined'),
      ],
      status: _status,
      onStatus: (String value) => setState(() {
        _status = value;
        _reloads += 1;
        _notice = null;
      }),
      child: AsyncContent<PaginatedResult<NewsSubmission>>(
        key: ValueKey<String>('$_status:$_reloads'),
        load: () => repository.submissions(status: _status),
        loadingMessage: 'Opening the queue…',
        isEmpty: (PaginatedResult<NewsSubmission> r) => r.isEmpty,
        emptyBuilder: (BuildContext context) => EmptyView(
          icon: Icons.article_outlined,
          showContributeAction: false,
          title: _status == 'pending_review' ? 'Nothing waiting' : 'Nothing in this list',
          message: _status == 'pending_review'
              ? 'News members send in arrives here.'
              : 'No submissions in this state.',
        ),
        builder: (BuildContext context, PaginatedResult<NewsSubmission> result) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: result.items
              .map(
                (NewsSubmission item) => _NewsCard(
                  submission: item,
                  onChanged: (String message) => setState(() {
                    _reloads += 1;
                    _notice = message;
                  }),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.submission, required this.onChanged});

  final NewsSubmission submission;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Card(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(submission.title, style: theme.textTheme.titleMedium)),
            StatusBadge(submission.status),
          ],
        ),
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (submission.category != null)
              _Fact(label: 'Kind', value: submission.category!),
            if (submission.happenedOn != null)
              _Fact(label: 'Happened', value: Formatters.date(submission.happenedOn)),
            if (submission.location != null) _Fact(label: 'Where', value: submission.location!),
            _Fact(label: 'Reference', value: submission.reference),
          ],
        ),
        const Gap.lg(),
        SelectableText(
          Formatters.excerpt(submission.body, maxLength: 1200),
          style: theme.textTheme.bodyMedium,
        ),

        // How they know, given its own line. News from somebody who was there
        // is a different thing from news read in a group chat, and this is the
        // field that decides what an administrator does with it.
        if (submission.sourceNote != null) ...<Widget>[
          const Gap.lg(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.info_outline, size: 18),
                const Gap.hMd(),
                Expanded(
                  child: Text(
                    'How they know: ${submission.sourceNote}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],

        const Gap.lg(),
        _Contributor(
          name: submission.contributorName,
          email: submission.contributorEmail,
          phone: submission.contributorPhone,
          sentAt: submission.createdAt,
        ),

        if (submission.status != 'promoted') ...<Widget>[
          const Gap.lg(),
          const Divider(height: 1),
          const Gap.lg(),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => _publish(context, submission, onChanged),
                icon: const Icon(Icons.publish_outlined, size: 18),
                label: const Text('Edit and publish'),
              ),
              OutlinedButton(
                onPressed: () => _review(context, submission.id, 'needs_more', onChanged),
                child: const Text('Ask for more'),
              ),
              TextButton(
                onPressed: () => _review(context, submission.id, 'rejected', onChanged),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// The editing step is the publishing step.
  ///
  /// One dialog, pre-filled with what arrived: an administrator who has to
  /// publish first and correct afterwards will publish a headline they would
  /// not have chosen, under the community's name.
  Future<void> _publish(
    BuildContext context,
    NewsSubmission submission,
    ValueChanged<String> onDone,
  ) async {
    final TextEditingController title = TextEditingController(text: submission.title);
    final TextEditingController excerpt = TextEditingController(text: submission.excerpt ?? '');
    final TextEditingController body = TextEditingController(text: submission.body);

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Publish this news'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Word it as it should appear. The contributor is credited whatever you '
                      'change.',
                    ),
                    const Gap.lg(),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Headline'),
                    ),
                    const Gap.md(),
                    TextField(
                      controller: excerpt,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Summary',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const Gap.md(),
                    TextField(
                      controller: body,
                      minLines: 8,
                      maxLines: 16,
                      decoration: const InputDecoration(
                        labelText: 'The story',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Publish it'),
              ),
            ],
          ),
        ) ??
        false;

    if (!go || !context.mounted) return;

    try {
      await context.read<NewsRepository>().promote(
        submission.id,
        title: title.text.trim(),
        excerpt: excerpt.text.trim().isEmpty ? null : excerpt.text.trim(),
        body: body.text.trim(),
      );
      onDone('Published.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _review(
    BuildContext context,
    String id,
    String status,
    ValueChanged<String> onDone,
  ) async {
    final String? notes = await _askForNotes(
      context,
      title: status == 'needs_more' ? 'What else do you need?' : 'Why are you declining it?',
      hint: 'The contributor can read this when they check their reference.',
    );
    if (notes == null || !context.mounted) return;

    try {
      await context.read<NewsRepository>().review(id, status: status, notes: notes);
      onDone('Saved.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Opportunities: listings awaiting review, and listings members reported
// ---------------------------------------------------------------------------

class OpportunityReviewPage extends StatefulWidget {
  const OpportunityReviewPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<OpportunityReviewPage> createState() => _OpportunityReviewPageState();
}

class _OpportunityReviewPageState extends State<OpportunityReviewPage> {
  /// Reports first, and by default.
  ///
  /// A queue of new listings can wait an hour. A listing somebody has said is
  /// asking them for money cannot.
  bool _showReports = true;
  String _status = 'pending_review';
  int _reloads = 0;
  String? _notice;

  void _reload(String message) => setState(() {
    _reloads += 1;
    _notice = message;
  });

  @override
  Widget build(BuildContext context) {
    final OpportunityRepository repository = context.read<OpportunityRepository>();
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.adminOpportunities,
      title: 'Opportunities',
      workspaceName: widget.workspace == WorkspaceKind.admin ? 'Administration' : 'Editorial',
      accent: widget.workspace == WorkspaceKind.admin ? AppColors.gold : AppColors.skyBlue,
      navigation: widget.workspace == WorkspaceKind.admin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'What members have reported, and listings waiting to be published. A listing that '
            'asks anybody for money is fraud until proven otherwise — take it down first and '
            'ask afterwards.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.xl(),
          if (_notice != null) ...<Widget>[_Notice(text: _notice!), const Gap.xl()],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Reported'),
                selected: _showReports,
                onSelected: (_) => setState(() => _showReports = true),
              ),
              ChoiceChip(
                label: const Text('Waiting to be published'),
                selected: !_showReports,
                onSelected: (_) => setState(() {
                  _showReports = false;
                  _status = 'pending_review';
                }),
              ),
            ],
          ),
          const Gap.xl(),
          if (_showReports)
            AsyncContent<List<OpportunityReport>>(
              key: ValueKey<String>('reports:$_reloads'),
              load: repository.reports,
              loadingMessage: 'Opening the queue…',
              isEmpty: (List<OpportunityReport> items) => items.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.verified_user_outlined,
                showContributeAction: false,
                title: 'Nothing reported',
                message:
                    'Members can report any listing in one press. Anything they send appears '
                    'here.',
              ),
              builder: (BuildContext context, List<OpportunityReport> items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map(
                      (OpportunityReport report) =>
                          _OpportunityReportCard(report: report, onChanged: _reload),
                    )
                    .toList(growable: false),
              ),
            )
          else
            AsyncContent<PaginatedResult<Opportunity>>(
              key: ValueKey<String>('listings:$_status:$_reloads'),
              load: () => repository.forReview(status: _status),
              loadingMessage: 'Opening the queue…',
              isEmpty: (PaginatedResult<Opportunity> r) => r.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.work_outline,
                showContributeAction: false,
                title: 'Nothing waiting',
                message: 'Listings members post arrive here before anybody else sees them.',
              ),
              builder: (BuildContext context, PaginatedResult<Opportunity> result) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.items
                    .map(
                      (Opportunity listing) =>
                          _ListingCard(listing: listing, onChanged: _reload),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpportunityReportCard extends StatelessWidget {
  const _OpportunityReportCard({required this.report, required this.onChanged});

  final OpportunityReport report;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Card(
      accent: report.isMoneyClaim ? theme.colorScheme.error : null,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: report.isMoneyClaim
                    ? theme.colorScheme.error
                    : theme.colorScheme.secondaryContainer,
                borderRadius: AppRadius.pillAll,
              ),
              child: Text(
                report.reasonLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: report.isMoneyClaim
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              Formatters.relative(report.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Gap.lg(),
        Text(report.title ?? 'A listing', style: theme.textTheme.titleMedium),
        if (report.organisation != null) ...<Widget>[
          const Gap.xs(),
          Text(
            report.organisation!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (report.detail != null) ...<Widget>[
          const Gap.md(),
          SelectableText(report.detail!, style: theme.textTheme.bodyMedium),
        ],
        const Gap.lg(),
        const Divider(height: 1),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            if (report.slug != null)
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.opportunity(report.slug!)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open the listing'),
              ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final OpportunityRepository repository = context
                      .read<OpportunityRepository>();
                  // Taken down first, then the report closed. Doing it in the
                  // other order leaves a fraudulent listing live if the second
                  // request fails.
                  await repository.decide(report.opportunityId, status: 'archived');
                  await repository.settleReport(report.id, state: 'upheld');
                  onChanged('Taken down, and the report closed.');
                } on AppException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Take it down'),
            ),
            TextButton(
              onPressed: () async {
                final String? note = await _askForNotes(
                  context,
                  title: 'Dismiss this report',
                  hint: 'Why it is being left up (optional but useful to the next reviewer).',
                );
                if (note == null || !context.mounted) return;
                try {
                  await context.read<OpportunityRepository>().settleReport(
                    report.id,
                    state: 'dismissed',
                    note: note,
                  );
                  onChanged('Dismissed.');
                } on AppException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('Nothing wrong with it'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.onChanged});

  final Opportunity listing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Card(
      children: <Widget>[
        Text(listing.title, style: theme.textTheme.titleMedium),
        const Gap.xs(),
        Text(
          listing.organisation,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (listing.summary != null) ...<Widget>[
          const Gap.md(),
          Text(listing.summary!, style: theme.textTheme.bodyMedium),
        ],
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _Fact(label: 'Kind', value: listing.kind),
            if (listing.locationText != null)
              _Fact(label: 'Where', value: listing.locationText!),
            if (listing.posterName != null)
              _Fact(label: 'Posted by', value: listing.posterName!),
            if (listing.reportCount > 0)
              _Fact(label: 'Reports', value: '${listing.reportCount}'),
          ],
        ),
        const Gap.lg(),
        const Divider(height: 1),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _decide(context, status: 'published', message: 'Published.'),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Publish it'),
            ),
            // Verifying is the archive saying somebody checked this is real.
            // Separate from publishing on purpose — the two claims are not the
            // same, and a listing can be worth showing without being vouched
            // for.
            OutlinedButton.icon(
              onPressed: () => _decide(
                context,
                verification: 'verified',
                message: 'Marked as checked.',
              ),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Mark it checked'),
            ),
            TextButton(
              onPressed: () => _decide(context, status: 'rejected', message: 'Declined.'),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text('Decline'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _decide(
    BuildContext context, {
    String? status,
    String? verification,
    required String message,
  }) async {
    try {
      await context.read<OpportunityRepository>().decide(
        listing.id,
        status: status,
        verificationStatus: verification,
      );
      onChanged(message);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Death reports
// ---------------------------------------------------------------------------

class RemembranceQueuePage extends StatefulWidget {
  const RemembranceQueuePage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<RemembranceQueuePage> createState() => _RemembranceQueuePageState();
}

class _RemembranceQueuePageState extends State<RemembranceQueuePage> {
  String _state = 'reported';
  int _reloads = 0;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final RemembranceRepository repository = context.read<RemembranceRepository>();

    return _QueueShell(
      workspace: widget.workspace,
      currentPath: AppRoutes.adminRemembrance,
      title: 'Remembrance',
      intro:
          'Deaths the community has reported. A report changes nothing on its own; a family '
          'member who was already recorded as family has to confirm it; the person it is about '
          'is told and can say it is wrong. Publishing a memorial is a further decision, and '
          'every step here can be undone.',
      notice: _notice,
      statuses: const <({String value, String label})>[
        (value: 'reported', label: 'Reported'),
        (value: 'family_confirmed', label: 'Confirmed by family'),
        (value: 'contested', label: 'Contested'),
        (value: 'memorialised', label: 'Remembered'),
        (value: 'rejected', label: 'Rejected'),
      ],
      status: _state,
      onStatus: (String value) => setState(() {
        _state = value;
        _reloads += 1;
        _notice = null;
      }),
      child: AsyncContent<PaginatedResult<DeathReport>>(
        key: ValueKey<String>('$_state:$_reloads'),
        load: () => repository.reports(state: _state),
        loadingMessage: 'Opening the queue…',
        isEmpty: (PaginatedResult<DeathReport> r) => r.isEmpty,
        emptyBuilder: (BuildContext context) => const EmptyView(
          icon: Icons.local_florist_outlined,
          showContributeAction: false,
          title: 'Nothing here',
          message: 'Nothing is waiting in this state.',
        ),
        builder: (BuildContext context, PaginatedResult<DeathReport> result) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: result.items
              .map(
                (DeathReport report) => _DeathReportCard(
                  report: report,
                  onChanged: (String message) => setState(() {
                    _reloads += 1;
                    _notice = message;
                  }),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _DeathReportCard extends StatelessWidget {
  const _DeathReportCard({required this.report, required this.onChanged});

  final DeathReport report;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Card(
      accent: report.isContested ? theme.colorScheme.error : null,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(report.subjectName, style: theme.textTheme.titleMedium)),
            Text(report.stateLabel, style: theme.textTheme.labelMedium),
          ],
        ),

        // Everything else on this card is irrelevant while this is true.
        if (report.isContested) ...<Widget>[
          const Gap.lg(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: AppRadius.smAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The account holder says this is wrong.',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
                ),
                if (report.contestNote != null) ...<Widget>[
                  const Gap.sm(),
                  Text(report.contestNote!, style: theme.textTheme.bodyMedium),
                ],
                const Gap.sm(),
                Text(
                  'Their account has already been restored. Nothing can be published from this '
                  'report until it is settled.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],

        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (report.reporterName != null)
              _Fact(label: 'Reported by', value: report.reporterName!),
            if (report.reporterRelationship != null)
              _Fact(label: 'Says they are', value: report.reporterRelationship!),
            _Fact(
              label: 'Family confirmations',
              value: '${report.confirmations}',
            ),
            if (report.dateOfDeath != null)
              _Fact(label: 'Date', value: Formatters.date(report.dateOfDeath)),
            if (report.placeOfDeath != null)
              _Fact(label: 'Place', value: report.placeOfDeath!),
            _Fact(
              label: 'Account',
              value: report.hasAccount ? 'Has one — they were told' : 'None on this platform',
            ),
            if (report.createdAt != null)
              _Fact(label: 'Reported', value: Formatters.relative(report.createdAt)),
          ],
        ),

        if (report.detail != null) ...<Widget>[
          const Gap.lg(),
          SelectableText(report.detail!, style: theme.textTheme.bodyMedium),
        ],

        const Gap.lg(),
        const Divider(height: 1),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            if (!report.isMemorialised)
              FilledButton.icon(
                onPressed: report.isContested
                    ? null
                    : () => _publish(context, report, onChanged),
                icon: const Icon(Icons.local_florist_outlined, size: 18),
                label: const Text('Write the memorial'),
              ),
            TextButton.icon(
              onPressed: () => _reject(context, report, onChanged),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Reject and restore the account'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _publish(
    BuildContext context,
    DeathReport report,
    ValueChanged<String> onDone,
  ) async {
    final TextEditingController biography = TextEditingController();
    final TextEditingController birthYear = TextEditingController();

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('A page for ${report.subjectName}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'This publishes a memorial in the Ancestry Records. Write only what is '
                      'known — an empty field is the truth, and a guessed year becomes the '
                      'archive’s answer.',
                    ),
                    const Gap.lg(),
                    TextField(
                      controller: birthYear,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Year of birth, if it is known',
                      ),
                    ),
                    const Gap.md(),
                    TextField(
                      controller: biography,
                      minLines: 5,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Their life',
                        alignLabelWithHint: true,
                        helperText: 'This can be added to later — it does not have to be '
                            'complete today.',
                        helperMaxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Publish the memorial'),
              ),
            ],
          ),
        ) ??
        false;

    if (!go || !context.mounted) return;

    try {
      await context.read<RemembranceRepository>().publishMemorial(
        report.id,
        biography: biography.text.trim().isEmpty ? null : biography.text.trim(),
        birthYear: int.tryParse(birthYear.text.trim()),
      );
      onDone('The memorial is published.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    DeathReport report,
    ValueChanged<String> onDone,
  ) async {
    final String? reason = await _askForNotes(
      context,
      title: 'Reject this report',
      hint: 'What you found. The account is restored either way.',
    );
    if (reason == null || !context.mounted) return;

    try {
      await context.read<RemembranceRepository>().reject(report.id, reason: reason);
      onDone('Rejected, and the account restored.');
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared furniture
// ---------------------------------------------------------------------------

/// The frame every queue on this page shares.
class _QueueShell extends StatelessWidget {
  const _QueueShell({
    required this.workspace,
    required this.currentPath,
    required this.title,
    required this.intro,
    required this.statuses,
    required this.status,
    required this.onStatus,
    required this.child,
    this.notice,
  });

  final WorkspaceKind workspace;
  final String currentPath;
  final String title;
  final String intro;
  final List<({String value, String label})> statuses;
  final String status;
  final ValueChanged<String> onStatus;
  final Widget child;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isAdmin = workspace == WorkspaceKind.admin;

    return WorkspaceShell(
      currentPath: currentPath,
      title: title,
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            intro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.xl(),
          if (notice != null) ...<Widget>[_Notice(text: notice!), const Gap.xl()],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: statuses
                .map(
                  (({String value, String label}) option) => ChoiceChip(
                    label: Text(option.label),
                    selected: status == option.value,
                    onSelected: (_) => onStatus(option.value),
                  ),
                )
                .toList(growable: false),
          ),
          const Gap.xl(),
          child,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, this.accent});

  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: accent?.withValues(alpha: 0.6) ?? theme.colorScheme.outlineVariant,
            width: accent == null ? 1 : 1.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

/// One labelled fact, in a row of them.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Who sent it, and how to reach them.
///
/// Beside the material rather than behind a click: a reviewer who needs one
/// more sentence should be able to see, without navigating anywhere, whether
/// there is anybody to ask.
class _Contributor extends StatelessWidget {
  const _Contributor({
    this.name,
    this.email,
    this.phone,
    this.relationship,
    this.sentAt,
  });

  final String? name;
  final String? email;
  final String? phone;
  final String? relationship;
  final String? sentAt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('SENT IN BY', style: theme.textTheme.labelSmall),
          const Gap.xs(),
          SelectableText(
            <String?>[
              name ?? 'Somebody who did not give a name',
              relationship,
              email,
              phone,
            ].whereType<String>().join('  ·  '),
            style: theme.textTheme.bodyMedium,
          ),
          if (sentAt != null) ...<Widget>[
            const Gap.xs(),
            Text(
              Formatters.relative(sentAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// Asks for a sentence, and returns null if the reviewer changed their mind.
///
/// Returning an empty string rather than null when they left it blank is
/// deliberate: "I have nothing to add" is an answer, and forcing a note would
/// only produce a full stop.
Future<String?> _askForNotes(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final TextEditingController notes = TextEditingController();

  final bool go =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: TextField(
              controller: notes,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(hintText: hint, alignLabelWithHint: true),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ) ??
      false;

  return go ? notes.text.trim() : null;
}
