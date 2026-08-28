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
import '../../models/member.dart';
import '../../models/community_group.dart';
import 'dashboard_sections.dart';
import 'memorial_notice.dart';
import '../../repositories/group_repository.dart';
import '../../repositories/member_repository.dart';
import '../../services/auth/auth_controller.dart';

/// THE OKOLI ACCOUNT.
///
/// One account for the whole platform, and this is where a member sees it: the
/// profile, what is still worth filling in, and the notifications every other
/// module raises.
///
/// It deliberately opens on *what to do next* rather than on a summary of what
/// is already there. A member who has just joined has an almost-empty profile,
/// and the useful thing to show them is the one field that would make the
/// opportunities board start working.
class AccountPage extends StatefulWidget {
  const AccountPage({this.justJoinedNumber, super.key});

  /// Set when arriving straight from the joining form, so the page can
  /// acknowledge it rather than looking like any other visit.
  final String? justJoinedNumber;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _reloads = 0;

  void _reload() => setState(() => _reloads += 1);

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final MemberRepository repository = context.read<MemberRepository>();

    return AppScaffold(
      currentPath: AppRoutes.account,
      seo: const SeoMetadata(
        title: 'Your account',
        description: 'Your Okoli account.',
        canonicalPath: AppRoutes.account,
        noIndex: true,
      ),
      child: !auth.isSignedIn
          ? const _SignedOut()
          : AsyncContent<MemberDashboard?>(
              key: ValueKey<int>(_reloads),
              // Somebody with an account who has not joined is not an error —
              // it is an editor, or a contributor, and the page offers them
              // membership rather than showing them a failure.
              load: () async {
                try {
                  return await repository.dashboard();
                } on NotFoundException {
                  return null;
                }
              },
              loadingMessage: 'Opening your account…',
              builder: (BuildContext context, MemberDashboard? dashboard) {
                if (dashboard == null) return const _NotAMemberYet();
                return _Account(
                  dashboard: dashboard,
                  justJoinedNumber: widget.justJoinedNumber,
                  onChanged: _reload,
                );
              },
            ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return PageSection(
      eyebrow: 'Your account',
      title: 'Sign in',
      description: 'Your Okoli account is the same one you use everywhere else on this site.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FilledButton(
            onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.account)),
            child: const Text('Sign in'),
          ),
          const Gap.md(),
          TextButton(
            onPressed: () => context.go(AppRoutes.join),
            child: const Text('Or learn about Yakoli membership'),
          ),
        ],
      ),
    );
  }
}

class _NotAMemberYet extends StatelessWidget {
  const _NotAMemberYet();

