import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/people_repository.dart';
import '../../services/api/mime_types.dart';
import '../../services/auth/auth_controller.dart';

/// CONTRIBUTING A PERSON — A PROFILE BUILDER.
///
/// The People section holds structured records: a name, a headline, a
/// profession, a biography, achievements, where somebody is, a photograph.
/// Contributing one used to go through the generic contribution form — a title,
/// a description and a file — so everything that made the record useful arrived
/// as one paragraph of prose, and most of it arrived not at all. Nobody thinks
/// to mention a birth year in a box labelled "description".
///
/// This asks for the fields the destination actually has, and it takes a
/// photograph and a short film.
///
/// ---------------------------------------------------------------------------
/// THE CONSENT QUESTION IS NOT A FORMALITY, AND IT IS NOT LAST
/// ---------------------------------------------------------------------------
///
/// Most of this archive is about places, practices and things. This is about
/// named people, many of them alive. A community archive that publishes a
/// biography of somebody who never agreed to it has done something TO them
/// rather than FOR them.
///
/// So the question sits in the middle of the form where it will be read, not
/// buried at the bottom as a tick-box, and the reviewer sees the answer before
/// they see anything else.
class ContributePersonPage extends StatefulWidget {
  const ContributePersonPage({super.key});

  @override
  State<ContributePersonPage> createState() => _ContributePersonPageState();
}

