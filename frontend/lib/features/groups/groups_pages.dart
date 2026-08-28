import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/community_group.dart';
import '../../repositories/group_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';

/// THE GROUPS OF EKOLI-YEDEN.
///
/// Age grades, cultural groups, associations and unions — one section rather
/// than one per kind. They need the same things of the archive, and they are
/// the same thing to a visitor: a body of people who organise themselves.
///
/// The kind is a filter, not a separate site. That is what lets somebody who
/// arrives looking for their age grade also discover the dance troupe, and it
/// is why `/age-grades` and `/cultural-groups` are this page with a filter
/// applied rather than pages of their own.
class GroupsListPage extends StatefulWidget {
  const GroupsListPage({this.fixedKind, super.key});

  /// Locks the page to one kind. Set for `/age-grades` and `/cultural-groups`,
  /// which are the same page arrived at by a more specific door.
  final String? fixedKind;

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  String? _kind;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _kind = widget.fixedKind;
  }

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();
    final AuthController auth = context.watch<AuthController>();
    final bool locked = widget.fixedKind != null;

    final String title = switch (widget.fixedKind) {
      'age_grade' => 'Age grades',
      'cultural_group' => 'Cultural groups',
      _ => 'Groups and age grades',
    };

    return AppScaffold(
      currentPath: locked
          ? (widget.fixedKind == 'age_grade' ? AppRoutes.ageGrades : AppRoutes.culturalGroups)
          : AppRoutes.groups,
      seo: SeoMetadata(
        title: title,
        description:
            'The age grades, cultural groups, associations and unions of Ekoli-Yeden — who they '
            'are, when they formed, and how to join.',
        canonicalPath: locked
            ? (widget.fixedKind == 'age_grade' ? AppRoutes.ageGrades : AppRoutes.culturalGroups)
            : AppRoutes.groups,
      ),
      child: PageSection(
        eyebrow: 'Community',
        title: title,
        description: switch (widget.fixedKind) {
          'age_grade' =>
            'Age grades organise Ekoli-Yeden by generation. Each covers a span of birth years, and '
                'everybody born in those years belongs to it.',
          'cultural_group' =>
            'The dance troupes, masquerade societies, choirs and cultural associations that keep '
                'the practices of Ekoli-Yeden alive.',
          _ =>
            'The bodies the community organises itself into — age grades by generation, and the '
                'cultural groups, associations and unions people form.',
        },
        action: auth.isSignedIn
            ? FilledButton.icon(
                onPressed: () => context.go(AppRoutes.registerGroup),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Register a group'),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!locked) ...<Widget>[
              _KindFilter(
                selected: _kind,
                onChanged: (String? kind) => setState(() {
                  _kind = kind;
                  _page = 1;
                }),
              ),
              const Gap.xl(),
            ],
            AsyncContent<PaginatedResult<CommunityGroup>>(
              key: ValueKey<String>('${_kind ?? 'all'}:$_page'),
              load: () => repository.list(page: _page, perPage: 24, kind: _kind),
              loadingMessage: 'Loading…',
              isEmpty: (PaginatedResult<CommunityGroup> r) => r.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: Icons.groups_outlined,
                title: 'None recorded yet',
                message: widget.fixedKind == 'age_grade'
                    ? 'No age grade has registered yet. If yours has not, one of its members can '
                        'register it — the person who does becomes its first officer.'
                    : 'No group has registered yet. Any member can register theirs.',
              ),
              builder: (BuildContext context, PaginatedResult<CommunityGroup> result) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${Formatters.number(result.total)} recorded',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Gap.lg(),
                    _GroupGrid(groups: result.items),
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

class _KindFilter extends StatelessWidget {
  const _KindFilter({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  static const List<({String? value, String label})> _options = <({String? value, String label})>[
    (value: null, label: 'All'),
    (value: 'age_grade', label: 'Age grades'),
    (value: 'cultural_group', label: 'Cultural groups'),
    (value: 'association', label: 'Associations'),
    (value: 'union', label: 'Unions'),
    (value: 'society', label: 'Societies'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _options
          .map(
            (({String? value, String label}) option) => FilterChip(
              selected: selected == option.value,
              showCheckmark: false,
              label: Text(option.label),
              onSelected: (bool _) => onChanged(option.value),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid({required this.groups});

  final List<CommunityGroup> groups;

  @override
  Widget build(BuildContext context) {
    final int columns = context.gridColumns(max: 3);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: groups
              .map(
                (CommunityGroup group) =>
                    SizedBox(width: width, child: _GroupCard(group: group)),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final CommunityGroup group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.group(group.slug)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                group.kindLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.greenDark,
                  letterSpacing: 0.8,
                ),
              ),
              const Gap.sm(),
              Text(group.title, style: theme.textTheme.titleMedium),
              if (group.subtitle != null) ...<Widget>[
                const Gap.xs(),
                Text(
                  group.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Gap.md(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  // The bracket is the most useful fact about an age grade: it
                  // is how somebody works out whether it is theirs.
                  if (group.bracketLabel != null)
                    _Chip(icon: Icons.cake_outlined, text: group.bracketLabel!),
                  if (group.formedYear != null)
                    _Chip(icon: Icons.history_outlined, text: 'Formed ${group.formedYear}'),
                  if (group.memberCount > 0)
                    _Chip(
                      icon: Icons.people_outline,
                      text: group.memberCount == 1 ? '1 member' : '${group.memberCount} members',
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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const Gap.hXs(),
        Text(text, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One group
// ---------------------------------------------------------------------------

/// ONE GROUP'S PAGE.
///
/// What a visitor sees, plus whatever the reader's own standing adds to it. The
/// server decides that — the `viewer` block on the response says what this
/// person may do, and the page draws accordingly rather than guessing.
class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({required this.slug, super.key});

  final String slug;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) => setState(() {
        _reloads += 1;
        _notice = notice;
      });

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();
    final AuthController auth = context.watch<AuthController>();

    return AsyncContent<CommunityGroup>(
      key: ValueKey<int>(_reloads),
      load: () => repository.show(widget.slug, authenticated: auth.isSignedIn),
      loadingMessage: 'Opening…',
      builder: (BuildContext context, CommunityGroup group) {
        final ThemeData theme = Theme.of(context);

        return AppScaffold(
          currentPath: group.isAgeGrade ? AppRoutes.ageGrades : AppRoutes.groups,
          seo: SeoMetadata(
            title: group.title,
            description: group.excerpt ?? group.subtitle ?? '${group.kindLabel} of Ekoli-Yeden',
            canonicalPath: AppRoutes.group(group.slug),
            type: 'article',
          ),
          child: Column(
            children: <Widget>[
              PageSection(
                eyebrow: group.kindLabel,
                title: group.title,
                description: group.subtitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_notice != null) ...<Widget>[
                      _Notice(message: _notice!),
                      const Gap.lg(),
                    ],
                    if (group.motto != null) ...<Widget>[
                      Text(
                        '“${group.motto}”',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.greenDark,
                        ),
                      ),
                      const Gap.lg(),
                    ],
                    Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        if (group.bracketLabel != null)
                          _Chip(icon: Icons.cake_outlined, text: group.bracketLabel!),
                        if (group.formedYear != null)
                          _Chip(icon: Icons.history_outlined, text: 'Formed ${group.formedYear}'),
                        _Chip(
                          icon: Icons.people_outline,
                          text: group.memberCount == 1
                              ? '1 member'
                              : '${group.memberCount} members',
                        ),
                      ],
                    ),
                    const Gap.xl(),
                    _JoinControl(group: group, onChanged: _reload),
                    if (group.body != null) ...<Widget>[
                      const Gap.xxl(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
                        child: Text(group.body!, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ],
                ),
              ),

              if (group.officers.isNotEmpty)
                PageSection(
                  title: 'Its officers',
                  background: theme.colorScheme.surfaceContainerHigh,
                  child: Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.md,
                    children: group.officers
                        .map(
                          (GroupOfficer officer) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(officer.name, style: theme.textTheme.bodyMedium),
                                Text(
                                  officer.office ?? officer.roleLabel,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),

              // The dues, and where they go. Members only — the server sends no
              // account details to anybody else, so this section is simply
              // absent for a visitor rather than being hidden from them.
              if (group.viewer.isMember && (group.hasDues || group.paymentAccounts.isNotEmpty))
                PageSection(
                  title: 'Dues',
                  child: _DuesSection(group: group),
                ),

              if (group.roster.isNotEmpty)
                PageSection(
                  title: 'Its members',
                  description:
                      'Only those who agreed to be listed appear here. Being in a group is not '
                      'consent to be named on the internet.',
                  background: theme.colorScheme.surfaceContainerHigh,
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: group.roster
                        .map(
                          (GroupRosterEntry entry) => Chip(
                            label: Text(entry.name),
                            avatar: entry.isDeceased
                                ? const Icon(Icons.local_florist_outlined, size: 14)
                                : null,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),

              if (group.viewer.isOfficer)
                PageSection(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'You are an officer of this group.',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.groupManage(group.slug)),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Manage it'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Joining, or the reason you cannot.
class _JoinControl extends StatefulWidget {
  const _JoinControl({required this.group, required this.onChanged});

  final CommunityGroup group;
  final void Function([String? notice]) onChanged;

  @override
  State<_JoinControl> createState() => _JoinControlState();
}

class _JoinControlState extends State<_JoinControl> {
  bool _busy = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ({String state, String message}) result =
          await context.read<GroupRepository>().join(widget.group.id);
      widget.onChanged(result.message);
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
    final GroupViewer viewer = widget.group.viewer;

    if (viewer.isMember) {
      return Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          const Gap.hSm(),
          Text('You are a member of this group.', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    if (viewer.hasAsked) {
      return Text(
        'You have asked to join. Its officers will answer.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    if (!auth.isSignedIn) {
      return OutlinedButton(
        onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.group(widget.group.slug))),
        child: const Text('Sign in to join'),
      );
    }

    if (!viewer.canRequestToJoin) {
      return Text(
        widget.group.joinPolicy == 'invite'
            ? 'This group is by invitation. Speak to one of its officers.'
            : 'This group is not taking new members at the moment.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _busy ? null : _join,
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: Text(
            widget.group.joinPolicy == 'by_request' ? 'Ask to join' : 'Join this group',
          ),
        ),
        if (widget.group.isAgeGrade) ...<Widget>[
          const Gap.sm(),
          Text(
            'An age grade is decided by the year you were born, so your date of birth has to be '
            'on your profile.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (_error != null) ...<Widget>[
          const Gap.sm(),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// The dues, and where they are sent.
///
/// The wording here is careful on purpose. The platform never receives the
/// money: a member sends it to the group's own account the way they already
/// would, and records it so both sides are looking at the same list.
class _DuesSection extends StatelessWidget {
  const _DuesSection({required this.group});

  final CommunityGroup group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (group.hasDues)
          Text(
            '${group.duesCurrency} ${Formatters.number(group.duesAmount!.round())}'
            '${group.duesPeriod == null ? '' : ' ${group.duesPeriod}'}',
            style: theme.textTheme.headlineSmall,
          ),
        if (group.duesNotes != null) ...<Widget>[
          const Gap.sm(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
            child: Text(group.duesNotes!, style: theme.textTheme.bodyMedium),
          ),
        ],
        if (group.paymentAccounts.isNotEmpty) ...<Widget>[
          const Gap.xl(),
          Text('Where to send it', style: theme.textTheme.titleSmall),
          const Gap.md(),
          ...group.paymentAccounts.map(
            (GroupPaymentAccount account) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (account.label != null)
                    Text(account.label!, style: theme.textTheme.labelMedium),
                  Text(account.bankName, style: theme.textTheme.titleSmall),
                  const Gap.xs(),
                  // Selectable, because the point of showing an account number
                  // is that somebody can copy it into their banking app.
                  SelectableText(
                    account.accountNumber,
                    style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  Text(account.accountName, style: theme.textTheme.bodyMedium),
                  if (account.instructions != null) ...<Widget>[
                    const Gap.sm(),
                    Text(account.instructions!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          Text(
            'Send the money to the account above by whatever means you normally use, then record '
            'it below. No money passes through this website — this is a shared record so you and '
            'the treasurer are looking at the same list.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Gap.lg(),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.groupDues(group.slug)),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Record a payment, or see mine'),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}
