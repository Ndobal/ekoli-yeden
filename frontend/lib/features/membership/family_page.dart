import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/kinship_repository.dart';

/// YOUR FAMILY.
///
/// Who you are connected to, who has asked, and who you have asked.
///
/// ---------------------------------------------------------------------------
/// NOTHING IS A RELATIONSHIP UNTIL BOTH SIDES SAY SO
/// ---------------------------------------------------------------------------
///
/// Anybody can claim anybody is their brother. The platform records that as a
/// request and nothing more, and the interface never shows an unanswered claim
/// as though it were settled.
///
/// This matters beyond politeness. Confirming that somebody has died requires a
/// close relationship accepted BEFORE the death was reported — so a claim that
/// could stand unanswered would be a way to manufacture the authority to still
/// a living person's account.
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) => setState(() {
        _reloads += 1;
        _notice = notice;
      });

  @override
  Widget build(BuildContext context) {
    final KinshipRepository repository = context.read<KinshipRepository>();

    return AppScaffold(
      currentPath: AppRoutes.account,
      seo: const SeoMetadata(
        title: 'Your family',
        description: 'Your family connections on Ekoli Yeden.',
        canonicalPath: AppRoutes.accountFamily,
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'Your account',
        title: 'Your family',
        description:
            'Record who your relatives are. Both people have to agree before anything is kept — '
            'so nobody can claim a connection to you that you have not confirmed.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.account),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to your dashboard'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.lg(),
            if (_notice != null) ...<Widget>[
              _Notice(message: _notice!),
              const Gap.lg(),
            ],
            _ConnectForm(onSent: _reload),
            const Gap.xxl(),
            AsyncContent<
                ({
                  List<Relationship> accepted,
                  List<Relationship> incoming,
                  List<Relationship> outgoing
                })>(
              key: ValueKey<int>(_reloads),
              load: repository.family,
              loadingMessage: 'Loading…',
              builder: (
                BuildContext context,
                ({
                  List<Relationship> accepted,
                  List<Relationship> incoming,
                  List<Relationship> outgoing
                }) family,
              ) {
                final ThemeData theme = Theme.of(context);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Waiting on you, first. It is the only part of this page
                    // that asks something of the reader.
                    if (family.incoming.isNotEmpty) ...<Widget>[
                      Text('Waiting for your answer', style: theme.textTheme.titleMedium),
                      const Gap.md(),
                      ...family.incoming.map(
                        (Relationship r) => _IncomingCard(relationship: r, onAnswered: _reload),
                      ),
                      const Gap.xxl(),
                    ],
                    Text('Your family', style: theme.textTheme.titleMedium),
                    const Gap.md(),
                    if (family.accepted.isEmpty)
                      Text(
                        'Nobody yet. Connect to a relative above — by their phone number, or by '
                        'opening their profile.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ...family.accepted.map(
                        (Relationship r) => _RelationshipRow(relationship: r, onChanged: _reload),
                      ),
                    if (family.outgoing.isNotEmpty) ...<Widget>[
                      const Gap.xxl(),
                      Text('You have asked', style: theme.textTheme.titleMedium),
                      const Gap.xs(),
                      Text(
                        'Nothing is recorded until they answer.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap.md(),
                      ...family.outgoing.map(
                        (Relationship r) => _RelationshipRow(
                          relationship: r,
                          onChanged: _reload,
                          pending: true,
                        ),
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
}

/// Connecting to somebody — by phone number, or by their handle.
class _ConnectForm extends StatefulWidget {
  const _ConnectForm({required this.onSent});

  final void Function([String? notice]) onSent;

  @override
  State<_ConnectForm> createState() => _ConnectFormState();
}

class _ConnectFormState extends State<_ConnectForm> {
  final TextEditingController _who = TextEditingController();
  String _type = 'brother';
  bool _byPhone = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _who.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_who.text.trim().isEmpty) {
      setState(() => _error = 'Say who you mean.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String message = await context.read<KinshipRepository>().request(
            type: _type,
            phone: _byPhone ? _who.text.trim() : null,
            handle: _byPhone ? null : _who.text.trim(),
          );
      _who.clear();
      widget.onSent(message);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Connect to a relative', style: theme.textTheme.titleSmall),
          const Gap.md(),
          Row(
            children: <Widget>[
              ChoiceChip(
                selected: _byPhone,
                label: const Text('By phone number'),
                onSelected: (bool _) => setState(() => _byPhone = true),
              ),
              const Gap.hSm(),
              ChoiceChip(
                selected: !_byPhone,
                label: const Text('By their handle'),
                onSelected: (bool _) => setState(() => _byPhone = false),
              ),
            ],
          ),
          const Gap.md(),
          TextField(
            controller: _who,
            decoration: InputDecoration(
              labelText: _byPhone ? 'Their phone number' : 'Their handle',
              helperText: _byPhone
                  ? 'We will not tell you whether that number belongs to a member — that would '
                      'be a way to test numbers against our membership.'
                  : 'The name in their profile address.',
            ),
          ),
          const Gap.lg(),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'They are your…'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'father', child: Text('Father')),
              DropdownMenuItem<String>(value: 'mother', child: Text('Mother')),
              DropdownMenuItem<String>(value: 'son', child: Text('Son')),
              DropdownMenuItem<String>(value: 'daughter', child: Text('Daughter')),
              DropdownMenuItem<String>(value: 'brother', child: Text('Brother')),
              DropdownMenuItem<String>(value: 'sister', child: Text('Sister')),
              DropdownMenuItem<String>(value: 'husband', child: Text('Husband')),
              DropdownMenuItem<String>(value: 'wife', child: Text('Wife')),
              DropdownMenuItem<String>(value: 'cousin', child: Text('Cousin')),
              DropdownMenuItem<String>(value: 'uncle', child: Text('Uncle')),
              DropdownMenuItem<String>(value: 'aunt', child: Text('Aunt')),
              DropdownMenuItem<String>(value: 'grandfather', child: Text('Grandfather')),
              DropdownMenuItem<String>(value: 'grandmother', child: Text('Grandmother')),
              DropdownMenuItem<String>(value: 'kin', child: Text('Related another way')),
            ],
            onChanged: _busy ? null : (String? v) => setState(() => _type = v ?? _type),
          ),
          if (_error != null) ...<Widget>[
            const Gap.sm(),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const Gap.lg(),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy ? const Text('Asking…') : const Text('Ask them to confirm'),
          ),
        ],
      ),
    );
  }
}

