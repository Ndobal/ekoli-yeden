import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../repositories/contact_repository.dart';
import '../../services/api/api_response.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// WHAT THE PUBLIC HAS WRITTEN.
///
/// ---------------------------------------------------------------------------
/// AN INBOX WITH ONE READER GOES QUIET THE WEEK THAT READER IS TRAVELLING
/// ---------------------------------------------------------------------------
///
/// Every message reaches every administrator, and each one carries its own
/// state — picked up, answered, closed — so two people do not answer the same
/// message and neither knows the other did.
///
/// **Privacy requests, takedowns and complaints come first.** The server orders
/// them that way and this page marks them, because those three carry
/// obligations the others do not and "somebody asked me to take a photograph of
/// their child down and it sat behind forty greetings" is not an acceptable
/// sentence.
///
/// **How they asked to be answered is shown beside the message.** Replying by
/// email to somebody who asked for a phone call has not answered them.
class ContactInboxPage extends StatefulWidget {
  const ContactInboxPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<ContactInboxPage> createState() => _ContactInboxPageState();
}

class _ContactInboxPageState extends State<ContactInboxPage> {
  String _status = 'new';
  int _reloads = 0;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    final ContactRepository repository = context.read<ContactRepository>();
    final ThemeData theme = Theme.of(context);
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;

    return WorkspaceShell(
      currentPath: AppRoutes.adminMessages,
      title: 'Messages',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'What people have written to the Preservation Team through the contact page. '
            'Requests about somebody’s own information, and asks to take something down, are '
            'shown first — those carry obligations a greeting does not.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.xl(),
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ({String value, String label}) option
                  in const <({String value, String label})>[
                    (value: 'new', label: 'Waiting'),
                    (value: 'reading', label: 'Being read'),
                    (value: 'answered', label: 'Answered'),
                    (value: 'closed', label: 'Closed'),
                    (value: 'spam', label: 'Set aside'),
                  ])
                ChoiceChip(
                  label: Text(option.label),
                  selected: _status == option.value,
                  onSelected: (_) => setState(() {
                    _status = option.value;
                    _reloads += 1;
                    _notice = null;
                  }),
                ),
            ],
          ),
          const Gap.xl(),
          AsyncContent<PaginatedResult<ContactMessage>>(
            key: ValueKey<String>('$_status:$_reloads'),
            load: () => repository.inbox(status: _status),
            loadingMessage: 'Opening the inbox…',
            isEmpty: (PaginatedResult<ContactMessage> r) => r.isEmpty,
            emptyBuilder: (BuildContext context) => EmptyView(
              icon: _status == 'new' ? Icons.mark_email_read_outlined : Icons.inbox_outlined,
              showContributeAction: false,
              title: _status == 'new' ? 'Nothing waiting' : 'Nothing here',
              message: _status == 'new'
                  ? 'Messages sent through the contact page arrive here, and every '
                        'administrator sees them.'
                  : 'No messages in this state.',
            ),
            builder: (BuildContext context, PaginatedResult<ContactMessage> result) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${Formatters.number(result.total)} '
                  '${result.total == 1 ? 'message' : 'messages'}',
                  style: theme.textTheme.labelMedium,
                ),
                const Gap.md(),
                ...result.items.map(
                  (ContactMessage message) => _MessageCard(
                    message: message,
                    onChanged: (String notice) => setState(() {
                      _reloads += 1;
                      _notice = notice;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onChanged});

  final ContactMessage message;
  final ValueChanged<String> onChanged;

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
          border: Border.all(
            color: message.isUrgent
                ? theme.colorScheme.error.withValues(alpha: 0.6)
                : theme.colorScheme.outlineVariant,
            width: message.isUrgent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUrgent
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    message.topicLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: message.isUrgent
                          ? theme.colorScheme.onError
                          : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Gap.hMd(),
                Expanded(
                  child: Text(
                    message.subject ?? 'No subject',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  Formatters.relative(message.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Gap.lg(),
            SelectableText(message.message, style: theme.textTheme.bodyMedium),
            const Gap.lg(),

            // Who wrote, and the one line that says how to answer them.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.person_outline, size: 18),
                  const Gap.hMd(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SelectableText(message.name, style: theme.textTheme.titleSmall),
                        const Gap.xs(),
                        SelectableText(
                          message.replyLine,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const Gap.xs(),
                        Text(
                          'Reference ${message.reference}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (message.email != null || message.phone != null)
                    IconButton(
                      tooltip: 'Copy how to reach them',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: message.email ?? message.phone ?? ''),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Copied.')));
                        }
                      },
                    ),
                ],
              ),
            ),

            if (message.handlingNotes != null) ...<Widget>[
              const Gap.md(),
              Text(
                'Notes: ${message.handlingNotes}',
                style: theme.textTheme.bodySmall,
              ),
            ],

            if (message.status != 'closed' && message.status != 'spam') ...<Widget>[
              const Gap.lg(),
              const Divider(height: 1),
              const Gap.lg(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  if (message.status == 'new')
                    OutlinedButton.icon(
                      onPressed: () => _set(context, 'reading', 'Marked as being read.'),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('I am dealing with this'),
                    ),
                  FilledButton.icon(
                    onPressed: () => _withNotes(
                      context,
                      status: 'answered',
                      title: 'How did you answer them?',
                      hint: 'Answered by WhatsApp — she is happy. (For whoever reads next.)',
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Answered'),
                  ),
                  OutlinedButton(
                    onPressed: () => _withNotes(
                      context,
                      status: 'closed',
                      title: 'Closing this',
                      hint: 'What was done, if anything.',
                    ),
                    child: const Text('Close it'),
                  ),
                  TextButton(
                    onPressed: () => _set(context, 'spam', 'Set aside.'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    child: const Text('Not a real message'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, String status, String notice, {String? notes}) async {
    try {
      await context.read<ContactRepository>().setStatus(
        message.id,
        status: status,
        notes: notes,
      );
      onChanged(notice);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _withNotes(
    BuildContext context, {
    required String status,
    required String title,
    required String hint,
  }) async {
    final TextEditingController notes = TextEditingController();

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 460,
              child: TextField(
                controller: notes,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(hintText: hint, alignLabelWithHint: true),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!go || !context.mounted) return;
    await _set(
      context,
      status,
      status == 'answered' ? 'Marked answered.' : 'Closed.',
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
    );
  }
}
