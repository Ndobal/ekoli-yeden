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
import '../../models/member.dart';
import '../../repositories/member_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';

/// EVERYTHING THE ARCHIVE HAS TOLD YOU.
///
/// The account dashboard shows the most recent few; this is all of them, kept.
/// That distinction matters: a notification panel that only ever holds five
/// items is one where somebody who was away for a week has already missed
/// whatever was said to them.
///
/// Notifications are grouped by day rather than listed as a flat stream. "Today"
/// and "Yesterday" are how people actually ask the question — a column of
/// timestamps is not.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unreadOnly = false;
  int _page = 1;
  int _reloads = 0;

  void _reload() => setState(() => _reloads += 1);

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    if (!auth.isSignedIn) return const _SignedOut();

    final MemberRepository repository = context.read<MemberRepository>();

    return AppScaffold(
      currentPath: AppRoutes.account,
      seo: const SeoMetadata(title: 'Notifications', noIndex: true),
      child: PageSection(
        eyebrow: 'Your account',
        title: 'Notifications',
        description:
            'Replies to your conversations, what the moderators decided, and anything the '
            'Preservation Team needs you to know.',
        action: TextButton.icon(
          onPressed: () => context.go(AppRoutes.account),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to your account'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('Everything')),
                    ButtonSegment<bool>(value: true, label: Text('Unread')),
                  ],
                  selected: <bool>{_unreadOnly},
                  onSelectionChanged: (Set<bool> value) => setState(() {
                    _unreadOnly = value.first;
                    _page = 1;
                  }),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await repository.markAllRead();
                      _reload();
                    } on AppException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                      }
                    }
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark everything read'),
                ),
              ],
            ),
            const Gap.xl(),
            AsyncContent<PaginatedResult<MemberNotification>>(
              key: ValueKey<String>('$_unreadOnly:$_page:$_reloads'),
              load: () => repository.notifications(page: _page, unreadOnly: _unreadOnly),
              loadingMessage: 'Fetching your notifications…',
              isEmpty: (PaginatedResult<MemberNotification> r) => r.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: _unreadOnly ? Icons.done_all : Icons.notifications_none,
                showContributeAction: false,
                title: _unreadOnly ? 'Nothing unread' : 'Nothing yet',
                message: _unreadOnly
                    ? 'You have read everything.'
                    : 'When somebody replies to you in the forums, when an opportunity suits '
                          'you, or when the Preservation Team acts on something you sent in, '
                          'it appears here.',
              ),
              builder: (BuildContext context, PaginatedResult<MemberNotification> result) {
                final Map<String, List<MemberNotification>> byDay = _groupByDay(result.items);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final MapEntry<String, List<MemberNotification>> day in byDay.entries) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          day.key.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      ...day.value.map(
                        (MemberNotification note) =>
                            _NotificationCard(note: note, onChanged: _reload),
                      ),
                      const Gap.lg(),
                    ],
                    if (result.totalPages > 1) ...<Widget>[
                      const Gap.md(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
                            child: const Text('Newer'),
                          ),
                          const Gap.hLg(),
                          Text(
                            '${result.page} of ${result.totalPages}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const Gap.hLg(),
                          OutlinedButton(
                            onPressed: result.hasMore
                                ? () => setState(() => _page += 1)
                                : null,
                            child: const Text('Older'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Today, Yesterday, then the date. Insertion order is preserved, and the
  /// server already sent them newest first.
  Map<String, List<MemberNotification>> _groupByDay(List<MemberNotification> items) {
    final DateTime now = DateTime.now();
    final Map<String, List<MemberNotification>> grouped =
        <String, List<MemberNotification>>{};

    for (final MemberNotification note in items) {
      final DateTime? at = DateTime.tryParse(note.createdAt ?? '')?.toLocal();
      final String label;

      if (at == null) {
        label = 'Undated';
      } else {
        final int days = DateTime(now.year, now.month, now.day)
            .difference(DateTime(at.year, at.month, at.day))
            .inDays;
        label = days == 0
            ? 'Today'
            : days == 1
            ? 'Yesterday'
            : Formatters.date(note.createdAt);
      }

      grouped.putIfAbsent(label, () => <MemberNotification>[]).add(note);
    }

    return grouped;
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.note, required this.onChanged});

  final MemberNotification note;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: note.isUnread
            ? AppColors.gold.withValues(alpha: 0.06)
            : theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () async {
            // Read first, then go. Marking it read after navigating away loses
            // the request when the page is replaced.
            if (note.isUnread) {
              try {
                await context.read<MemberRepository>().markRead(note.id);
                onChanged();
              } on AppException {
                // Reading a notification is not worth an error message. The
                // dot stays; the link still works.
              }
            }
            if (note.linkPath != null && context.mounted) context.go(note.linkPath!);
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: note.isUnread
                    ? AppColors.gold.withValues(alpha: 0.45)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(note.kind), size: 18),
                ),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        note.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: note.isUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (note.body != null) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          note.body!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Gap.sm(),
                      Row(
                        children: <Widget>[
                          Text(
                            Formatters.relative(note.createdAt),
                            style: theme.textTheme.labelSmall,
                          ),
                          if (note.linkPath != null) ...<Widget>[
                            const Gap.hMd(),
                            Text(
                              '·  Open',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.navyLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (note.isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String kind) {
    switch (kind) {
      case 'forum_reply':
      case 'forum_mention':
        return Icons.forum_outlined;
      case 'forum_moderation':
        return Icons.shield_outlined;
      case 'opportunity_match':
      case 'opportunity_deadline':
      case 'application_status':
        return Icons.work_outline;
      case 'membership':
        return Icons.badge_outlined;
      case 'contribution':
        return Icons.volunteer_activism_outlined;
      case 'age_grade':
        return Icons.groups_outlined;
      default:
        return Icons.notifications_none;
    }
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentPath: AppRoutes.account,
      seo: const SeoMetadata(title: 'Notifications', noIndex: true),
      child: PageSection(
        reading: true,
        title: 'Sign in to see your notifications',
        description: 'They are kept for you until you do.',
        child: FilledButton(
          onPressed: () =>
              context.go(AppRoutes.signInReturningTo(AppRoutes.accountNotifications)),
          child: const Text('Sign in'),
        ),
      ),
    );
  }
}
