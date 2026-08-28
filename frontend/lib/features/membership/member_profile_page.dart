import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import '../../repositories/member_repository.dart';
import '../../services/auth/auth_controller.dart';

/// ONE MEMBER'S PUBLIC PAGE.
///
/// What arrives here has already been shaped by the server to what the viewer
/// is allowed to see. This page does not decide anything about visibility — it
/// renders what it was given, and a field that is absent is simply not drawn.
///
/// That is deliberate. Putting the privacy rules in one place on the server
/// means a change to this page cannot leak a phone number, and a new page
/// cannot forget a check.
class MemberProfilePage extends StatelessWidget {
  const MemberProfilePage({required this.handle, super.key});

  final String handle;

  @override
  Widget build(BuildContext context) {
    final MemberRepository repository = context.read<MemberRepository>();
    final AuthController auth = context.watch<AuthController>();

    // One member looking at another. A profile lives inside the directory, and
    // the directory is for members — the server refuses this to a signed-out
    // caller, and the page says so rather than showing an error.
    if (!auth.isSignedIn) return const _MembersOnlyProfile();

    return AsyncContent<MemberProfile>(
      load: () => repository.member(handle),
      loadingMessage: 'Opening the profile…',
      builder: (BuildContext context, MemberProfile profile) {
        final bool isSelf = auth.user?.id == profile.userId;

        return AppScaffold(
          currentPath: AppRoutes.directory,
          seo: SeoMetadata(
            title: profile.name,
            description: profile.headline ?? profile.summaryLine,
            canonicalPath: AppRoutes.memberProfile(profile.handle),
            type: 'profile',
            // Never indexed. A member page is reachable only by somebody signed
            // in, and a page about a real person should not be a search result
            // for their name whatever their visibility setting says.
            noIndex: true,
          ),
          child: Column(
            children: <Widget>[
              _ProfileHeader(profile: profile, isSelf: isSelf),
              PageSection(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = context.screenWidth < Breakpoints.laptop;
                    final Widget main = _MainColumn(profile: profile);
                    final Widget side = _SideColumn(profile: profile);

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
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.isSelf});

  final MemberProfile profile;
  final bool isSelf;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Avatar(profile: profile, size: context.isMobile ? 64 : 88),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.name,
                        style: (context.isMobile
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.headlineLarge)
                            ?.copyWith(color: Colors.white),
                      ),
                      if (profile.headline != null) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          profile.headline!,
                          style:
                              theme.textTheme.titleMedium?.copyWith(color: AppColors.goldLight),
                        ),
                      ],
                      const Gap.md(),
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          if (profile.professionLabel != null)
                            _Fact(icon: Icons.work_outline, text: profile.professionLabel!),
                          if (profile.locationLabel != null)
                            _Fact(icon: Icons.place_outlined, text: profile.locationLabel!),
                          if (profile.joinedAt != null)
                            _Fact(
                              icon: Icons.event_outlined,
                              text: 'Member since ${Formatters.monthYear(profile.joinedAt)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelf) ...<Widget>[
              const Gap.xl(),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.accountProfile),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                    label: const Text('Edit', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                  const Gap.hMd(),
                  Text(
                    'This is how others see your page.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (profile.bio != null) ...<Widget>[
          Text('About', style: theme.textTheme.titleLarge),
          const Gap.md(),
          SelectableText(profile.bio!, style: theme.textTheme.bodyLarge),
          const Gap.xxl(),
        ],

        if (profile.skills.isNotEmpty) ...<Widget>[
          Text('What they can do', style: theme.textTheme.titleLarge),
          const Gap.xs(),
          Text(
            'Self-described, as everything on a profile is.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.md(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: profile.skills
                .map(
                  (MemberSkill skill) => Chip(
                    label: Text(
                      skill.hasProficiency ? '${skill.name} · ${skill.proficiencyLabel}' : skill.name,
                    ),
                    labelStyle: theme.textTheme.labelMedium,
                  ),
                )
                .toList(growable: false),
          ),
          const Gap.xxl(),
        ],

        if (profile.interests.isNotEmpty) ...<Widget>[
          Text('Interested in', style: theme.textTheme.titleLarge),
          const Gap.md(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: profile.interests
                .map(
                  (MemberInterest interest) => Chip(
                    label: Text(interest.name),
                    labelStyle: theme.textTheme.labelMedium,
                  ),
                )
                .toList(growable: false),
          ),
        ],

        if (profile.bio == null && profile.skills.isEmpty && profile.interests.isEmpty)
          Text(
            'This member has not filled in their profile yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<({String label, String value})> details = <({String label, String value})>[
      if (profile.professionLabel != null)
        (label: 'Profession', value: profile.professionLabel!),
      if (profile.industry != null) (label: 'Industry', value: profile.industry!),
      if (profile.yearsExperience != null)
        (label: 'Experience', value: '${profile.yearsExperience} years'),
      if (profile.employer != null) (label: 'Works at', value: profile.employer!),
      if (profile.educationLevel != null)
        (label: 'Education', value: _educationLabel(profile.educationLevel!)),
      if (profile.educationField != null) (label: 'Studied', value: profile.educationField!),
      if (profile.institution != null) (label: 'At', value: profile.institution!),
      if (profile.connection != null)
        (label: 'Connection', value: _connectionLabel(profile.connection!)),
      if (profile.locationLabel != null) (label: 'Where', value: profile.locationLabel!),
      if (profile.phone != null) (label: 'Phone', value: profile.phone!),
      if (profile.whatsappNumber != null) (label: 'WhatsApp', value: profile.whatsappNumber!),
      if (profile.email != null) (label: 'Email', value: profile.email!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
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
              Text('Details', style: theme.textTheme.titleMedium),
              const Gap.lg(),
              if (details.isEmpty)
                Text(
                  'Nothing shared publicly.',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                )
              else
                ...details.map(
                  (({String label, String value}) detail) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 110,
                          child: Text(detail.label, style: theme.textTheme.labelMedium),
                        ),
                        Expanded(
                          child: SelectableText(detail.value, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              if (profile.openToOpportunities) ...<Widget>[
                const Gap.lg(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.mark_email_read_outlined,
                          size: 16, color: AppColors.greenDark),
                      const Gap.hMd(),
                      Expanded(
                        child: Text(
                          'Open to hearing about opportunities',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Gap.lg(),
        Text(
          'Member ${profile.membershipNumber}',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }

  static String _educationLabel(String level) {
    const Map<String, String> labels = <String, String>{
      'primary': 'Primary',
      'secondary': 'Secondary',
      'vocational': 'Vocational or trade training',
      'diploma': 'Diploma or certificate',
      'bachelors': "Bachelor's degree",
      'masters': "Master's degree",
      'doctorate': 'Doctorate',
      'other': 'Other',
    };
    return labels[level] ?? level;
  }

  static String _connectionLabel(String connection) {
    const Map<String, String> labels = <String, String>{
      'born_here': 'Born in Ekoli-Yeden',
      'family_from_here': 'Family from Ekoli-Yeden',
      'married_into': 'Married into Ekoli-Yeden',
      'resident': 'Lives in Ekoli-Yeden',
      'descendant': 'A descendant of Ekoli-Yeden',
      'returned': 'Returned to Ekoli-Yeden',
      'researcher': 'Researcher or scholar',
      'friend': 'Friend of the community',
      'other': 'Other',
    };
    return labels[connection] ?? connection;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, this.size = 64});

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
              _Initials(text: profile.initials, size: size),
        ),
      );
    }
    return _Initials(text: profile.initials, size: size);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontSize: size * 0.36,
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: Colors.white70),
        const Gap.hSm(),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// A profile is inside the directory, and the directory is for members.
class _MembersOnlyProfile extends StatelessWidget {
  const _MembersOnlyProfile();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentPath: AppRoutes.directory,
      seo: const SeoMetadata(title: 'Member profile', noIndex: true),
      child: PageSection(
        reading: true,
        eyebrow: 'Yakoli',
        title: 'This page is for members',
        description:
            'Member profiles are part of the community directory. Sign in to see it, or join — '
            'it takes a minute, and nothing about you appears anywhere unless you switch it on.',
        child: Row(
          children: <Widget>[
            FilledButton(
              onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.directory)),
              child: const Text('Sign in'),
            ),
            const Gap.hLg(),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.join),
              child: const Text('Become a member'),
            ),
          ],
        ),
      ),
    );
  }
}