class _ContributePersonPageState extends State<ContributePersonPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _alsoKnownAs = TextEditingController();
  final TextEditingController _headline = TextEditingController();
  final TextEditingController _profession = TextEditingController();
  final TextEditingController _biography = TextEditingController();
  final TextEditingController _achievement = TextEditingController();
  final TextEditingController _birthYear = TextEditingController();
  final TextEditingController _deathYear = TextEditingController();
  final TextEditingController _communityArea = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _connection = TextEditingController();
  final TextEditingController _whyNotable = TextEditingController();
  final TextEditingController _consentNote = TextEditingController();
  final TextEditingController _relationship = TextEditingController();

  final List<String> _achievements = <String>[];

  String _category = 'elder';
  String _consentBasis = 'person_agreed';
  bool? _isLiving = true;

  _Attachment? _photo;
  _Attachment? _video;

  bool _busy = false;
  String? _error;
  String? _reference;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name, _alsoKnownAs, _headline, _profession, _biography, _achievement,
      _birthYear, _deathYear, _communityArea, _city, _country,
      _connection, _whyNotable, _consentNote, _relationship,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------

  Future<void> _pick({required bool video}) async {
    final AccountRepository repository = context.read<AccountRepository>();

    final FilePickerResult? picked = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: video ? UploadExtensions.video : UploadExtensions.images,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final PlatformFile file = picked.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Uploaded straight away, into the submissions area rather than the
      // published archive. Nothing here is public until a reviewer promotes it.
      final String uploadId = await repository.uploadContribution(
        bytes: bytes,
        filename: file.name,
        folder: MediaFolders.heritage,
        caption: 'Profile of ${_name.text.trim().isEmpty ? 'a person' : _name.text.trim()}',
        contributorName: _nameOfContributor(),
      );

      if (!mounted) return;
      setState(() {
        final _Attachment attachment = _Attachment(id: uploadId, filename: file.name);
        if (video) {
          _video = attachment;
        } else {
          _photo = attachment;
        }
      });
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _nameOfContributor() {
    final AuthController auth = context.read<AuthController>();
    return auth.user?.displayName;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String reference = await context.read<PeopleRepository>().submitProfile(<String, dynamic>{
        'name': _name.text.trim(),
        'also_known_as': _trimOrNull(_alsoKnownAs),
        'headline': _trimOrNull(_headline),
        'profession': _trimOrNull(_profession),
        'category': _category,
        'biography': _trimOrNull(_biography),
        'achievements': _achievements,
        'birth_year': int.tryParse(_birthYear.text.trim()),
        'death_year': int.tryParse(_deathYear.text.trim()),
        'is_living': _isLiving,
        'community_area': _trimOrNull(_communityArea),
        'city': _trimOrNull(_city),
        'country': _trimOrNull(_country),
        'connection_to_ekoli': _trimOrNull(_connection),
        'why_notable': _trimOrNull(_whyNotable),
        'consent_basis': _consentBasis,
        'consent_note': _trimOrNull(_consentNote),
        'contributor_relationship': _trimOrNull(_relationship),
        'photo_upload_id': _photo?.id,
        'video_upload_id': _video?.id,
      });

      if (mounted) setState(() => _reference = reference);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _trimOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    return AppScaffold(
      currentPath: AppRoutes.people,
      seo: const SeoMetadata(
        title: 'Add somebody to the archive',
        description:
            'Tell us about somebody from Ekoli-Yeden — an elder, a teacher, a professional, '
            'somebody who did something worth remembering.',
        canonicalPath: AppRoutes.contributePerson,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'People',
        title: 'Add somebody to the archive',
        description:
            'An elder, a teacher, a professional, somebody who did something worth remembering. '
            'Fill in as much as you know — a partial record is worth far more than none, and other '
            'people can add to it later.',
        child: _reference != null
            ? _Submitted(reference: _reference!)
            // Signed in, not the membership flag — see `contribute_page.dart`.
            : !auth.isSignedIn
                ? const _MembersOnly()
                : Form(key: _formKey, child: _buildForm(theme)),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // --- Who ------------------------------------------------------------
        const _SectionHeading(
          title: 'Who they are',
          detail: 'Their name is the only thing that is required.',
        ),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Their full name'),
          validator: (String? v) =>
              (v ?? '').trim().length < 2 ? 'Please give their name.' : null,
        ),
        const Gap.lg(),
        TextFormField(
          controller: _alsoKnownAs,
          decoration: const InputDecoration(
            labelText: 'Also known as (optional)',
            helperText: 'A title, a praise name, the name people actually use.',
          ),
        ),
        const Gap.lg(),
        TextFormField(
          controller: _headline,
          decoration: const InputDecoration(
            labelText: 'One line about them',
            helperText: 'What a visitor reads under their name.',
          ),
        ),
        const Gap.lg(),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _profession,
                decoration: const InputDecoration(labelText: 'What they do or did'),
              ),
            ),
            const Gap.hMd(),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'They are'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'elder', child: Text('An elder')),
                  DropdownMenuItem<String>(value: 'leader', child: Text('A leader')),
                  DropdownMenuItem<String>(value: 'educator', child: Text('An educator')),
                  DropdownMenuItem<String>(value: 'professional', child: Text('A professional')),
                  DropdownMenuItem<String>(value: 'artisan', child: Text('An artisan')),
                  DropdownMenuItem<String>(value: 'artist', child: Text('An artist')),
                  DropdownMenuItem<String>(value: 'religious', child: Text('A religious leader')),
                  DropdownMenuItem<String>(value: 'sports', child: Text('In sport')),
                  DropdownMenuItem<String>(value: 'medicine', child: Text('In medicine')),
                  DropdownMenuItem<String>(value: 'business', child: Text('In business')),
                  DropdownMenuItem<String>(
                    value: 'public_service',
                    child: Text('In public service'),
                  ),
                  DropdownMenuItem<String>(value: 'diaspora', child: Text('Abroad')),
                  DropdownMenuItem<String>(value: 'youth', child: Text('A young person')),
                  DropdownMenuItem<String>(value: 'other', child: Text('Something else')),
                ],
                onChanged: _busy ? null : (String? v) => setState(() => _category = v ?? _category),
              ),
            ),
          ],
        ),

        // --- Pictures -------------------------------------------------------
        const Gap.xxl(),
        const _SectionHeading(
          title: 'A photograph, and a film',
          detail:
              'A photograph makes a person findable in a way a name alone does not. A short film '
              'says more still — an elder speaking is worth more than a paragraph about them.',
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _AttachmentTile(
                icon: Icons.photo_camera_outlined,
                label: 'Photograph',
                attachment: _photo,
                busy: _busy,
                onPick: () => _pick(video: false),
                onClear: () => setState(() => _photo = null),
              ),
            ),
            const Gap.hMd(),
            Expanded(
              child: _AttachmentTile(
                icon: Icons.videocam_outlined,
                label: 'Short film',
                attachment: _video,
                busy: _busy,
                onPick: () => _pick(video: true),
                onClear: () => setState(() => _video = null),
              ),
            ),
          ],
        ),

        // --- Consent --------------------------------------------------------
        // Placed here, in the middle, where it will be read — not buried at the
        // bottom as a tick-box.
        const Gap.xxl(),
        _ConsentSection(
          basis: _consentBasis,
          isLiving: _isLiving,
          note: _consentNote,
          onBasis: (String value) => setState(() => _consentBasis = value),
          onLiving: (bool? value) => setState(() => _isLiving = value),
        ),

        // --- Their life -----------------------------------------------------
        const Gap.xxl(),
        const _SectionHeading(
          title: 'Their life',
          detail: 'Whatever you know. Approximate years are better than none.',
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _birthYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year of birth'),
              ),
            ),
            const Gap.hMd(),
            Expanded(
              child: TextFormField(
                controller: _deathYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year they passed'),
                enabled: _isLiving != true,
              ),
            ),
          ],
        ),
        const Gap.lg(),
        TextFormField(
          controller: _biography,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'About them',
            alignLabelWithHint: true,
            helperText: 'Their story, in your own words.',
          ),
        ),
        const Gap.lg(),
        _AchievementsField(
          controller: _achievement,
          achievements: _achievements,
          onAdd: () {
            final String value = _achievement.text.trim();
            if (value.isEmpty) return;
            setState(() {
              _achievements.add(value);
              _achievement.clear();
            });
          },
          onRemove: (int index) => setState(() => _achievements.removeAt(index)),
        ),

        // --- Where ----------------------------------------------------------
        const Gap.xxl(),
        const _SectionHeading(title: 'Where', detail: null),
        TextFormField(
          controller: _communityArea,
          decoration: const InputDecoration(labelText: 'Where in Ekoli-Yeden they are from'),
        ),
        const Gap.lg(),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City they live in'),
              ),
            ),
            const Gap.hMd(),
            Expanded(
              child: TextFormField(
                controller: _country,
                decoration: const InputDecoration(labelText: 'Country'),
              ),
            ),
          ],
        ),
        const Gap.lg(),
        TextFormField(
          controller: _connection,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Their connection to Ekoli-Yeden',
            alignLabelWithHint: true,
            helperText: 'The question this section exists to answer.',
          ),
        ),
        const Gap.lg(),
        TextFormField(
          controller: _whyNotable,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Why they are worth recording',
            alignLabelWithHint: true,
          ),
        ),

        // --- You ------------------------------------------------------------
        const Gap.xxl(),
        const _SectionHeading(
          title: 'And you',
          detail:
              'So the Heritage Team can come back to you with a question. Not published.',
        ),
        TextFormField(
          controller: _relationship,
          decoration: const InputDecoration(
            labelText: 'How do you know them?',
            helperText: '"My grandmother", "he taught me", "I read about him".',
          ),
        ),

        if (_error != null) ...<Widget>[
          const Gap.lg(),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
        ],

        const Gap.xxl(),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const Text('Sending…') : const Text('Send this profile'),
        ),
        const Gap.md(),
        Text(
          'The Heritage Team reads every profile before it is published, and they look at the '
          'consent question first.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Attachment {
  const _Attachment({required this.id, required this.filename});

  final String id;
  final String filename;
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.attachment,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final _Attachment? attachment;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool has = attachment != null;

    return InkWell(
      onTap: busy ? null : (has ? onClear : onPick),
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: has
              ? AppColors.success.withValues(alpha: 0.10)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: has ? AppColors.success.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(has ? Icons.check_circle_outline : icon, size: 26),
            const Gap.sm(),
            Text(label, style: theme.textTheme.titleSmall),
            const Gap.xs(),
            Text(
              has ? attachment!.filename : 'Choose a file',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (has) ...<Widget>[
              const Gap.xs(),
              Text('Tap to remove', style: theme.textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// The consent question, given the weight it deserves.
class _ConsentSection extends StatelessWidget {
  const _ConsentSection({
    required this.basis,
    required this.isLiving,
    required this.note,
    required this.onBasis,
    required this.onLiving,
  });

  final String basis;
  final bool? isLiving;
  final TextEditingController note;
  final ValueChanged<String> onBasis;
  final ValueChanged<bool?> onLiving;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('May we publish this?', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          Text(
            'If this person is alive, please only send what they are happy to have published. A '
            'community archive that publishes a biography of somebody who never agreed to it has '
            'done something to them rather than for them — so we ask, and we do not guess.',
            style: theme.textTheme.bodyMedium,
          ),
          const Gap.lg(),
          Text('Are they living?', style: theme.textTheme.labelLarge),
          const Gap.sm(),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              ChoiceChip(
                selected: isLiving == true,
                label: const Text('Yes'),
                onSelected: (bool _) => onLiving(true),
              ),
              ChoiceChip(
                selected: isLiving == false,
                label: const Text('They have passed on'),
                onSelected: (bool _) => onLiving(false),
              ),
              ChoiceChip(
                selected: isLiving == null,
                label: const Text('I do not know'),
                onSelected: (bool _) => onLiving(null),
              ),
            ],
          ),
          const Gap.lg(),
          DropdownButtonFormField<String>(
            initialValue: basis,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'On what basis?'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'person_agreed',
                child: Text('They are happy for this to be published'),
              ),
              DropdownMenuItem<String>(
                value: 'family_agreed',
                child: Text('Their family agreed'),
              ),
              DropdownMenuItem<String>(
                value: 'public_figure',
                child: Text('They hold public office, or this is already known'),
              ),
              DropdownMenuItem<String>(
                value: 'deceased_historical',
                child: Text('They have passed on — a historical record'),
              ),
              DropdownMenuItem<String>(
                value: 'unspecified',
                child: Text('I am not sure — please check first'),
              ),
            ],
            onChanged: (String? value) => onBasis(value ?? basis),
          ),
          const Gap.md(),
          TextField(
            controller: note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Anything we should know (optional)',
              alignLabelWithHint: true,
              helperText: 'Who to ask, or what they said.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievements, added one at a time so they stay a list rather than a blob.
class _AchievementsField extends StatelessWidget {
  const _AchievementsField({
    required this.controller,
    required this.achievements,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> achievements;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                decoration: const InputDecoration(
                  labelText: 'Something they achieved',
                  helperText: 'One at a time. Press add after each.',
                ),
              ),
            ),
            const Gap.hMd(),
            OutlinedButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
        if (achievements.isNotEmpty) ...<Widget>[
          const Gap.md(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List<Widget>.generate(
              achievements.length,
              (int index) => Chip(
                label: Text(achievements[index]),
                onDeleted: () => onRemove(index),
              ),
            ),
          ),
        ],
        if (achievements.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Nothing added yet — that is fine.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          if (detail != null) ...<Widget>[
            const Gap.xs(),
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Submitted extends StatelessWidget {
  const _Submitted({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Thank you', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          Text(
            'Keep this reference — you can use it to check what happened.',
            style: theme.textTheme.bodyMedium,
          ),
          const Gap.md(),
          SelectableText(
            reference,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2),
          ),
          const Gap.lg(),
          FilledButton(
            onPressed: () => context.go(AppRoutes.people),
            child: const Text('Back to People'),
          ),
        ],
      ),
    );
  }
}

class _MembersOnly extends StatelessWidget {
  const _MembersOnly();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Adding somebody to the archive is for members. A profile is worth what is known about '
          'it, and when we cannot tell who is in a photograph or when something happened, the '
          'only way to find out is to ask whoever sent it.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Gap.xl(),
        FilledButton(
          onPressed: () => context.go(AppRoutes.join),
          child: const Text('Become a member'),
        ),
      ],
    );
  }
}
