import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_exception.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../repositories/admin_repository.dart';

/// EVERYTHING AN ADMINISTRATOR CAN DO TO AN ACCOUNT, ON ITS OWN ROW.
///
/// ---------------------------------------------------------------------------
/// FOUR WAYS BACK IN, AND THEY ARE NOT INTERCHANGEABLE
/// ---------------------------------------------------------------------------
///
/// **A reset link** is the default and the best: nobody ever learns the
/// person's password. It assumes they can open a link.
///
/// **A temporary password** is for the person who cannot — an elder on a
/// borrowed phone, an address that stopped working years ago. It replaces their
/// password, ends every session, expires, and gets them exactly as far as the
/// change-password screen.
///
/// **Setting a password directly** is the last resort and is labelled as one:
/// the administrator learns a password the member will go on using.
///
/// **Suspending** stops sign-in and is reversible. **Closing** is not a delete
/// — see the confirmation text, which says exactly what survives and why.
///
/// Each destructive action asks first, and each confirmation states the
/// consequence rather than asking "are you sure?". "Suspend" and "Close" read
/// almost the same in a menu and do very different things.
class UserActions extends StatefulWidget {
  const UserActions({
    required this.userId,
    required this.name,
    required this.status,
    required this.roles,
    required this.onDone,
    super.key,
  });

  final String userId;
  final String name;
  final String status;
  final List<String> roles;
  final VoidCallback onDone;

  @override
  State<UserActions> createState() => _UserActionsState();
}

class _UserActionsState extends State<UserActions> {
  bool _busy = false;