  @override
  Widget build(BuildContext context) {
    return PageSection(
      eyebrow: 'Your account',
      title: 'You have an account, but not a membership',
      description:
          'The two are separate on purpose. Your account is how you sign in; a Yakoli membership '
          'is what opens the community forums, the opportunities board and the directory.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.join),
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: const Text('Join the Yakoli community'),
          ),
        ],
      ),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.dashboard, required this.onChanged, this.justJoinedNumber});

  final MemberDashboard dashboard;
  final VoidCallback onChanged;
  final String? justJoinedNumber;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MemberProfile profile = dashboard.profile;

    return Column(
      children: <Widget>[
        _AccountHeader(profile: profile, justJoinedNumber: justJoinedNumber),

        // Above everything, and before anything else on the page can be read.
        // An account recorded as belonging to somebody who has died must learn
        // of it the moment its holder signs in — see `MemorialNoticeBanner`.
        const MemorialNoticeBanner(),

        PageSection(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = context.screenWidth < Breakpoints.laptop;

              // THE ORDER OF THIS COLUMN IS THE ARGUMENT.
              //
              // A dashboard is a claim about what matters. This one puts, in
              // order: how far through your profile you are and what it would
              // unlock, work that suits you, the groups you belong to, then
              // everything else you can reach, and only then your profile
              // details — which are what you came here to EDIT rather than
              // what you came here to SEE.
              final Widget main = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ProfileCompletionCard(
                    profile: profile,
                    suggestions: dashboard.suggestions,
                  ),
                  const Gap.xxl(),
                  const DashboardOpportunities(),
                  const Gap.xxl(),
                  const _MyGroups(),
                  const Gap.xxl(),
                  MemberToolGrid(handle: profile.handle),
                  const Gap.xxl(),
                  _ProfileSummary(profile: profile),
                ],
              );

              final Widget side = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _NotificationPanel(
                    notifications: dashboard.notifications,
                    unread: dashboard.unreadCount,
                    onChanged: onChanged,
                  ),
                  const Gap.xl(),
                  const _AccountLinks(),
                ],
              );

              return stacked
                  ? Column(children: <Widget>[main, const Gap.xxl(), side])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: main),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(flex: 2, child: side),
                      ],
                    );
            },
          ),
        ),

        PageSection(
          background: theme.colorScheme.surfaceContainerHigh,
          title: 'Who can see what',
          description:
              'Nothing sensitive is shown unless you turn it on. You can change any of this at any '
              'time, and turning something off takes effect immediately.',
          child: _PrivacySummary(profile: profile),
        ),
      ],
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.profile, this.justJoinedNumber});

  final MemberProfile profile;
  final String? justJoinedNumber;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navy, AppColors.greenDark],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? AppSpacing.xxl : AppSpacing.xxxl,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (justJoinedNumber != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline, color: AppColors.goldLight, size: 20),
                    const Gap.hMd(),
                    Expanded(
                      child: Text(
                        'Welcome to the Yakoli community. Your membership number is '
                        '$justJoinedNumber.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap.xl(),
            ],
            Row(
              children: <Widget>[
                _Avatar(profile: profile, size: context.isMobile ? 56 : 72),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.name,
                        style: (context.isMobile
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(color: Colors.white),
                      ),
                      if (profile.summaryLine != null) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          profile.summaryLine!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.goldLight),
                        ),
                      ],
                      const Gap.sm(),
                      Text(
                        'Member ${profile.membershipNumber}'
                        '${profile.joinedAt == null ? '' : ' · joined ${Formatters.monthYear(profile.joinedAt)}'}',
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.isPending) ...<Widget>[
              const Gap.lg(),
              Text(
                'Your membership is waiting to be confirmed. You can fill in your profile now — it '
                'appears as soon as the Preservation Team confirms you.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.goldLight),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, this.size = 48});

  final MemberProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (profile.avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          profile.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: profile.name,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
              _InitialsAvatar(initials: profile.initials, size: size),
        ),
      );
    }
    return _InitialsAvatar(initials: profile.initials, size: size);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: size * 0.36,
            ),
      ),
    );
  }
}

