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
import '../../models/member.dart';
import '../../repositories/member_repository.dart';

/// PRIVACY.
///
/// A page of its own rather than a section of the profile editor, because
/// changing what the world knows about you is a different act from correcting
/// your job title, and it should not happen as a side effect of saving a form.
///
/// Every switch says what it does in plain words and takes effect immediately.
/// Nothing here is phrased as a benefit of turning something on — the honest
/// framing is that these are all off, and each one is a decision to share
/// something.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MemberRepository repository = context.read<MemberRepository>();

    return AppScaffold(
      currentPath: AppRoutes.accountPrivacy,
      seo: const SeoMetadata(
        title: 'Privacy',
        canonicalPath: AppRoutes.accountPrivacy,
        noIndex: true,
      ),
      child: PageSection(
        eyebrow: 'Your account',
        title: 'Who can see what',
        description:
            'Everything sensitive is off until you turn it on. Turning something off takes effect '
            'straight away.',
        child: AsyncContent<({MemberProfile profile, MembershipOptions options})>(
          load: () async {
            final List<Object> results = await Future.wait<Object>(<Future<Object>>[
              repository.me(),
              repository.options(),
            ]);
            return (
              profile: results[0] as MemberProfile,
              options: results[1] as MembershipOptions,
            );
          },
          loadingMessage: 'Opening your settings…',
          builder: (
            BuildContext context,
            ({MemberProfile profile, MembershipOptions options}) data,
          ) =>
              _PrivacyForm(profile: data.profile, options: data.options),
        ),
      ),
    );
  }
}

class _PrivacyForm extends StatefulWidget {
  const _PrivacyForm({required this.profile, required this.options});

  final MemberProfile profile;
  final MembershipOptions options;

