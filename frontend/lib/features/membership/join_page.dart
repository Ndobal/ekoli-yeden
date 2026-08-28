import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/member.dart';
import '../../repositories/member_repository.dart';
import '../../services/auth/auth_controller.dart';

/// JOIN THE YAKOLI COMMUNITY.
///
/// The front door. It has two jobs and they pull in opposite directions: it has
/// to explain what membership is for, and it has to not be a wall of form.
///
/// So the page explains, and joining itself asks for one thing — your name. The
/// profile is filled in afterwards, in stages, from the account dashboard.
/// Somebody who joins and stops has still joined; somebody faced with forty
/// fields at the door mostly does not come in.
class JoinPage extends StatelessWidget {
  const JoinPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.join,
      seo: const SeoMetadata(
        title: 'Join the Yakoli community',
        description:
            'One account for the whole of Ekoli Yeden — the community forums, opportunities meant '
            'for Ekoli-Yeden people, and a directory that lets others find what you can do.',
        canonicalPath: AppRoutes.join,
      ),
      child: Column(
        children: <Widget>[
          const _JoinBanner(),
          PageSection(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = context.screenWidth < Breakpoints.tablet;
                const Widget what = _WhatMembershipIs();
                final Widget action = _JoinAction(auth: auth);

                return stacked
                    ? Column(children: <Widget>[what, const Gap.xxl(), action])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Expanded(flex: 3, child: what),
                          const SizedBox(width: AppSpacing.xxl),
                          Expanded(flex: 2, child: action),
                        ],
                      );
              },
            ),
          ),
          PageSection(
            background: theme.colorScheme.surfaceContainerHigh,
            title: 'What we do with what you tell us',
            child: const _PrivacyPromise(),
          ),
        ],
      ),
    );
  }
}