  bool get _suspended => widget.status == 'suspended';

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton(
          onPressed: () => _run(() => context.read<AdminRepository>().resetLink(widget.userId)),
          child: const Text('Reset link'),
        ),
        TextButton(onPressed: _roles, child: const Text('Roles')),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert, size: 18),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'temporary', child: Text('Temporary password')),
            const PopupMenuItem<String>(value: 'set', child: Text('Set a password directly')),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'status',
              child: Text(_suspended ? 'Reactivate the account' : 'Suspend the account'),
            ),
            const PopupMenuItem<String>(value: 'close', child: Text('Close the account')),
          ],
          onSelected: (String action) {
            switch (action) {
              case 'temporary':
                _confirmTemporary();
              case 'set':
                _setPassword();
              case 'status':
                _toggleStatus();
              case 'close':
                _close();
            }
          },
        ),
      ],
    );
  }

  /// Appointing and removing roles.
  ///
  /// The whole list is shown with what each one may do, because "Heritage
  /// Editor" means nothing to somebody who has not read the roles page — and
  /// appointing the wrong role is how permissions quietly spread.
  ///
  /// Each toggle saves immediately. The server refuses what the caller may not
  /// do — a Deputy cannot appoint a Super Admin — so a refusal here is the
  /// permission model speaking, and it is shown as it comes.
  Future<void> _roles() async {
    final AdminRepository repository = context.read<AdminRepository>();

    setState(() => _busy = true);
    late RolesResponse response;
    try {
      response = await repository.roles();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final Set<String> held = widget.roles.toSet();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext inner, StateSetter setInner) => AlertDialog(
          title: Text('Roles for ${widget.name}'),
          content: SizedBox(
            width: 560,
            height: 440,
            child: ListView(
              children: response.roles
                  .map(
                    (RoleDefinition role) => CheckboxListTile(
                      value: held.contains(role.slug),
                      title: Text(role.name),
                      subtitle: Text(
                        role.description ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(inner).textTheme.bodySmall,
                      ),
                      onChanged: (bool? value) async {
                        final bool grant = value ?? false;
                        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(inner);
                        try {
                          if (grant) {
                            await repository.assignRole(widget.userId, role.slug);
                            setInner(() => held.add(role.slug));
                          } else {
                            await repository.revokeRole(widget.userId, role.slug);
                            setInner(() => held.remove(role.slug));
                          }
                          widget.onDone();
                        } on AppException catch (error) {
                          messenger.showSnackBar(SnackBar(content: Text(error.message)));
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  /// Suspending is reversible, and the confirmation says so. That is the whole
  /// difference from closing, and it is the thing to be clear about.
  Future<void> _toggleStatus() async {
    final bool go = await _confirm(
      title: _suspended ? 'Reactivate ${widget.name}?' : 'Suspend ${widget.name}?',
      body: _suspended
          ? 'They will be able to sign in again. Their roles and their profile are unchanged.'
          : 'They cannot sign in, and every session they hold ends immediately. Nothing is '
                'deleted, and you can reactivate them at any time.',
      confirm: _suspended ? 'Reactivate' : 'Suspend',
    );
    if (!go || !mounted) return;

    await _guard(() async {
      await context.read<AdminRepository>().setStatus(
        widget.userId,
        _suspended ? 'active' : 'suspended',
      );
      widget.onDone();
    });
  }

  /// Closing, with what it does and does not touch stated in full.
  Future<void> _close() async {
    final TextEditingController reason = TextEditingController();

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Close the account of ${widget.name}?'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'They can no longer sign in, every session ends, and they come out of the '
                    'directory and the messaging search.',
                  ),
                  const Gap.md(),
                  const Text(
                    'What they contributed to the archive stays, and so does their name on it. '
                    'That is deliberate: an archive whose record of who supplied what can be '
                    'erased is not an archive. If somebody has asked for their personal data to '
                    'be removed, handle that as a privacy request in Messages.',
                  ),
                  const Gap.lg(),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Why (recorded in the audit log)',
                    ),
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
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: const Text('Close the account'),
              ),
            ],
          ),
        ) ??
        false;

    if (!go || !mounted) return;

    await _guard(() async {
      final String message = await context.read<AdminRepository>().closeAccount(
        widget.userId,
        reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
      );
      widget.onDone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  /// Setting a password directly.
  ///
  /// The least good of the three ways in, offered because there are people it
  /// is the only thing that works for — and labelled honestly rather than
  /// presented as equivalent.
  Future<void> _setPassword() async {
    final TextEditingController password = TextEditingController();

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Set a password for ${widget.name}'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Prefer a reset link, or a temporary password — with either of those you '
                    'never learn what they end up using. Use this only when neither will work '
                    'for them, and tell them to change it.',
                  ),
                  const Gap.lg(),
                  TextField(
                    controller: password,
                    decoration: const InputDecoration(
                      labelText: 'The password',
                      helperText: 'Six characters or more. Common ones are refused.',
                    ),
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
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Set it'),
              ),
            ],
          ),
        ) ??
        false;

    if (!go || !mounted) return;

    await _guard(() async {
      await context.read<AdminRepository>().setPassword(widget.userId, password.text);
      widget.onDone();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set. Every session on the account has ended.')),
        );
      }
    });
  }

  Future<void> _confirmTemporary() async {
    final bool go = await _confirm(
      title: 'A temporary password for ${widget.name}?',
      body:
          'This replaces their current password and signs them out everywhere. They must choose '
          'a new one the moment they sign in, and it stops working after the window set in '
          'Security settings. If they can open a link, send a reset link instead.',
      confirm: 'Issue it',
    );
    if (!go || !mounted) return;
    await _run(() => context.read<AdminRepository>().temporaryPassword(widget.userId));
  }

  Future<void> _run(Future<PasswordHandover> Function() action) async {
    setState(() => _busy = true);
    try {
      final PasswordHandover handover = await action();
      if (mounted) await showHandover(context, handover);
      widget.onDone();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirm,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: SizedBox(width: 460, child: Text(body)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirm),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Shows the link or the password, once.
///
/// Selectable and large. An administrator is about to read this down a phone
/// line or type it into WhatsApp, and there is no second chance to see it —
/// the server keeps only a digest.
Future<void> showHandover(BuildContext context, PasswordHandover handover) {
  final ThemeData theme = Theme.of(context);

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(
        handover.isLink
            ? 'Reset link for ${handover.displayName ?? handover.email ?? 'this account'}'
            : 'Temporary password for ${handover.displayName ?? handover.email ?? 'this account'}',
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                handover.value,
                style: handover.isLink
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.headlineSmall?.copyWith(letterSpacing: 1.5),
              ),
            ),
            const Gap.lg(),
            Text(handover.guidance, style: theme.textTheme.bodyMedium),
            if (handover.isLink && handover.expiresAt != null) ...<Widget>[
              const Gap.sm(),
              Text(
                'It expires ${Formatters.dateTime(handover.expiresAt)}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Gap.lg(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const Gap.hSm(),
                Expanded(
                  child: Text(
                    'This is shown once. Nothing here is stored — the server keeps only a '
                    'digest of it.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(dialogContext);
            await Clipboard.setData(ClipboardData(text: handover.value));
            messenger.showSnackBar(const SnackBar(content: Text('Copied.')));
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
