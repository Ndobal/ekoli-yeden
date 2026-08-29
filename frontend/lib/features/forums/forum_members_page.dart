/// A FORUM'S OWN ADMINISTRATION.
///
/// Requests waiting, and the people already in. Reachable by the space's own
/// admins and by a Super Admin, and by nobody else — the server decides that;
/// this page simply asks and shows what it is given.
///
/// The queue is above the roster because it is the part with work in it. A
/// screen that opens on a list of people who are already members, with the
/// requests below the fold, is a screen where requests wait for days.
library;

import 'package:flutter/material.dart';
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
import '../../models/forum.dart';
import '../../repositories/forum_repository.dart';

class ForumMembersPage extends StatefulWidget {
  const ForumMembersPage({required this.space, super.key});

  final String space;

  @override
  State<ForumMembersPage> createState() => _ForumMembersPageState();
}

class _ForumMembersPageState extends State<ForumMembersPage> {
  int _reloads = 0;
  String? _notice;

  void _reload(String message) => setState(() {
    _reloads += 1;
    _notice = message;
  });

  Future<void> _decide(
    ForumMember member, {
    required String action,
    String? role,
  }) async {
    final ForumRepository repository = context.read<ForumRepository>();

    // A refusal, a removal or a suspension is explained. The person is told
    // what was decided either way, so a note nobody writes becomes a decision
    // nobody can understand.
    String? note;
    if (action == 'reject' || action == 'remove' || action == 'suspend') {
      note = await showDialog<String>(
        context: context,
        builder: (BuildContext context) => _NoteDialog(action: action, name: member.name),
      );
      if (note == null) return;
    }

    try {
      final String message = await repository.decideMembership(
        widget.space,
        member.userId,
        action: action,
        note: note == null || note.isEmpty ? null : note,
        role: role,
      );
      _reload(message);
    } on AppException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ForumRepository repository = context.read<ForumRepository>();
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.forums,
      seo: const SeoMetadata(title: 'Forum members', noIndex: true),
      child: PageSection(
        eyebrow: 'Forum administration',
        title: 'Members and requests',
        description:
            'Who is in this forum, and who has asked to be. A decision is sent to the person '
            'it concerns, so nobody is left wondering.',
        child: AsyncContent<({List<ForumMember> members, List<ForumMember> pending})>(
          key: ValueKey<int>(_reloads),
          load: () => repository.forumMembers(widget.space),
          loadingMessage: 'Opening the forum…',
          builder: (
            BuildContext context,
            ({List<ForumMember> members, List<ForumMember> pending}) data,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_notice != null) ...<Widget>[
                  _Notice(message: _notice!),
                  const Gap.xl(),
                ],

                Text(
                  data.pending.isEmpty
                      ? 'Waiting to join'
                      : 'Waiting to join (${data.pending.length})',
                  style: theme.textTheme.titleLarge,
                ),
                const Gap.sm(),
                if (data.pending.isEmpty)
                  Text(
                    'Nobody is waiting. Requests appear here the moment somebody asks.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                else
                  for (final ForumMember member in data.pending)
                    _MemberRow(
                      member: member,
                      pending: true,
                      onApprove: () => _decide(member, action: 'approve'),
                      onReject: () => _decide(member, action: 'reject'),
                      onRemove: null,
                      onSuspend: null,
                      onRestore: null,
                      onMakeAdmin: null,
                    ),

                const Gap.xxl(),
                Text('In this forum (${data.members.length})', style: theme.textTheme.titleLarge),
                const Gap.sm(),
                if (data.members.isEmpty)
                  const EmptyView(
                    icon: Icons.groups_outlined,
                    title: 'Nobody has joined yet',
                    message:
                        'When somebody asks to join and is approved, they appear here.',
                    showContributeAction: false,
                  )
                else
                  for (final ForumMember member in data.members)
                    _MemberRow(
                      member: member,
                      pending: false,
                      onApprove: null,
                      onReject: null,
                      onRemove: () => _decide(member, action: 'remove'),
                      onSuspend: member.isSuspended
                          ? null
                          : () => _decide(member, action: 'suspend'),
                      onRestore: member.isSuspended
                          ? () => _decide(member, action: 'restore')
                          : null,
                      onMakeAdmin: member.runsIt
                          ? () => _decide(member, action: 'set_role', role: 'member')
                          : () => _decide(member, action: 'set_role', role: 'admin'),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.pending,
    required this.onApprove,
    required this.onReject,
    required this.onRemove,
    required this.onSuspend,
    required this.onRestore,
    required this.onMakeAdmin,
  });

  final ForumMember member;
  final bool pending;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;
  final VoidCallback? onSuspend;
  final VoidCallback? onRestore;
  final VoidCallback? onMakeAdmin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: member.isSuspended
                ? theme.colorScheme.error.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Avatar(member: member),
                const Gap.hMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(member.name, style: theme.textTheme.titleSmall),
                          ),
                          if (member.runsIt) ...<Widget>[
                            const Gap.hSm(),
                            const _Tag(label: 'Runs this forum'),
                          ],
                          if (member.isSuspended) ...<Widget>[
                            const Gap.hSm(),
                            const _Tag(label: 'Suspended', warning: true),
                          ],
                        ],
                      ),
                      if (pending && member.requestedAt != null)
                        Text(
                          'Asked ${Formatters.relative(member.requestedAt!)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (member.handle != null)
                        Text(
                          '@${member.handle}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // What they said when they asked. The thing an administrator is
            // actually deciding on, so it is not hidden behind a link.
            if ((member.requestNote ?? '').isNotEmpty) ...<Widget>[
              const Gap.md(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(member.requestNote!, style: theme.textTheme.bodyMedium),
              ),
            ],

            const Gap.md(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (onApprove != null)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Not this time'),
                  ),
                if (onRestore != null)
                  FilledButton.tonalIcon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.lock_open_outlined, size: 16),
                    label: const Text('Lift the suspension'),
                  ),
                if (onSuspend != null)
                  OutlinedButton.icon(
                    onPressed: onSuspend,
                    icon: const Icon(Icons.pause_circle_outline, size: 16),
                    label: const Text('Suspend'),
                  ),
                if (onMakeAdmin != null)
                  TextButton.icon(
                    onPressed: onMakeAdmin,
                    icon: Icon(
                      member.runsIt ? Icons.person_outline : Icons.shield_outlined,
                      size: 16,
                    ),
                    label: Text(member.runsIt ? 'Make an ordinary member' : 'Make an administrator'),
                  ),
                if (onRemove != null)
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member});

  final ForumMember member;

  @override
  Widget build(BuildContext context) {
    if ((member.avatarUrl ?? '').isNotEmpty) {
      return CircleAvatar(radius: 21, backgroundImage: NetworkImage(member.avatarUrl!));
    }
    final String initials = member.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .take(2)
        .map((String p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 21,
      backgroundColor: AppColors.navy,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = warning ? theme.colorScheme.error : AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: colour, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.action, required this.name});

  final String action;
  final String name;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String verb = switch (widget.action) {
      'reject' => 'Not accepting',
      'remove' => 'Removing',
      _ => 'Suspending',
    };

    return AlertDialog(
      title: Text('$verb ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'They will be told, and they will see whatever you write here. A decision somebody '
            'cannot understand is one they will simply ask about again.',
          ),
          const Gap.lg(),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reason (optional, but worth writing)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: Text(verb.split(' ').first),
        ),
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
        color: AppColors.green.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.greenDark),
          const Gap.hMd(),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