class _JoinBanner extends StatelessWidget {
  const _JoinBanner();

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
        vertical: context.isMobile ? AppSpacing.xxxl : AppSpacing.huge,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'YAKOLI MEMBERSHIP',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.goldLight,
                letterSpacing: 2,
              ),
            ),
            const Gap.md(),
            CmsText(
              'page.join.title',
              fallback: 'Join the Yakoli community',
              style: (context.isMobile
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.displayMedium)
                  ?.copyWith(color: Colors.white),
            ),
            const Gap.lg(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: CmsText(
                'page.join.intro',
                fallback:
                    'One account for the whole of Ekoli Yeden. Registering makes you a member — '
                    'there is no second form and no separate contributor account. Being a member '
                    'means you can send material to the archive, write to other members, take '
                    'part in the forums, see opportunities meant for Ekoli-Yeden people, and be '
                    'found by others who need what you can do — if you choose to be. You decide '
                    'what appears on your profile, and nothing sensitive is shown by default.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What one account actually gets you.
class _WhatMembershipIs extends StatelessWidget {
  const _WhatMembershipIs();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({IconData icon, String title, String detail})> parts =
        <({IconData icon, String title, String detail})>[
      (
        icon: Icons.forum_outlined,
        title: 'The community forums',
        detail: 'General discussion, and dedicated spaces for young people and for students. '
            'Moderated, and permanent — a conversation here does not scroll away.'
      ),
      (
        icon: Icons.work_outline,
        title: 'Opportunities',
        detail: 'Jobs, scholarships, internships, training and contracts, shown nearest first and '
            'matched against what you can actually do.'
      ),
      (
        icon: Icons.groups_outlined,
        title: 'The Yakoli directory',
        detail: 'Other members can find you by profession, skill or where you are — but only if '
            'you turn it on, and you can turn it off again at any time.'
      ),
      (
        icon: Icons.badge_outlined,
        title: 'One account, everywhere',
        detail: 'The same sign-in for all of it, and for contributing to the archive. Nothing '
            'here asks you to register a second time.'
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('What membership is', style: theme.textTheme.headlineSmall),
        const Gap.xl(),
        ...parts.map(
          (({IconData icon, String title, String detail}) part) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.10),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(part.icon, size: 20, color: AppColors.greenDark),
                ),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(part.title, style: theme.textTheme.titleMedium),
                      const Gap.xs(),
                      Text(part.detail, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The panel that actually joins, which changes shape depending on who is
/// looking at it: signed out, signed in but not a member, or already a member.
class _JoinAction extends StatefulWidget {
  const _JoinAction({required this.auth});

  final AuthController auth;

  @override
  State<_JoinAction> createState() => _JoinActionState();
}

class _JoinActionState extends State<_JoinAction> {
  final TextEditingController _name = TextEditingController();
  bool _joining = false;
  String? _error;
  bool _initialised = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final ({String handle, String membershipNumber, String status, String message}) result =
          await context.read<MemberRepository>().join(
                fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
              );
      if (!mounted) return;
      // Straight to the account, with the profile waiting to be filled in.
      // Landing somewhere with a next step is the difference between joining
      // and joining and then doing something.
      context.go('${AppRoutes.account}?joined=${Uri.encodeQueryComponent(result.membershipNumber)}');
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!widget.auth.isSignedIn) return const _SignInFirst();

    if (!_initialised) {
      _initialised = true;
      _name.text = widget.auth.user?.displayName ?? '';
    }

    return AsyncContent<MemberProfile?>(
      // A member who is already in sees their membership rather than a form
      // that would fail. `NotFoundException` is the expected answer for
      // somebody who has not joined, not an error worth showing.
      load: () async {
        try {
          return await context.read<MemberRepository>().me();
        } on NotFoundException {
          return null;
        }
      },
      loadingMessage: 'Checking…',
      builder: (BuildContext context, MemberProfile? existing) {
        if (existing != null) return _AlreadyAMember(profile: existing);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Become a member', style: theme.textTheme.titleLarge),
              const Gap.sm(),
              Text(
                'One question now. Everything else — what you do, where you are, what you can '
                'offer — you fill in afterwards, a little at a time.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap.xl(),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  helperText: 'As you would like it to appear.',
                ),
              ),
              if (_error != null) ...<Widget>[
                const Gap.lg(),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const Gap.xl(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _joining ? null : _join,
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Join the Yakoli community'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SignInFirst extends StatelessWidget {
  const _SignInFirst();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('You need an account first', style: theme.textTheme.titleLarge),
          const Gap.sm(),
          Text(
            'Membership uses the same account as everything else here. If you already have one — '
            'because you have contributed to the archive, or you help run an age grade page — '
            'sign in and join with it rather than making a second.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.xl(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.join)),
              child: const Text('Sign in'),
            ),
          ),
          const Gap.md(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.register),
              child: const Text('Create an account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyAMember extends StatelessWidget {
  const _AlreadyAMember({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 28, color: AppColors.green),
          const Gap.md(),
          Text('You are already a member', style: theme.textTheme.titleLarge),
          const Gap.sm(),
          Text('Membership number ${profile.membershipNumber}', style: theme.textTheme.bodyMedium),
          if (profile.completionPercent < 80) ...<Widget>[
            const Gap.md(),
            Text(
              'Your profile is ${profile.completionPercent}% filled in. The rest is what lets '
              'opportunities and other members find you.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const Gap.xl(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go(AppRoutes.account),
              child: const Text('Go to your account'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The privacy promise, in the server's own words where it has them.
///
/// On the way in rather than buried in a settings page afterwards: somebody
/// handing over their phone number deserves to read this before they do.
class _PrivacyPromise extends StatelessWidget {
  const _PrivacyPromise();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AsyncContent<MembershipOptions>(
      load: context.read<MemberRepository>().options,
      builder: (BuildContext context, MembershipOptions options) {
        final List<String> promises = options.privacyPromise.isEmpty
            ? const <String>[
                'Your phone number and email are hidden unless you turn them on.',
                'Your work situation is never shown publicly by default.',
                'The platform does not label anybody unemployed, anywhere, to anyone.',
                'You are not in the directory unless you choose to be.',
              ]
            : options.privacyPromise;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: CmsText(
                'page.join.privacy_note',
                fallback:
                    'Your phone number, your email and your work situation are never shown '
                    'publicly unless you turn them on. The platform does not label anybody '
                    'unemployed, anywhere, to anyone.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const Gap.xl(),
            ...promises.map(
              (String promise) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.lock_outline, size: 16, color: AppColors.greenDark),
                    const Gap.hMd(),
                    Expanded(child: Text(promise, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
