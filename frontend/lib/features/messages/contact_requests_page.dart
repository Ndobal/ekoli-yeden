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
import '../../models/message.dart';
import '../../repositories/message_repository.dart';
import '../../services/auth/auth_controller.dart';

/// WHO HAS ASKED FOR YOUR DETAILS, AND WHO IS HOLDING THEM.
///
/// ---------------------------------------------------------------------------
/// THE PAGE THAT MAKES THE PROMISE CHECKABLE
/// ---------------------------------------------------------------------------
///
/// The platform tells members that their phone number and email are hidden
/// unless they share them. A promise like that is only worth anything if the
/// person can see, at any moment, exactly who holds what — and take it back in
/// one press without having to remember who was ever given it.
///
/// So this page shows three things and hides none of them: what is waiting on
/// you, what you have asked of other people, and everybody currently holding
/// your details.
///
/// **Approving is deliberately not one button.** Somebody may be willing to
/// give a phone number and not an email, and the approval dialog lets them
/// narrow what was asked for rather than forcing all-or-nothing.
class ContactRequestsPage extends StatefulWidget {
  const ContactRequestsPage({super.key});

  @override
  State<ContactRequestsPage> createState() => _ContactRequestsPageState();
}

class _ContactRequestsPageState extends State<ContactRequestsPage> {
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) => setState(() {
    _reloads += 1;
    _notice = notice;
  });

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final ThemeData theme = Theme.of(context);

    if (!auth.isSignedIn) {
      return AppScaffold(
        currentPath: AppRoutes.account,
        seo: const SeoMetadata(title: 'Requests', noIndex: true),
        child: PageSection(
          reading: true,
          title: 'Sign in to see your requests',
          child: FilledButton(
            onPressed: () =>
                context.go(AppRoutes.signInReturningTo(AppRoutes.accountRequests)),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    return AppScaffold(
      currentPath: AppRoutes.account,
      seo: const SeoMetadata(title: 'Requests for your details', noIndex: true),
      child: PageSection(
        reading: true,
        eyebrow: 'Your account',
        title: 'Your contact details',
        description:
            'Your phone number and email are hidden from other members unless you share them. '
            'This is who has asked, and who is holding them now.',
        action: TextButton.icon(
          onPressed: () => context.go(AppRoutes.messages),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Messages'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_notice != null) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.08),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Text(_notice!, style: theme.textTheme.bodyMedium),
              ),
              const Gap.xl(),
            ],
            AsyncContent<ContactRequestInbox>(
              key: ValueKey<int>(_reloads),
              load: () => context.read<MessageRepository>().contactRequests(),
              loadingMessage: 'Opening your requests…',
              builder: (BuildContext context, ContactRequestInbox inbox) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // --- Waiting on you --------------------------------------
                  Text('Waiting on you', style: theme.textTheme.titleMedium),
                  const Gap.sm(),
                  if (inbox.incoming.isEmpty)
                    Text(
                      'Nobody has asked for your details.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...inbox.incoming.map(
                      (ContactRequest request) =>
                          _IncomingCard(request: request, onDecided: _reload),
                    ),

                  const Gap.section(),

                  // --- Who is holding your details -------------------------
                  Text('Who has your details', style: theme.textTheme.titleMedium),
                  const Gap.sm(),
                  Text(
                    'Taking it back works immediately. They are not told, and they keep no copy '
                    'in this platform.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap.lg(),
                  if (inbox.granted.isEmpty)
                    Text(
                      'Nobody. Your number and email are hidden from every other member.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...inbox.granted.map(
                      (ContactGrant grant) => _GrantCard(grant: grant, onRevoked: _reload),
                    ),

                  const Gap.section(),

                  // --- What you have asked ---------------------------------
                  Text('What you have asked for', style: theme.textTheme.titleMedium),
                  const Gap.lg(),
                  if (inbox.outgoing.isEmpty)
                    Text(
                      'You have not asked anybody for their details.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...inbox.outgoing.map((ContactRequest request) => _OutgoingRow(request: request)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Somebody asking you.
class _IncomingCard extends StatelessWidget {
  const _IncomingCard({required this.request, required this.onDecided});

  final ContactRequest request;
  final ValueChanged<String> onDecided;

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
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${request.name} has asked for ${request.askLabel}',
              style: theme.textTheme.titleSmall,
            ),
            if (request.headline != null) ...<Widget>[
              const Gap.xs(),
              Text(
                request.headline!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Gap.lg(),

            // Their reason, in their words, which is the thing being decided
            // on. Shown in a quote rather than paraphrased.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                request.reason ?? 'They did not say why.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: request.reason == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const Gap.md(),
            Text(
              'Asked ${Formatters.relative(request.createdAt)}. You can say no, and you can '
              'change your mind later either way.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap.lg(),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                FilledButton(
                  onPressed: () => _approve(context),
                  child: const Text('Share with them'),
                ),
                OutlinedButton(
                  onPressed: () => _decide(context, approve: false),
                  child: const Text('No thank you'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Approving narrows rather than accepts wholesale.
  ///
  /// Somebody may be perfectly willing to hand over a phone number and not an
  /// email, and an all-or-nothing button makes them decline the whole thing.
  Future<void> _approve(BuildContext context) async {
    bool sharePhone = request.wantsPhone;
    bool shareEmail = request.wantsEmail;

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => StatefulBuilder(
            builder: (BuildContext inner, StateSetter setInner) => AlertDialog(
              title: Text('Share with ${request.name}'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Choose what they may see. You can take it back at any time.'),
                    const Gap.lg(),
                    if (request.wantsPhone)
                      CheckboxListTile(
                        value: sharePhone,
                        onChanged: (bool? value) =>
                            setInner(() => sharePhone = value ?? sharePhone),
                        title: const Text('My phone number'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    if (request.wantsEmail)
                      CheckboxListTile(
                        value: shareEmail,
                        onChanged: (bool? value) =>
                            setInner(() => shareEmail = value ?? shareEmail),
                        title: const Text('My email address'),
                        contentPadding: EdgeInsets.zero,
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
                  onPressed: (sharePhone || shareEmail)
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Share'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!go || !context.mounted) return;
    await _decide(context, approve: true, sharePhone: sharePhone, shareEmail: shareEmail);
  }

  Future<void> _decide(
    BuildContext context, {
    required bool approve,
    bool? sharePhone,
    bool? shareEmail,
  }) async {
    try {
      final String message = await context.read<MessageRepository>().decide(
        request.id,
        approve: approve,
        sharePhone: sharePhone,
        shareEmail: shareEmail,
      );
      onDecided(message);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

/// Somebody currently holding your details.
class _GrantCard extends StatelessWidget {
  const _GrantCard({required this.grant, required this.onRevoked});

  final ContactGrant grant;
  final ValueChanged<String> onRevoked;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(grant.name, style: theme.textTheme.titleSmall),
                  const Gap.xs(),
                  Text(
                    'Has ${grant.whatTheyHave} · shared '
                    '${Formatters.relative(grant.grantedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await context.read<MessageRepository>().revoke(grant.viewerId);
                  onRevoked('Taken back. ${grant.name} can no longer see your details.');
                } on AppException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: const Text('Take it back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Something you asked somebody else for.
class _OutgoingRow extends StatelessWidget {
  const _OutgoingRow({required this.request});

  final ContactRequest request;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final ({String label, Color colour}) state = switch (request.state) {
      'approved' => (label: 'They shared it', colour: AppColors.green),
      'declined' => (label: 'They said no', colour: theme.colorScheme.error),
      _ => (label: 'Waiting on them', colour: theme.colorScheme.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(request.name, style: theme.textTheme.bodyMedium)),
          Text(
            state.label,
            style: theme.textTheme.labelMedium?.copyWith(color: state.colour),
          ),
        ],
      ),
    );
  }
}
