import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/cms_text.dart';
import '../../repositories/contact_repository.dart';
import '../../services/auth/auth_controller.dart';

/// WRITING TO THE PRESERVATION TEAM.
///
/// ---------------------------------------------------------------------------
/// WHY A FORM AND NOT AN EMAIL ADDRESS
/// ---------------------------------------------------------------------------
///
/// An address on a page works for somebody with an email client set up who
/// remembers to say what they are writing about. Most people reaching this
/// archive are on a phone, arriving from a WhatsApp link, and for them a
/// `mailto:` is where the message stops.
///
/// A message sent here reaches every administrator rather than one inbox, and
/// the sender is given a reference they can quote.
///
/// **The topic is the field that does the work.** "Please take my photograph
/// down" and "hello from Lagos" are not the same message, must not sit in the
/// same queue in the same order, and the person writing the first one deserves
/// to be told, on this page, that it will be treated seriously.
///
/// **The reply channel is asked for rather than assumed.** Email is not how
/// most of this community communicates, and answering by email somebody who
/// asked for a phone call has not answered them.
class ContactForm extends StatefulWidget {
  const ContactForm({super.key});

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _message = TextEditingController();

  List<ContactTopic> _topics = const <ContactTopic>[];
  List<({String value, String label})> _channels = const <({String value, String label})>[];
  String _topic = 'general';
  String _reply = 'whatsapp';
  bool _busy = false;
  String? _error;
  ({String reference, String message})? _receipt;

  @override
  void initState() {
    super.initState();
    _load();

    // Prefilled for somebody signed in, and still editable — an administrator
    // asking about a family member's photograph should not have to correct the
    // name back to their own.
    final AuthController auth = context.read<AuthController>();
    if (auth.isSignedIn) {
      _name.text = auth.user?.displayName ?? '';
      _email.text = auth.user?.email ?? '';
    }
  }

  Future<void> _load() async {
    try {
      final ({
        List<ContactTopic> topics,
        List<({String value, String label})> replyChannels,
      })
      options = await context.read<ContactRepository>().options();
      if (mounted) {
        setState(() {
          _topics = options.topics;
          _channels = options.replyChannels;
        });
      }
    } on AppException {
      // The form still sends without them: topic and reply channel both have
      // defaults the server accepts.
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _email,
      _phone,
      _subject,
      _message,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ContactTopic? get _chosen {
    for (final ContactTopic topic in _topics) {
      if (topic.value == _topic) return topic;
    }
    return null;
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Checked here as well as on the server, so somebody who wants an answer is
    // told now rather than waiting for a reply that could never arrive.
    if (_reply != 'none' && _email.text.trim().isEmpty && _phone.text.trim().isEmpty) {
      setState(
        () => _error =
            'Leave an email address or a phone number, or choose "No reply needed".',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ({String reference, String message}) receipt = await context
          .read<ContactRepository>()
          .send(<String, dynamic>{
            'name': _name.text.trim(),
            'message': _message.text.trim(),
            'topic': _topic,
            'preferred_reply': _reply,
            if (_subject.text.trim().isNotEmpty) 'subject': _subject.text.trim(),
            if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
            if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
          });

      if (mounted) setState(() => _receipt = receipt);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_receipt != null) return _Receipt(receipt: _receipt!);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Write to us', style: theme.textTheme.titleLarge),
            const Gap.sm(),
            CmsText(
              'page.contact.form_intro',
              fallback:
                  'Write to the Preservation Team. Every message reaches all of the '
                  'administrators rather than one inbox, and you are given a reference you can '
                  'quote if you need to follow it up.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap.xl(),

            if (_topics.isNotEmpty) ...<Widget>[
              Text('What is it about?', style: theme.textTheme.titleSmall),
              const Gap.md(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _topics
                    .map(
                      (ContactTopic topic) => ChoiceChip(
                        label: Text(topic.label),
                        selected: _topic == topic.value,
                        onSelected: (_) => setState(() => _topic = topic.value),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (_chosen?.help != null) ...<Widget>[
                const Gap.sm(),
                Text(
                  _chosen!.help!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // Said on the form, before they write it. Somebody asking for a
              // photograph of their child to come down should not have to
              // wonder whether this is the right place.
              if (_chosen?.isUrgent ?? false) ...<Widget>[
                const Gap.md(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.priority_high, size: 18),
                      const Gap.hMd(),
                      Expanded(
                        child: Text(
                          'This goes to the top of the administrators’ queue, and you do not '
                          'need an account to ask. You will not be asked to explain why.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Gap.xl(),
            ],

            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Your name'),
              validator: (String? value) =>
                  (value ?? '').trim().length < 2 ? 'Please tell us your name.' : null,
            ),
            const Gap.md(),
            Text('How should we reply?', style: theme.textTheme.titleSmall),
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children:
                  (_channels.isEmpty
                          ? const <({String value, String label})>[
                              (value: 'whatsapp', label: 'WhatsApp'),
                              (value: 'phone', label: 'A phone call'),
                              (value: 'email', label: 'Email'),
                              (value: 'none', label: 'No reply needed'),
                            ]
                          : _channels)
                      .map(
                        (({String value, String label}) channel) => ChoiceChip(
                          label: Text(channel.label),
                          selected: _reply == channel.value,
                          onSelected: (_) => setState(() => _reply = channel.value),
                        ),
                      )
                      .toList(growable: false),
            ),
            const Gap.lg(),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: _reply == 'whatsapp' || _reply == 'phone'
                          ? 'Your number'
                          : 'Phone or WhatsApp (optional)',
                    ),
                  ),
                ),
                const Gap.hMd(),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _reply == 'email' ? 'Your email' : 'Email (optional)',
                    ),
                  ),
                ),
              ],
            ),
            const Gap.md(),
            TextFormField(
              controller: _subject,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Subject (optional)'),
            ),
            TextFormField(
              controller: _message,
              minLines: 5,
              maxLines: 12,
              maxLength: 8000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your message',
                alignLabelWithHint: true,
                helperText: 'If it is about a particular page, say which one.',
              ),
              validator: (String? value) => (value ?? '').trim().length < 10
                  ? 'Please write a little more so we can help.'
                  : null,
            ),

            if (_error != null) ...<Widget>[
              const Gap.md(),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const Gap.lg(),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: const Text('Send it'),
                ),
                const Gap.hLg(),
                Flexible(
                  child: Text(
                    'We read everything that arrives.',
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
    );
  }
}

/// The reference, shown large, because it is the only way somebody without an
/// account can ask what happened to what they wrote.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.receipt});

  final ({String reference, String message}) receipt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.check_circle_outline, color: AppColors.green),
              const Gap.hMd(),
              Text('Sent', style: theme.textTheme.titleLarge),
            ],
          ),
          const Gap.md(),
          Text(receipt.message, style: theme.textTheme.bodyLarge),
          const Gap.xl(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: AppRadius.smAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('YOUR REFERENCE', style: theme.textTheme.labelSmall),
                const Gap.sm(),
                SelectableText(
                  receipt.reference,
                  style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2),
                ),
              ],
            ),
          ),
          const Gap.lg(),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Back to the archive'),
          ),
        ],
      ),
    );
  }
}