/// What is still worth filling in, and why.
///
/// Phrased as the thing it unlocks rather than as a scolding. A member who has
/// not added a skill is not doing anything wrong; they simply will not be
/// matched to anything yet, and saying that plainly is more use than a
/// progress bar.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Your profile', style: theme.textTheme.titleLarge)),
              TextButton(
                onPressed: () => context.go(AppRoutes.memberProfile(profile.handle)),
                child: const Text('View as others see it'),
              ),
            ],
          ),
          const Gap.lg(),
          _Row(label: 'Name', value: profile.fullName),
          _Row(label: 'What you do', value: profile.professionLabel),
          _Row(label: 'Where', value: profile.locationLabel),
          _Row(
            label: 'Work situation',
            value: profile.workGroupLabel,
            // Said once, here, to the only person it belongs to.
            note: 'Only you and the platform administrators see this.',
          ),
          if (profile.yearsExperience != null)
            _Row(label: 'Experience', value: '${profile.yearsExperience} years'),
          const Gap.lg(),
          Text('Skills', style: theme.textTheme.titleSmall),
          const Gap.sm(),
          if (profile.skills.isEmpty)
            Text(
              'None yet. Skills are what opportunities are matched against.',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: profile.skills
                  .map(
                    (MemberSkill skill) => Chip(
                      label: Text(
                        skill.hasProficiency
                            ? '${skill.name} · ${skill.proficiencyLabel}'
                            : skill.name,
                      ),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          if (profile.interests.isNotEmpty) ...<Widget>[
            const Gap.lg(),
            Text('Interested in', style: theme.textTheme.titleSmall),
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: profile.interests
                  .map(
                    (MemberInterest interest) => Chip(
                      label: Text(interest.name),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.note});

  final String label;
  final String? value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value ?? 'Not said',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: value == null ? FontStyle.italic : FontStyle.normal,
                    color: value == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (note != null && value != null) ...<Widget>[
                  const Gap.xs(),
                  Text(note!, style: theme.textTheme.labelSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.notifications,
    required this.unread,
    required this.onChanged,
  });

  final List<MemberNotification> notifications;
  final int unread;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Notifications', style: theme.textTheme.titleMedium)),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    '$unread',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
            ],
          ),
          const Gap.lg(),
          if (notifications.isEmpty)
            Text(
              'Nothing yet. This is where the community forums and the opportunities board will '
              'reach you.',
              style: theme.textTheme.bodySmall,
            )
          else ...<Widget>[
            ...notifications.map(
              (MemberNotification note) => _NotificationRow(note: note, onChanged: onChanged),
            ),
            const Gap.md(),
            Row(
              children: <Widget>[
                if (unread > 0)
                  TextButton(
                    onPressed: () async {
                      await context.read<MemberRepository>().markAllRead();
                      onChanged();
                    },
                    child: const Text('Mark all read'),
                  ),
                const Spacer(),
                // This panel holds the most recent few. Somebody who was away
                // for a week has already scrolled past whatever was said to
                // them, and this is where the rest of it is.
                TextButton(
                  onPressed: () => context.go(AppRoutes.accountNotifications),
                  child: const Text('See all'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.note, required this.onChanged});

  final MemberNotification note;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        if (note.isUnread) {
          await context.read<MemberRepository>().markRead(note.id);
          onChanged();
        }
        if (note.linkPath != null && context.mounted) context.go(note.linkPath!);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: note.isUnread ? AppColors.gold : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const Gap.hMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    note.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: note.isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (note.body != null) ...<Widget>[
                    const Gap.xs(),
                    Text(note.body!, style: theme.textTheme.bodySmall),
                  ],
                  const Gap.xs(),
                  Text(Formatters.relative(note.createdAt), style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rest of the account, as a list rather than a navigation bar.
///
/// Everything here is one account: contributions to the archive and Yakoli
/// membership are the same sign-in, and putting them in one list is how that
/// gets communicated without a paragraph explaining it.
class _AccountLinks extends StatelessWidget {
  const _AccountLinks();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({IconData icon, String label, String path, String detail})> links =
        <({IconData icon, String label, String path, String detail})>[
      (
        icon: Icons.person_outline,
        label: 'My profile',
        path: AppRoutes.accountProfile,
        detail: 'Name, what you do, where you are'
      ),
      (
        icon: Icons.notifications_none,
        label: 'Notifications',
        path: AppRoutes.accountNotifications,
        detail: 'Everything the archive has told you, kept'
      ),
      (
        icon: Icons.lock_outline,
        label: 'Privacy',
        path: AppRoutes.accountPrivacy,
        detail: 'Who sees what, and whether you are in the directory'
      ),
      (
        icon: Icons.groups_outlined,
        label: 'My age grades',
        path: AppRoutes.myAgeGrades,
        detail: 'Pages you help keep'
      ),
      (
        icon: Icons.upload_file_outlined,
        label: 'Contribute to the archive',
        path: AppRoutes.contribute,
        detail: 'Photographs, documents, stories'
      ),
      (
        icon: Icons.translate_outlined,
        label: 'Contribute a word',
        path: AppRoutes.contributeWord,
        detail: 'Add to the dictionary'
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: links
            .map(
              (({IconData icon, String label, String path, String detail}) link) => ListTile(
                leading: Icon(link.icon, size: 20),
                title: Text(link.label, style: theme.textTheme.bodyLarge),
                subtitle: Text(link.detail, style: theme.textTheme.bodySmall),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.go(link.path),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PrivacySummary extends StatelessWidget {
  const _PrivacySummary({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<({String label, bool on, String onText, String offText})> rows =
        <({String label, bool on, String onText, String offText})>[
      (
        label: 'Your profile',
        on: profile.profileVisibility == 'public',
        onText: 'Visible to anybody',
        offText: profile.profileVisibility == 'members'
            ? 'Visible to Yakoli members only'
            : 'Visible only to you',
      ),
      (
        label: 'Phone and email',
        on: profile.showContact,
        onText: 'Shown on your profile',
        offText: 'Hidden',
      ),
      (
        label: 'Work situation',
        on: profile.showEmployment,
        onText: 'Shown — except where it would say you are out of work, which is never shown',
        offText: 'Hidden',
      ),
      (
        label: 'In the Yakoli directory',
        on: profile.listedInDirectory,
        onText: 'Other members can find you by what you do',
        offText: 'You cannot be found by profession or skill',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...rows.map(
          (({String label, bool on, String onText, String offText}) row) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  row.on ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: row.on ? AppColors.gold : theme.colorScheme.onSurfaceVariant,
                ),
                const Gap.hMd(),
                SizedBox(
                  width: 170,
                  child: Text(row.label, style: theme.textTheme.labelMedium),
                ),
                Expanded(
                  child: Text(
                    row.on ? row.onText : row.offText,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap.lg(),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.accountPrivacy),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Change these'),
        ),
      ],
    );
  }
}


/// WHICH AGE GRADE IS MINE?
///
/// Every member is told, on their own dashboard, which age grades their year of
/// birth places them in — and can join one in a single press.
///
/// This exists because the alternative does not work. An age grade is one of
/// the structures Ekoli-Yeden actually organises itself by, and expecting
/// somebody to find the groups section, work out which bracket contains their
/// birth year, and join, is expecting a great deal for something the archive
/// can simply work out and offer.
///
/// Where it cannot, it says why. "We do not know when you were born" is
/// actionable in a way that an empty box is not.
class _MyGroups extends StatelessWidget {
  const _MyGroups();

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<GroupSuggestions>(
      load: repository.suggestions,
      // A dashboard should not shout about a section that has nothing in it.
      isEmpty: (GroupSuggestions data) => data.isEmpty,
      emptyBuilder: (BuildContext context) => const SizedBox.shrink(),
      builder: (BuildContext context, GroupSuggestions data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Your groups', style: theme.textTheme.titleMedium),
            const Gap.md(),

            if (data.mine.isNotEmpty) ...<Widget>[
              ...data.mine.map(
                (CommunityGroup group) => _GroupRow(group: group, joined: true),
              ),
              const Gap.lg(),
            ],

            // The prompt, where the archive cannot work the answer out.
            if (data.needsBirthDate)
              _Prompt(
                icon: Icons.cake_outlined,
                message: data.prompt ??
                    'Add your date of birth and we can tell you which age grade is yours.',
                actionLabel: 'Add it',
                onPressed: () => context.go(AppRoutes.accountProfile),
              ),

            if (data.suggested.isNotEmpty) ...<Widget>[
              Text(
                data.suggested.length == 1
                    ? 'One age grade matches your year of birth'
                    : '${data.suggested.length} age grades match your year of birth',
                style: theme.textTheme.titleSmall,
              ),
              const Gap.sm(),
              ...data.suggested.map(
                (CommunityGroup group) => _GroupRow(group: group, joined: false),
              ),
            ],

            if (data.mine.isEmpty && data.suggested.isEmpty && !data.needsBirthDate)
              Text(
                'You do not belong to any group yet, and no age grade covers your year of birth. '
                'If yours has not registered, you can register it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

            const Gap.md(),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.groups),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('All groups and age grades'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        );
      },
    );
  }
}

class _GroupRow extends StatefulWidget {
  const _GroupRow({required this.group, required this.joined});

  final CommunityGroup group;
  final bool joined;

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _busy = false;
  String? _message;
  bool _isError = false;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ({String state, String message}) result =
          await context.read<GroupRepository>().join(widget.group.id);
      if (mounted) {
        setState(() {
          _message = result.message;
          _isError = false;
        });
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CommunityGroup group = widget.group;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    InkWell(
                      onTap: () => context.go(AppRoutes.group(group.slug)),
                      child: Text(group.title, style: theme.textTheme.titleSmall),
                    ),
                    // Why it is being suggested. A suggestion without a reason
                    // reads as an advertisement.
                    if (group.reason != null)
                      Text(group.reason!, style: theme.textTheme.bodySmall)
                    else if (group.bracketLabel != null)
                      Text(group.bracketLabel!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              if (widget.joined)
                Text(
                  group.membershipState == 'requested' ? 'Asked' : 'Member',
                  style: theme.textTheme.labelSmall,
                )
              else if (_message == null)
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: Text(group.joinPolicy == 'by_request' ? 'Ask to join' : 'Join'),
                ),
            ],
          ),
          if (_message != null) ...<Widget>[
            const Gap.sm(),
            Text(
              _message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _isError ? theme.colorScheme.error : AppColors.greenDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.warning),
          const Gap.hMd(),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
