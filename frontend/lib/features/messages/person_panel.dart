import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../models/member.dart';
import '../../models/message.dart';
import '../../repositories/member_repository.dart';
import '../../repositories/message_repository.dart';
import 'messages_page.dart' show MemberAvatar;

/// WHO YOU ARE TALKING TO.
///
/// ---------------------------------------------------------------------------
/// THE PANEL WHERE THE CONTACT RULE BECOMES VISIBLE
/// ---------------------------------------------------------------------------
///
/// Everywhere else in the messaging module, contact details are simply absent.
/// This is the one screen where their absence is explained — and where somebody
/// who genuinely needs a phone number can ask for it.
///
/// The states, and each is worded rather than left blank:
///
///   **Not shared.** "Their number is not shown" with a button to ask. Not an
///   empty field, and not a missing row that reads as a bug.
///   **Asked.** "You have asked. They will decide." Nothing more to press.
///   **Shared.** The number, selectable, with a note that they chose to share
///   it and can take it back.
///
/// A profile that shows nothing and explains nothing teaches people that the
/// platform is broken. A profile that says "this is hidden, here is how to ask"
/// teaches them how it works.
class PersonPanel extends StatefulWidget {
  const PersonPanel({required this.conversationId, this.embedded = false, super.key});

  final String conversationId;

  /// Rendered inside a bottom sheet on a narrow screen, where it supplies its
  /// own scroll and does not need the card around it.
  final bool embedded;

  @override
  State<PersonPanel> createState() => _PersonPanelState();
}

class _PersonPanelState extends State<PersonPanel> {
  int _reloads = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget body = AsyncContent<ConversationThread>(
      key: ValueKey<String>('${widget.conversationId}:$_reloads'),
      load: () => context.read<MessageRepository>().thread(widget.conversationId, perPage: 1),
      loadingMessage: null,
      builder: (BuildContext context, ConversationThread thread) {
        final MessagePerson? person = thread.with_;
        if (person == null) {
          return const SizedBox.shrink();
        }
        return _Details(
          person: person,
          onChanged: () => setState(() => _reloads += 1),
        );
      },
    );

    if (widget.embedded) return body;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: body,
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.person, required this.onChanged});

  final MessagePerson person;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        MemberAvatar(person: person, size: 76),
        const Gap.md(),
        Text(person.name, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        if (person.headline != null) ...<Widget>[
          const Gap.xs(),
          Text(
            person.headline!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Gap.lg(),
        if (person.handle != null)
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.memberProfile(person.handle!)),
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Their profile'),
          ),
        const Gap.xl(),
        const Divider(height: 1),
        const Gap.lg(),

        // The contact details, and the state they are in.
        if (person.handle != null)
          _ContactBlock(handle: person.handle!, name: person.name, onChanged: onChanged),
      ],
    );
  }
}

/// Their contact details, or the reason there are none, or the way to ask.
class _ContactBlock extends StatelessWidget {
  const _ContactBlock({required this.handle, required this.name, required this.onChanged});

  final String handle;
  final String name;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AsyncContent<MemberProfile>(
      // Read from the profile route rather than from the conversation, because
      // the profile route is where the grant is applied. One source of truth
      // for "may this reader see this number", and it is the server's.
      load: () => context.read<MemberRepository>().member(handle),
      loadingMessage: null,
      builder: (BuildContext context, MemberProfile profile) {
        final bool hasPhone = profile.phone != null || profile.whatsappNumber != null;
        final bool hasEmail = profile.email != null;

        if (hasPhone || hasEmail) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('HOW TO REACH THEM', style: theme.textTheme.labelSmall),
              const Gap.md(),
              if (profile.phone != null)
                _ContactLine(icon: Icons.phone_outlined, value: profile.phone!),
              if (profile.whatsappNumber != null)
                _ContactLine(icon: Icons.chat_outlined, value: profile.whatsappNumber!),
              if (profile.email != null)
                _ContactLine(icon: Icons.mail_outline, value: profile.email!),
              const Gap.md(),
              Text(
                'They chose to share this, and they can take it back at any time.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        return _AskForContact(handle: handle, name: name, onChanged: onChanged);
      },
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.navy),
          const Gap.hMd(),
          Expanded(
            child: SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// "Their number is not shown" — and the way to ask for it.
class _AskForContact extends StatefulWidget {
  const _AskForContact({required this.handle, required this.name, required this.onChanged});

  final String handle;
  final String name;
  final VoidCallback onChanged;

  @override
  State<_AskForContact> createState() => _AskForContactState();
}

class _AskForContactState extends State<_AskForContact> {
  bool _busy = false;
  String? _sent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_sent != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.08),
          borderRadius: AppRadius.smAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
            const Gap.sm(),
            Text(_sent!, style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const Gap.hSm(),
            Text('THEIR DETAILS ARE HIDDEN', style: theme.textTheme.labelSmall),
          ],
        ),
        const Gap.sm(),
        Text(
          'You can keep writing to ${widget.name} here without them. If you need to reach them '
          'another way, ask — and they decide.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap.lg(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _ask,
            icon: const Icon(Icons.contact_page_outlined, size: 18),
            label: const Text('Ask for their details'),
          ),
        ),
      ],
    );
  }

  /// Asks, with a reason.
  ///
  /// The reason is not decoration: it is what the other person reads when
  /// deciding, and "I am your cousin in Calabar and there is a funeral" is a
  /// different request from "hi".
  Future<void> _ask() async {
    final TextEditingController reason = TextEditingController();
    bool wantsPhone = true;
    bool wantsEmail = false;

    final bool send =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => StatefulBuilder(
            builder: (BuildContext inner, StateSetter setInner) => AlertDialog(
              title: Text('Ask ${widget.name}'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const CmsText(
                        'messages.contact_request.explainer',
                        fallback:
                            'Asking to see somebody’s phone number or email sends them a '
                            'request. They decide, and they can change their mind later. '
                            'Nothing is shared until they say yes.',
                      ),
                      const Gap.lg(),
                      CheckboxListTile(
                        value: wantsPhone,
                        onChanged: (bool? value) =>
                            setInner(() => wantsPhone = value ?? wantsPhone),
                        title: const Text('Their phone number'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: wantsEmail,
                        onChanged: (bool? value) =>
                            setInner(() => wantsEmail = value ?? wantsEmail),
                        title: const Text('Their email address'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Gap.md(),
                      TextField(
                        controller: reason,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Why you are asking',
                          alignLabelWithHint: true,
                          helperText: 'They read this before deciding. Say who you are.',
                          helperMaxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: (wantsPhone || wantsEmail)
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Send the request'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!send || !mounted) return;

    setState(() => _busy = true);
    try {
      final String message = await context.read<MessageRepository>().requestContact(
        handle: widget.handle,
        reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
        wantsPhone: wantsPhone,
        wantsEmail: wantsEmail,
      );
      if (mounted) setState(() => _sent = message);
      widget.onChanged();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
