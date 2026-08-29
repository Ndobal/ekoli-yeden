/// THE COMMUNITY HUB.
///
/// Three columns: who is here, what has happened, and what the archive holds.
///
/// ---------------------------------------------------------------------------
/// WHY ACTIVITY IS THE MIDDLE COLUMN
/// ---------------------------------------------------------------------------
///
/// A community page whose centre is a description of the community is a
/// brochure. The centre has to be the thing that changed since the reader last
/// looked, or there is no reason to come back — and on an archive that is still
/// filling up, "somebody added four photographs of Leboku" is the most
/// encouraging sentence on the site.
///
/// The counts are on the right rather than the top because they are context,
/// not news. They answer "how much is here" for somebody deciding whether to
/// contribute, which is a different question from "what happened".
library;

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
import '../../models/community_overview.dart';
import '../../repositories/community_repository.dart';
import '../../services/auth/auth_controller.dart';

class CommunityHubPage extends StatelessWidget {
  const CommunityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final CommunityRepository repository = context.read<CommunityRepository>();

    return AppScaffold(
      currentPath: AppRoutes.communityHub,
      seo: const SeoMetadata(
        title: 'The community of Ekoli-Yeden',
        description:
            'Who is here, what has been added lately, and what the archive holds — the people, '
            'groups, age grades and forums of Ekoli-Yeden.',
        canonicalPath: AppRoutes.communityHub,
      ),
      child: PageSection(
        eyebrow: 'Yakoli',
        title: 'The community',
        description:
            'Who is here, what has happened lately, and what the archive holds. Everything on '
            'this page was put there by somebody of Ekoli-Yeden.',
        child: AsyncContent<CommunityOverview>(
          load: repository.overview,
          loadingMessage: 'Opening the community…',
          builder: (BuildContext context, CommunityOverview data) {
            final bool wide = context.screenWidth >= Breakpoints.laptop;

            final Widget left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MembersPanel(members: data.members, total: data.stats.members),
                const Gap.xl(),
                _GroupsPanel(groups: data.groups),
              ],
            );

            final Widget centre = _ActivityPanel(activity: data.activity, stats: data.stats);

            final Widget right = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!context.watch<AuthController>().isSignedIn) ...<Widget>[
                  const _JoinPanel(),
                  const Gap.xl(),
                ],
                _StatsPanel(stats: data.stats),
              ],
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  centre,
                  const Gap.xxl(),
                  left,
                  const Gap.xxl(),
                  right,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 260, child: left),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: centre),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: 260, child: right),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panels
// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                ?action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
        ],
      ),
    );
  }
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.members, required this.total});

  final List<CommunityMember> members;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Panel(
      title: 'Members',
      action: TextButton(
        onPressed: () => context.go(AppRoutes.directory),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('All'),
      ),
      child: members.isEmpty
          ? Text(
              // Only people who chose to be listed appear here, so an empty
              // panel means privacy rather than an empty community.
              total == 0
                  ? 'Nobody has joined yet.'
                  : 'Nobody has chosen to appear in the directory yet.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final CommunityMember member in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.memberProfile(member.handle)),
                      child: Row(
                        children: <Widget>[
                          _Avatar(url: member.avatarUrl, name: member.name, size: 38),
                          const Gap.hMd(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  member.name,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((member.headline ?? member.place ?? '').isNotEmpty)
                                  Text(
                                    member.headline ?? member.place!,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (member.openToMentoring)
                            const Tooltip(
                              message: 'Willing to mentor',
                              child: Icon(
                                Icons.volunteer_activism_outlined,
                                size: 15,
                                color: AppColors.gold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GroupsPanel extends StatelessWidget {
  const _GroupsPanel({required this.groups});

  final List<CommunityGroupCard> groups;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Panel(
      title: 'Groups',
      action: TextButton(
        onPressed: () => context.go(AppRoutes.groups),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('All'),
      ),
      child: groups.isEmpty
          ? Text(
              'No groups recorded yet.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final CommunityGroupCard group in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: InkWell(
                      onTap: () => context.go(
                        group.isAgeGrade
                            ? AppRoutes.ageGrade(group.slug)
                            : AppRoutes.group(group.slug),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: (group.isAgeGrade ? AppColors.green : AppColors.navy)
                                  .withValues(alpha: 0.12),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Icon(
                              group.isAgeGrade ? Icons.groups_2_outlined : Icons.diversity_3_outlined,
                              size: 18,
                              color: group.isAgeGrade ? AppColors.green : AppColors.navy,
                            ),
                          ),
                          const Gap.hMd(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  group.name,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  group.detail ??
                                      (group.memberCount > 0
                                          ? '${group.memberCount} members'
                                          : 'A group of Ekoli-Yeden'),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activity, required this.stats});

  final List<ActivityEntry> activity;
  final CommunityStats stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Panel(
      title: 'Latest activity',
      child: activity.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Nothing has happened yet. The archive fills up as people send in '
                  'photographs, write down what they know, and start conversations.',
                  style: theme.textTheme.bodyMedium,
                ),
                const Gap.lg(),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.contribute),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Be the first'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final ActivityEntry entry in activity)
                  _ActivityRow(entry: entry),

                // The forums, said plainly. An empty forum behind three cards
                // reads as broken; saying it is empty and inviting the first
                // conversation reads as an archive at the beginning.
                if (stats.topics == 0) ...<Widget>[
                  const Gap.lg(),
                  const Divider(),
                  const Gap.md(),
                  Text(
                    'Nobody has started a conversation in the forums yet. Every registered '
                    'member is already in the General Forum — the first one is yours to start.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Gap.md(),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.forums),
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    label: const Text('Open the forums'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  static IconData _iconFor(String kind) => switch (kind) {
    'photograph' => Icons.photo_outlined,
    'conversation' => Icons.forum_outlined,
    'news' => Icons.newspaper_outlined,
    'member' => Icons.person_add_alt,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (entry.imageUrl != null && entry.kind == 'photograph')
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: Image.network(
                entry.imageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _ActivityIcon(kind: entry.kind),
              ),
            )
          else
            _ActivityIcon(kind: entry.kind),
          const Gap.hMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.sentence, style: theme.textTheme.bodyMedium),
                if ((entry.title ?? '').isNotEmpty && entry.kind != 'member') ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    entry.title!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  Formatters.relative(entry.at ?? ''),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
      ),
      child: Icon(_ActivityRow._iconFor(kind), size: 20, color: AppColors.navy),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final CommunityStats stats;

  @override
  Widget build(BuildContext context) {
    final List<(String, int, String)> rows = <(String, int, String)>[
      ('Members', stats.members, AppRoutes.directory),
      ('Photographs', stats.photographs, AppRoutes.gallery),
      ('History entries', stats.history, AppRoutes.history),
      ('People recorded', stats.people, AppRoutes.people),
      ('Recordings', stats.recordings, AppRoutes.voices),
      ('Ekoli words', stats.words, AppRoutes.language),
      ('News', stats.news, AppRoutes.news),
      ('Forums', stats.forums, AppRoutes.forums),
      ('Conversations', stats.topics, AppRoutes.forums),
      ('Groups', stats.groups + stats.ageGrades, AppRoutes.groups),
    ];

    return _Panel(
      title: 'What the archive holds',
      child: Column(
        children: <Widget>[
          for (final (String label, int count, String path) in rows)
            _StatRow(label: label, count: count, path: path),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.count, required this.path});

  final String label;
  final int count;
  final String path;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                // Zero is shown, not hidden. An archive at the beginning that
                // pretends to be full is one nobody trusts later.
                color: count > 0
                    ? AppColors.navy
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.pillAll,
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: count > 0 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinPanel extends StatelessWidget {
  const _JoinPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Panel(
      title: 'Join Ekoli-Yeden',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'One account. It puts you in the General Forum, lets you write to anybody here '
            'without giving out your number, and lets you send in what you have.',
            style: theme.textTheme.bodySmall,
          ),
          const Gap.md(),
          FilledButton(
            onPressed: () => context.go(AppRoutes.join),
            child: const Text('Create an account'),
          ),
          const Gap.sm(),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.size});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    if ((url ?? '').isNotEmpty) {
      return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(url!));
    }
    final String initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .take(2)
        .map((String p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.navy,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.w700),
      ),
    );
  }
}