  @override
  State<_PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends State<_PrivacyForm> {
  late String _visibility;
  late bool _showContact;
  late bool _showEmployment;
  late bool _showLocation;
  late bool _showEducation;
  late bool _listed;
  late String _messagesFrom;
  late bool _findableForMessages;
  late bool _notifyOpportunities;
  late bool _notifyForum;
  late bool _notifyCommunity;

  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final MemberProfile p = widget.profile;
    _visibility = p.profileVisibility;
    _showContact = p.showContact;
    _showEmployment = p.showEmployment;
    _showLocation = p.showLocation;
    _showEducation = p.showEducation;
    _listed = p.listedInDirectory;
    _messagesFrom = p.messagesFrom;
    _findableForMessages = p.findableForMessages;
    _notifyOpportunities = p.notifyOpportunities;
    _notifyForum = p.notifyForum;
    _notifyCommunity = p.notifyCommunity;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });

    try {
      await context.read<MemberRepository>().updatePrivacy(
            profileVisibility: _visibility,
            showContact: _showContact,
            showEmployment: _showEmployment,
            showLocation: _showLocation,
            showEducation: _showEducation,
            listedInDirectory: _listed,
            messagesFrom: _messagesFrom,
            findableForMessages: _findableForMessages,
            notifyOpportunities: _notifyOpportunities,
            notifyForum: _notifyForum,
            notifyCommunity: _notifyCommunity,
          );
      if (mounted) setState(() => _saved = true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Panel(
          title: 'Your profile',
          description: 'Who can open your page at all.',
          // The group owns the selection; each tile only declares its value.
          child: RadioGroup<String>(
            groupValue: _visibility,
            onChanged: (String? value) => setState(() => _visibility = value ?? _visibility),
            child: Column(
              children: widget.options.visibilities
                  .map(
                    (LabelledChoice choice) => RadioListTile<String>(
                      value: choice.value,
                      title: Text(choice.label),
                      subtitle: choice.description == null ? null : Text(choice.description!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),

        _Panel(
          title: 'What appears on it',
          description: 'Each of these is off until you turn it on.',
          child: Column(
            children: <Widget>[
              _Switch(
                value: _showContact,
                onChanged: (bool v) => setState(() => _showContact = v),
                title: 'Phone number and email',
                subtitle: 'Off by default. Turning it on shows them to anybody who can see your '
                    'profile.',
              ),
              _Switch(
                value: _showEmployment,
                onChanged: (bool v) => setState(() => _showEmployment = v),
                title: 'Your work situation',
                // The exception matters and is stated here rather than buried:
                // this switch cannot publish that somebody is out of work, and
                // a member deciding whether to flip it deserves to know that.
                subtitle: 'Even turned on, the platform never shows that you are seeking work or '
                    'not working. Only working, studying or retired is ever shown.',
              ),
              _Switch(
                value: _showLocation,
                onChanged: (bool v) => setState(() => _showLocation = v),
                title: 'Where you are',
                subtitle: 'Your community, state and country. Not a street address — the platform '
                    'does not hold one.',
              ),
              _Switch(
                value: _showEducation,
                onChanged: (bool v) => setState(() => _showEducation = v),
                title: 'Your education',
                subtitle: 'Level, field and institution.',
              ),
            ],
          ),
        ),

        _Panel(
          title: 'The Yakoli directory',
          description:
              'The directory is how another member finds somebody who can do what you can do — a '
              'teacher in Lagos, a farmer in Cross River, a developer in Abuja.',
          child: _Switch(
            value: _listed,
            onChanged: (bool v) => setState(() => _listed = v),
            title: 'List me in the Yakoli directory',
            subtitle: 'Off by default. Being findable by profession is a decision, not a '
                'consequence of joining — and you can turn it off again at any time.',
          ),
        ),

        _Panel(
          title: 'Messages',
          description:
              'Members can write to you here without ever seeing your phone number or your '
              'email. Those stay hidden unless you switch them on above, or somebody asks and '
              'you say yes — and you can take that back at any time.',
          child: Column(
            children: <Widget>[
              _Switch(
                value: _findableForMessages,
                onChanged: (bool v) => setState(() => _findableForMessages = v),
                title: 'Let members find me by name',
                subtitle: 'How somebody who remembers your name reaches you. This is separate '
                    'from the directory: you can be findable without being listed.',
              ),
              _Switch(
                value: _messagesFrom == 'members',
                onChanged: (bool v) => setState(() => _messagesFrom = v ? 'members' : 'nobody'),
                title: 'Let members write to me',
                subtitle: 'Turn this off and nobody can start a new conversation with you. '
                    'Conversations you are already in keep working.',
              ),
              const Gap.md(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(AppRoutes.accountRequests),
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('Who has asked for my details'),
                ),
              ),
            ],
          ),
        ),

        _Panel(
          title: 'What we tell you about',
          description: 'Notifications reach you here, on this site.',
          child: Column(
            children: <Widget>[
              _Switch(
                value: _notifyOpportunities,
                onChanged: (bool v) => setState(() => _notifyOpportunities = v),
                title: 'Opportunities that match you',
                subtitle: 'Jobs, scholarships and training matching your skills and where you are.',
              ),
              _Switch(
                value: _notifyForum,
                onChanged: (bool v) => setState(() => _notifyForum = v),
                title: 'Replies in the forums',
                subtitle: 'When somebody replies to you or to a discussion you follow.',
              ),
              _Switch(
                value: _notifyCommunity,
                onChanged: (bool v) => setState(() => _notifyCommunity = v),
                title: 'Community announcements',
                subtitle: 'Occasional, and only from the Preservation Team.',
              ),
            ],
          ),
        ),

        if (_error != null) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          const Gap.lg(),
        ],

        Row(
          children: <Widget>[
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save these settings'),
            ),
            if (_saved) ...<Widget>[
              const Gap.hMd(),
              const Icon(Icons.check, size: 16, color: AppColors.green),
              const Gap.hSm(),
              Text(
                'Saved',
                style: theme.textTheme.labelMedium?.copyWith(color: AppColors.greenDark),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.account),
              child: const Text('Back to your account'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.description});

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          if (description != null) ...<Widget>[
            const Gap.xs(),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Gap.lg(),
          child,
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: subtitle.length > 70,
    );
  }
}
