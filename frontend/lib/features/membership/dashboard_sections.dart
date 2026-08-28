import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../models/member.dart';
import '../../models/opportunity.dart';
import '../../repositories/opportunity_repository.dart';
import '../../services/api/api_response.dart';
import '../opportunities/opportunities_pages.dart' show OpportunityCard;

/// THE PIECES OF THE MEMBER DASHBOARD.
///
/// A member's dashboard is meant to be the one place they need. Everything they
/// can do on this platform reaches them here — their profile, their groups,
/// work that suits them, their family, and what needs their attention — rather
/// than being scattered across a navigation bar they have to learn.
///
/// The sections live in this file so `account_page.dart` stays a layout rather
/// than a two-thousand-line screen.

// ---------------------------------------------------------------------------
// How complete is my profile?
// ---------------------------------------------------------------------------

/// HOW FAR THROUGH THE PROFILE THIS MEMBER IS.
///
/// Shown as a percentage with the next unanswered thing named beside it, and
/// both are pressable straight into the editor.
///
/// A bare percentage is a scolding. A percentage with "add your skills — that
/// is what opportunities are matched against" is an offer, and it is also true:
/// each of these fields unlocks something specific, and the interface says
/// which rather than implying the member is behind on homework.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({
    required this.profile,
    required this.suggestions,
    super.key,
  });

  final MemberProfile profile;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int percent = profile.completionPercent;
    final bool done = percent >= 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: done
            ? AppColors.success.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _CompletionRing(percent: percent),
              const Gap.hLg(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      done ? 'Your profile is complete' : 'Your profile is $percent% complete',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Gap.xs(),
                    Text(
                      done
                          ? 'Thank you. Everything the platform can do for you is switched on.'
                          : 'Each part you fill in switches something on — being matched to work, '
                              'being findable by other members, being placed in your age grade.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!done) ...<Widget>[
            const Gap.lg(),
            // The next things worth doing, each a press away from the field
            // that fixes it. The server phrases these as what they unlock.
            ...suggestions.take(3).map(
                  (String suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.accountProfile),
                      borderRadius: AppRadius.smAll,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.arrow_forward, size: 15),
                            const Gap.hSm(),
                            Expanded(
                              child: Text(suggestion, style: theme.textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            const Gap.sm(),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.accountProfile),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Continue your profile'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: percent >= 100 ? AppColors.success : AppColors.green,
            ),
          ),
          Text('$percent%', style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Work that suits me
// ---------------------------------------------------------------------------

/// OPPORTUNITIES, ON THE DASHBOARD.
///
/// The few that fit this member best, without them having to go looking. A jobs
/// board somebody has to remember to visit is a jobs board nobody visits, and
/// the whole value of matching is that it can be brought to them.
class DashboardOpportunities extends StatelessWidget {
  const DashboardOpportunities({super.key});

  @override
  Widget build(BuildContext context) {
    final OpportunityRepository repository = context.read<OpportunityRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<PaginatedResult<Opportunity>>(
      load: () => repository.list(perPage: 4),
      // A quiet board is not worth a large empty state on somebody's own
      // dashboard; the section simply does not appear.
      isEmpty: (PaginatedResult<Opportunity> r) => r.isEmpty,
      emptyBuilder: (BuildContext context) => const SizedBox.shrink(),
      builder: (BuildContext context, PaginatedResult<Opportunity> result) {
        final bool matchingOff = !result.items.first.matchingActive;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    matchingOff ? 'Opportunities' : 'Work that suits you',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.opportunities),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text('All ${Formatters.number(result.total)}'),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
            if (matchingOff) ...<Widget>[
              const Gap.xs(),
              Text(
                'Add your skills and these will start ordering themselves around what you can do.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Gap.md(),
            ...result.items.map(
              (Opportunity item) => OpportunityCard(opportunity: item, dense: true),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Everything else a member can reach
// ---------------------------------------------------------------------------

/// THE REST OF THE PLATFORM, FROM ONE PLACE.
///
/// The features a member has but would otherwise have to hunt for in a
/// navigation bar built for visitors reading the archive.
///
/// Membership things live here rather than in the public menu on purpose: the
/// public site is for reading about Ekoli-Yeden, and a visitor has no use for
/// "your family" or "your dues".
class MemberToolGrid extends StatelessWidget {
  const MemberToolGrid({required this.handle, super.key});

  final String? handle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<_Tool> tools = <_Tool>[
      const _Tool(
        icon: Icons.work_outline,
        label: 'Opportunities',
        detail: 'Jobs, scholarships and training matched to you',
        path: AppRoutes.opportunities,
      ),
      const _Tool(
        icon: Icons.groups_outlined,
        label: 'Groups and age grades',
        detail: 'Join yours, pay dues, raise something',
        path: AppRoutes.groups,
      ),
      // The forums (Module 5) have their schema but no code yet, so there is
      // deliberately no tile for them: a dashboard that links to a page which
      // does not exist teaches people not to trust the dashboard.
      const _Tool(
        icon: Icons.contacts_outlined,
        label: 'Member directory',
        detail: 'Find members by what they do and where they are',
        path: AppRoutes.directory,
      ),
      const _Tool(
        icon: Icons.family_restroom_outlined,
        label: 'Your family',
        detail: 'Connect to relatives, and answer who has asked',
        path: AppRoutes.accountFamily,
      ),
      const _Tool(
        icon: Icons.cake_outlined,
        label: 'Birthdays',
        detail: 'Whose birthday it is, and every wish you have received',
        path: AppRoutes.accountBirthdays,
      ),
      const _Tool(
        icon: Icons.upload_file_outlined,
        label: 'Contribute',
        detail: 'Send photographs, recordings and stories to the archive',
        path: AppRoutes.contribute,
      ),
      const _Tool(
        icon: Icons.lock_outline,
        label: 'Privacy',
        detail: 'Choose what other people can see',
        path: AppRoutes.accountPrivacy,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Everything you can do', style: theme.textTheme.titleMedium),
        const Gap.md(),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth > 560 ? 2 : 1;
            final double width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;

            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                ...tools.map(
                  (_Tool tool) => SizedBox(width: width, child: _ToolTile(tool: tool)),
                ),
                if (handle != null)
                  SizedBox(
                    width: width,
                    child: _ToolTile(
                      tool: _Tool(
                        icon: Icons.badge_outlined,
                        label: 'Your public page',
                        detail: 'What other members see when they find you',
                        path: AppRoutes.memberProfile(handle!),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Tool {
  const _Tool({
    required this.icon,
    required this.label,
    required this.detail,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String detail;
  final String path;
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(tool.path),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(tool.icon, size: 18, color: AppColors.greenDark),
              ),
              const Gap.hMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(tool.label, style: theme.textTheme.titleSmall),
                    Text(
                      tool.detail,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