/// A request waiting on this member.
class _IncomingCard extends StatefulWidget {
  const _IncomingCard({required this.relationship, required this.onAnswered});

  final Relationship relationship;
  final void Function([String? notice]) onAnswered;

  @override
  State<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends State<_IncomingCard> {
  String? _reverse;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Relationship r = widget.relationship;
    final List<({String value, String label})> options = r.reverseOptions;

    _reverse ??= options.isEmpty ? null : options.first.value;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${r.personName} says you are their '
            '${(r.requestedTypeLabel ?? 'family').toLowerCase()}.',
            style: theme.textTheme.titleSmall,
          ),
          if (r.note != null) ...<Widget>[
            const Gap.xs(),
            Text(r.note!, style: theme.textTheme.bodySmall),
          ],
          const Gap.md(),
          if (options.isNotEmpty) ...<Widget>[
            // Only they can say which they are. The archive does not ask anybody
            // to record their sex so that it can guess for them.
            DropdownButtonFormField<String>(
              initialValue: _reverse,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'And you are their…',
                isDense: true,
              ),
              items: options
                  .map((({String value, String label}) o) =>
                      DropdownMenuItem<String>(value: o.value, child: Text(o.label)))
                  .toList(growable: false),
              onChanged: _busy ? null : (String? v) => setState(() => _reverse = v),
            ),
            const Gap.md(),
          ],
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        // Captured before the await: reading an inherited
                        // widget across an async gap is unsafe.
                        final KinshipRepository repository =
                            context.read<KinshipRepository>();
                        final ScaffoldMessengerState messenger =
                            ScaffoldMessenger.of(context);

                        setState(() => _busy = true);
                        try {
                          await repository.accept(r.id, reverseType: _reverse ?? 'kin');
                          widget.onAnswered('Confirmed.');
                        } on AppException catch (error) {
                          if (mounted) {
                            messenger.showSnackBar(SnackBar(content: Text(error.message)));
                            setState(() => _busy = false);
                          }
                        }
                      },
                child: const Text('Confirm'),
              ),
              const Gap.hMd(),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await context.read<KinshipRepository>().decline(r.id);
                        widget.onAnswered('Declined.');
                      },
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({
    required this.relationship,
    required this.onChanged,
    this.pending = false,
  });

  final Relationship relationship;
  final void Function([String? notice]) onChanged;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.green.withValues(alpha: 0.15),
            backgroundImage: relationship.avatarUrl == null
                ? null
                : NetworkImage(relationship.avatarUrl!),
            child: relationship.avatarUrl != null
                ? null
                : const Icon(Icons.person_outline, size: 18),
          ),
          const Gap.hMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(relationship.personName, style: theme.textTheme.bodyMedium),
                Text(
                  pending
                      ? 'Waiting for them to answer'
                      : 'Your ${relationship.typeLabel.toLowerCase()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: pending ? 'Withdraw' : 'End this connection',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () async {
              await context.read<KinshipRepository>().remove(relationship.id);
              onChanged(pending ? 'Withdrawn.' : 'Ended.');
            },
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
