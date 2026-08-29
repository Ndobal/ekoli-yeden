import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/api/mime_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../models/member.dart';
import '../../repositories/member_repository.dart';
import '../../repositories/place_repository.dart';
import '../../models/place.dart';

/// FILLING IN THE PROFILE.
///
/// In stages, not as one enormous form. Each stage saves on its own, so a
/// member can answer three questions today and three more next week without
/// losing the first three — which is what actually happens, as opposed to what
/// a single sixty-field form assumes.
///
/// The stages are ordered by what the platform can do with them: identity
/// first, then what you do, then what you can do, then where — because skills
/// and location are what make the opportunities board and the directory work,
/// and a member who stops after two stages should have given the two that
/// matter most.
class ProfileEditorPage extends StatelessWidget {
  const ProfileEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MemberRepository repository = context.read<MemberRepository>();

    return AppScaffold(
      currentPath: AppRoutes.accountProfile,
      seo: const SeoMetadata(
        title: 'Your profile',
        canonicalPath: AppRoutes.accountProfile,
        noIndex: true,
      ),
      child: PageSection(
        eyebrow: 'Your account',
        title: 'Your profile',
        description:
            'Each section saves on its own. Fill in what you like now and the rest whenever — '
            'nothing is lost in between.',
        child: AsyncContent<({MemberProfile profile, MembershipOptions options})>(
          load: () async {
            // Both at once: the form cannot draw its pickers without the
            // vocabulary, and cannot fill them in without the profile.
            final List<Object> results = await Future.wait<Object>(<Future<Object>>[
              repository.me(),
              repository.options(),
            ]);
            return (
              profile: results[0] as MemberProfile,
              options: results[1] as MembershipOptions,
            );
          },
          loadingMessage: 'Opening your profile…',
          builder: (
            BuildContext context,
            ({MemberProfile profile, MembershipOptions options}) data,
          ) =>
              _Editor(profile: data.profile, options: data.options),
        ),
      ),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({required this.profile, required this.options});

  final MemberProfile profile;
  final MembershipOptions options;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final TextEditingController _fullName;
  late final TextEditingController _headline;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _country;
  late final TextEditingController _state;
  late final TextEditingController _lga;
  late final TextEditingController _community;
  late final TextEditingController _city;
  late final TextEditingController _placeText;
  late final TextEditingController _clan;
  late final TextEditingController _connectionNote;
  late final TextEditingController _professionOther;
  late final TextEditingController _employer;
  late final TextEditingController _educationField;
  late final TextEditingController _institution;
  late final TextEditingController _years;

  String? _connection;
  String? _relationship;
  String? _professionId;
  String? _educationLevel;
  String? _employmentStatus;
  bool _openToOpportunities = false;
  bool _openToMentoring = false;
  DateTime? _birthDate;
  bool _showBirthday = false;
  bool _birthdayWishes = true;
  bool _showAge = false;
  final TextEditingController _mentoringNote = TextEditingController();

  late List<MemberSkillEntry> _skills;
  late Set<String> _interests;

  String? _savingStage;
  String? _savedStage;
  String? _error;

  @override
  void initState() {
    super.initState();
    final MemberProfile p = widget.profile;

    _fullName = TextEditingController(text: p.fullName ?? '');
    _headline = TextEditingController(text: p.headline ?? '');
    _bio = TextEditingController(text: p.bio ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _whatsapp = TextEditingController(text: p.whatsappNumber ?? '');
    _country = TextEditingController(text: p.country ?? '');
    _state = TextEditingController(text: p.stateRegion ?? '');
    _lga = TextEditingController(text: p.lga ?? '');
    _community = TextEditingController(text: p.communityArea ?? '');
    _city = TextEditingController(text: p.city ?? '');
    _placeText = TextEditingController(text: p.placeText ?? '');
    _clan = TextEditingController(text: p.clan ?? '');
    _connectionNote = TextEditingController(text: p.connectionNote ?? '');
    _professionOther = TextEditingController(text: p.professionOther ?? '');
    _employer = TextEditingController(text: p.employer ?? '');
    _educationField = TextEditingController(text: p.educationField ?? '');
    _institution = TextEditingController(text: p.institution ?? '');
    _years = TextEditingController(text: p.yearsExperience?.toString() ?? '');

    _connection = p.connection;
    _relationship = p.relationship;
    _professionId = p.professionId;
    _educationLevel = p.educationLevel;
    _employmentStatus = p.employmentStatus;
    _openToOpportunities = p.openToOpportunities;
    _openToMentoring = p.openToMentoring;
    _birthDate = DateTime.tryParse(p.birthDate ?? '');
    _showBirthday = p.showBirthday;
    _birthdayWishes = p.birthdayWishesEnabled;
    _showAge = p.showAge;
    _mentoringNote.text = p.mentoringNote ?? '';

    _skills = p.skills
        .map(
          (MemberSkill skill) => MemberSkillEntry(
            skillId: skill.id,
            proficiency: skill.proficiency,
            years: skill.years,
          ),
        )
        .toList();
    _interests = p.interests.map((MemberInterest interest) => interest.id).toSet();
  }

  @override
  void dispose() {
    _mentoringNote.dispose();
    for (final TextEditingController controller in <TextEditingController>[
      _fullName, _headline, _bio, _phone, _whatsapp, _country, _state, _lga,
      _community, _city, _placeText, _clan, _connectionNote, _professionOther,
      _employer, _educationField, _institution, _years,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String stage, Future<void> Function() action) async {
    setState(() {
      _savingStage = stage;
      _savedStage = null;
      _error = null;
    });

    try {
      await action();
      if (mounted) setState(() => _savedStage = stage);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _savingStage = null);
    }
  }

  String? _text(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  MemberRepository get _repository => context.read<MemberRepository>();

  static const List<String> _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _readableDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_error != null) ...<Widget>[
          _ErrorBanner(message: _error!),
          const Gap.xl(),
        ],

        // First, because it is the part of a profile people fill in first and
        // the part that makes the rest feel worth filling in.
        _ProfilePhotos(
          avatarUrl: widget.profile.avatarUrl,
          coverUrl: widget.profile.coverUrl,
          name: widget.profile.name,
        ),
        const Gap.xxl(),

        // --- Who you are ---------------------------------------------------
        _Stage(
          number: 1,
          title: 'Who you are',
          description: 'The only part anybody sees by default.',
          saving: _savingStage == 'identity',
          saved: _savedStage == 'identity',
          onSave: () => _save('identity', () async {
            await _repository.updateProfile(<String, dynamic>{
              'full_name': _text(_fullName),
              'headline': _text(_headline),
              'bio': _text(_bio),
            });
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const Gap.lg(),
              TextField(
                controller: _headline,
                decoration: const InputDecoration(
                  labelText: 'One line about you',
                  helperText: 'For example: Civil engineer, Calabar. Shown under your name.',
                ),
              ),
              const Gap.lg(),
              TextField(
                controller: _bio,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'About you',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),

        // --- Where you are -------------------------------------------------
        _Stage(
          number: 2,
          title: 'Where you are',
          description:
              'Opportunities are shown nearest first — Ekoli-Yeden, then Yakurr, then Cross River, '
              'then Nigeria. Without a location you get the far ones too.',
          saving: _savingStage == 'location',
          saved: _savedStage == 'location',
          onSave: () => _save('location', () async {
            await _repository.updateProfile(<String, dynamic>{
              'country': _text(_country),
              'state_region': _text(_state),
              'lga': _text(_lga),
              'community_area': _text(_community),
              'city': _text(_city),
              'place_text': _text(_placeText),
              'clan': _text(_clan),
              'connection': _connection,
              'relationship': _relationship,
              'connection_note': _text(_connectionNote),
            });
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _field(_country, 'Country', width: 200),
                  _field(_state, 'State', width: 200),
                  _field(_lga, 'Local government area', width: 240),
                  _field(_city, 'City or town', width: 200),
                  _field(
                    _community,
                    'Community or quarter',
                    width: 240,
                    helper: 'Put Ekoli-Yeden here if you are here.',
                  ),
                ],
              ),
              const Gap.xl(),
              _WhereInEkori(place: _placeText, clan: _clan),
              const Gap.xl(),

              // THE PRIMARY IDENTITY QUESTION.
              //
              // What somebody IS to Ekoli-Yeden, asked separately from what
              // they DO on the platform. The second is a role a Super Admin
              // assigns; this is theirs to answer, and it grants nothing.
              Builder(
                builder: (BuildContext context) => Text(
                  context.cmsWatch(
                    'profile.relationship.question',
                    fallback: 'What is your relationship to Ekoli-Yeden?',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Gap.md(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: widget.options.relationships
                    .map(
                      (LabelledChoice choice) => ChoiceChip(
                        label: Text(choice.label),
                        selected: _relationship == choice.value,
                        onSelected: (bool selected) => setState(
                          () => _relationship = selected ? choice.value : null,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const Gap.sm(),
              Builder(
                builder: (BuildContext context) => Text(
                  'This is how the community places you, and it is what the Indigene Directory '
                  'lists by. It gives you no extra permission on the site — what you can do '
                  'here is a separate thing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const Gap.xl(),
              DropdownButtonFormField<String?>(
                initialValue: _connection,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'How, in more detail (optional)',
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Not said')),
                  ...widget.options.connections.map(
                    (LabelledChoice choice) => DropdownMenuItem<String?>(
                      value: choice.value,
                      child: Text(choice.label),
                    ),
                  ),
                ],
                onChanged: (String? value) => setState(() => _connection = value),
              ),
              if (_connection == 'other') ...<Widget>[
                const Gap.md(),
                TextField(
                  controller: _connectionNote,
                  decoration: const InputDecoration(labelText: 'Tell us how'),
                ),
              ],
            ],
          ),
        ),

        // --- What you do ----------------------------------------------------
        _Stage(
          number: 3,
          title: 'What you do',
          description: 'What lets somebody looking for your trade find you.',
          saving: _savingStage == 'work',
          saved: _savedStage == 'work',
          onSave: () => _save('work', () async {
            await _repository.updateProfile(<String, dynamic>{
              'profession_id': _professionId,
              'profession_other': _text(_professionOther),
              'employer': _text(_employer),
              'years_experience': int.tryParse(_years.text.trim()),
              'education_level': _educationLevel,
              'education_field': _text(_educationField),
              'institution': _text(_institution),
            });
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String?>(
                initialValue: _professionId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Profession'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Not said')),
                  ...widget.options.professions.map(
                    (Profession profession) => DropdownMenuItem<String?>(
                      value: profession.id,
                      child: Text(profession.name),
                    ),
                  ),
                ],
                onChanged: (String? value) => setState(() => _professionId = value),
              ),
              if (_professionId == 'prof_other' || _professionId == null) ...<Widget>[
                const Gap.md(),
                TextField(
                  controller: _professionOther,
                  decoration: const InputDecoration(
                    labelText: 'Or write it yourself',
                    helperText: 'If your trade is not on the list.',
                  ),
                ),
              ],
              const Gap.lg(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _field(_employer, 'Employer or business', width: 260),
                  _field(_years, 'Years of experience', width: 180, number: true),
                ],
              ),
              const Gap.lg(),
              DropdownButtonFormField<String?>(
                initialValue: _educationLevel,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Education'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Not said')),
                  ...widget.options.educationLevels.map(
                    (LabelledChoice choice) => DropdownMenuItem<String?>(
                      value: choice.value,
                      child: Text(choice.label),
                    ),
                  ),
                ],
                onChanged: (String? value) => setState(() => _educationLevel = value),
              ),
              const Gap.md(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _field(_educationField, 'Field of study', width: 240),
                  _field(_institution, 'Institution', width: 240),
                ],
              ),
            ],
          ),
        ),

        // --- Your work situation --------------------------------------------
        _Stage(
          number: 4,
          title: 'Your current work situation',
          description:
              'Used to match you to opportunities and to plan community development. It is never '
              'shown publicly unless you turn it on — and the platform does not publish that '
              'anybody is out of work, whatever the setting says.',
          saving: _savingStage == 'employment',
          saved: _savedStage == 'employment',
          onSave: () => _save('employment', () async {
            await _repository.updateProfile(<String, dynamic>{
              'employment_status': _employmentStatus,
              'open_to_opportunities': _openToOpportunities,
              'open_to_mentoring': _openToMentoring,
              // Sent as a plain date; the Worker derives the day and month and
              // keeps the year out of anything public.
              'birth_date': _birthDate?.toIso8601String().split('T').first,
              'show_birthday': _showBirthday,
              'birthday_wishes_enabled': _birthdayWishes,
              'show_age': _showAge,
              'mentoring_note': _mentoringNote.text.trim(),
            });
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // A radio list rather than a dropdown: these are ten real
              // situations and somebody should be able to see them all and
              // recognise themselves, not hunt through a collapsed menu.
              RadioGroup<String?>(
                groupValue: _employmentStatus,
                onChanged: (String? value) => setState(() => _employmentStatus = value),
                child: Column(
                  children: widget.options.employmentStatuses
                      .map(
                        (LabelledChoice choice) => RadioListTile<String?>(
                          value: choice.value,
                          title: Text(choice.label),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const Gap.lg(),
              const Gap.xxl(),
              Text('Your birthday', style: theme.textTheme.titleMedium),
              const Gap.xs(),
              Text(
                'The day and month let the community wish you a happy birthday. The year is '
                'never shown to anybody — it is only used to work out which age grade you '
                'belong to.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Gap.md(),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _birthDate == null ? 'Not given' : _readableDate(_birthDate!),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    if (_birthDate != null)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _birthDate = null),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(_birthDate == null ? 'Choose' : 'Change'),
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime(now.year - 30),
                          firstDate: DateTime(now.year - 110),
                          lastDate: now,
                          helpText: 'Your date of birth',
                        );
                        if (picked != null) setState(() => _birthDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              if (_birthDate != null) ...<Widget>[
                const Gap.sm(),
                SwitchListTile(
                  value: _showBirthday,
                  onChanged: (bool value) => setState(() => _showBirthday = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Let the community know when it is my birthday'),
                  subtitle: const Text('Your day and month only, never the year.'),
                ),
                if (_showBirthday)
                  SwitchListTile(
                    value: _birthdayWishes,
                    onChanged: (bool value) => setState(() => _birthdayWishes = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow members to leave me a birthday message'),
                  ),
                SwitchListTile(
                  value: _showAge,
                  onChanged: (bool value) => setState(() => _showAge = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show my age on my profile'),
                  subtitle: const Text(
                    'Separate from the switch above — you can be wished a happy birthday '
                    'without publishing your age.',
                  ),
                ),
              ],
              SwitchListTile(
                value: _openToOpportunities,
                onChanged: (bool value) => setState(() => _openToOpportunities = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Tell me about opportunities'),
                subtitle: const Text(
                  'Separate from the answer above — somebody in full-time work may still want to '
                  'hear about a scholarship.',
                ),
              ),

              // §14 of the proposal. The opposite direction to the switch
              // above: that one asks what you would like to receive, this one
              // offers what you are willing to give.
              SwitchListTile(
                value: _openToMentoring,
                onChanged: (bool value) => setState(() => _openToMentoring = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('I am willing to mentor young people from Ekori'),
                subtitle: const Text(
                  'Shown on your profile and searchable in the directory, so a student from '
                  'Ekori can find somebody doing what they want to do.',
                ),
              ),
              if (_openToMentoring) ...<Widget>[
                const Gap.sm(),
                TextFormField(
                  controller: _mentoringNote,
                  maxLength: 400,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What you can help with',
                    hintText:
                        'For example: choosing a course, applying to university abroad, '
                        'getting started in nursing, or writing a first CV.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ],
          ),
        ),

        // --- What you can do -------------------------------------------------
        _Stage(
          number: 5,
          title: 'What you can do',
          description:
              'The part that makes the opportunities board work. Skills are what an opportunity is '
              'matched against — without them, nothing will find you.',
          saving: _savingStage == 'skills',
          saved: _savedStage == 'skills',
          onSave: () => _save('skills', () async {
            await _repository.setSkills(_skills);
            await _repository.setInterests(_interests.toList());
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SkillPicker(
                options: widget.options,
                selected: _skills,
                onChanged: (List<MemberSkillEntry> skills) => setState(() => _skills = skills),
              ),
              const Gap.xxl(),
              Text('Interested in', style: Theme.of(context).textTheme.titleSmall),
              const Gap.sm(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: widget.options.interests
                    .map(
                      (MemberInterest interest) => FilterChip(
                        label: Text(interest.name),
                        selected: _interests.contains(interest.id),
                        onSelected: (bool selected) => setState(() {
                          if (selected) {
                            _interests.add(interest.id);
                          } else {
                            _interests.remove(interest.id);
                          }
                        }),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),

        // --- Contact ---------------------------------------------------------
        _Stage(
          number: 6,
          title: 'How to reach you',
          description:
              'Hidden from everybody unless you turn contact details on in your privacy settings. '
              'Stored so the Preservation Team can reach you if they need to.',
          saving: _savingStage == 'contact',
          saved: _savedStage == 'contact',
          onSave: () => _save('contact', () async {
            await _repository.updateProfile(<String, dynamic>{
              'phone': _text(_phone),
              'whatsapp_number': _text(_whatsapp),
            });
          }),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _field(_phone, 'Phone number', width: 240),
              _field(_whatsapp, 'WhatsApp number', width: 240, helper: 'If it differs.'),
            ],
          ),
        ),

        const Gap.xxl(),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.account),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to your account'),
            ),
            const Gap.hMd(),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.accountPrivacy),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Privacy settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required double width,
    String? helper,
    bool number = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
    );
  }
}

/// One stage of the profile, with its own save button.
///
/// Each stage saving independently is the whole point: a member is never in a
/// position where answering one more question means losing the last six.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.number,
    required this.title,
    required this.child,
    required this.onSave,
    required this.saving,
    required this.saved,
    this.description,
  });

  final int number;
  final String title;
  final String? description;
  final Widget child;
  final VoidCallback onSave;
  final bool saving;
  final bool saved;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.navy.withValues(alpha: 0.10),
                child: Text(
                  '$number',
                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.navy),
                ),
              ),
              const Gap.hMd(),
              Expanded(
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
                  ],
                ),
              ),
            ],
          ),
          const Gap.xl(),
          child,
          const Gap.xl(),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save this section'),
              ),
              if (saved) ...<Widget>[
                const Gap.hMd(),
                Row(
                  children: <Widget>[
                    const Icon(Icons.check, size: 16, color: AppColors.green),
                    const Gap.hSm(),
                    Text(
                      'Saved',
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.greenDark),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Choosing skills.
///
/// Grouped by category and searchable, because the vocabulary will grow past
/// the point where a flat list of checkboxes is navigable. A skill the list
/// does not have can be typed in — the server adds it rather than refusing,
/// since the community knows its own trades better than a seed list does.
class _SkillPicker extends StatefulWidget {
  const _SkillPicker({required this.options, required this.selected, required this.onChanged});

  final MembershipOptions options;
  final List<MemberSkillEntry> selected;
  final ValueChanged<List<MemberSkillEntry>> onChanged;

  @override
  State<_SkillPicker> createState() => _SkillPickerState();
}

class _SkillPickerState extends State<_SkillPicker> {
  final TextEditingController _custom = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  bool _isSelected(String skillId) =>
      widget.selected.any((MemberSkillEntry entry) => entry.skillId == skillId);

  void _toggle(MemberSkill skill) {
    final List<MemberSkillEntry> next = List<MemberSkillEntry>.from(widget.selected);
    if (_isSelected(skill.id)) {
      next.removeWhere((MemberSkillEntry entry) => entry.skillId == skill.id);
    } else {
      next.add(MemberSkillEntry(skillId: skill.id));
    }
    widget.onChanged(next);
  }

  void _addCustom() {
    final String name = _custom.text.trim();
    if (name.isEmpty) return;
    widget.onChanged(<MemberSkillEntry>[...widget.selected, MemberSkillEntry(name: name)]);
    _custom.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, List<MemberSkill>> grouped = widget.options.skillsByCategory;

    final List<MemberSkillEntry> custom = widget.selected
        .where((MemberSkillEntry entry) => entry.skillId == null && entry.name != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          onChanged: (String value) => setState(() => _search = value.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Search skills',
            prefixIcon: Icon(Icons.search, size: 20),
            isDense: true,
          ),
        ),
        const Gap.lg(),
        ...grouped.entries.map((MapEntry<String, List<MemberSkill>> entry) {
          final List<MemberSkill> visible = _search.isEmpty
              ? entry.value
              : entry.value
                  .where((MemberSkill skill) => skill.name.toLowerCase().contains(_search))
                  .toList();
          if (visible.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.key, style: theme.textTheme.labelMedium),
                const Gap.sm(),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: visible
                      .map(
                        (MemberSkill skill) => FilterChip(
                          label: Text(skill.name),
                          selected: _isSelected(skill.id),
                          onSelected: (_) => _toggle(skill),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          );
        }),

        if (custom.isNotEmpty) ...<Widget>[
          Text('Your own', style: theme.textTheme.labelMedium),
          const Gap.sm(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: custom
                .map(
                  (MemberSkillEntry entry) => InputChip(
                    label: Text(entry.name!),
                    onDeleted: () => widget.onChanged(
                      widget.selected.where((MemberSkillEntry e) => e != entry).toList(),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const Gap.lg(),
        ],

        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _custom,
                onSubmitted: (_) => _addCustom(),
                decoration: const InputDecoration(
                  labelText: 'Something not on the list',
                  isDense: true,
                  helperText: 'Add your own. It becomes available to everybody else too.',
                ),
              ),
            ),
            const Gap.hMd(),
            OutlinedButton(onPressed: _addCustom, child: const Text('Add')),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}

/// "Where in Ekori are you from?"
///
/// ---------------------------------------------------------------------------
/// FREE TEXT, WITH SUGGESTIONS — NEVER A DROPDOWN ALONE
/// ---------------------------------------------------------------------------
///
/// No list anybody writes will contain every compound in Ekori. A member whose
/// home is missing from a picker will choose the wrong thing or give up, and
/// both answers are worse than the one they would have typed.
///
/// So the field takes anything. The suggestions are a convenience that stops
/// four spellings of one compound appearing, and the words are kept exactly as
/// typed whether they matched anything or not. A name two different people give
/// becomes a real place on its own — which is how this list grows without
/// anybody having to maintain it.
class _WhereInEkori extends StatefulWidget {
  const _WhereInEkori({required this.place, required this.clan});

  final TextEditingController place;
  final TextEditingController clan;

  @override
  State<_WhereInEkori> createState() => _WhereInEkoriState();
}

class _WhereInEkoriState extends State<_WhereInEkori> {
  final FocusNode _focus = FocusNode();
  List<Place> _places = const <Place>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Suggestions only. A failure here leaves a plain text field, which is the
  /// field that matters.
  Future<void> _load() async {
    try {
      final List<Place> places = await context.read<PlaceRepository>().all();
      if (mounted) setState(() => _places = places);
    } on AppException {
      // Left empty on purpose.
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Where in Ekori are you from?', style: theme.textTheme.titleSmall),
        const Gap.xs(),
        Text(
          'Your ward, your quarter, or your compound — whichever is how you would answer if '
          'somebody asked you at home. Type it even if it is not offered below.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: RawAutocomplete<Place>(
                textEditingController: widget.place,
                focusNode: _focus,
                displayStringForOption: (Place place) => place.name,
                optionsBuilder: (TextEditingValue value) {
                  final String typed = value.text.trim().toLowerCase();
                  if (typed.isEmpty) return const Iterable<Place>.empty();
                  return _places.where(
                    (Place place) =>
                        place.name.toLowerCase().contains(typed) ||
                        (place.path ?? '').toLowerCase().contains(typed),
                  );
                },
                fieldViewBuilder:
                    (
                      BuildContext context,
                      TextEditingController controller,
                      FocusNode node,
                      VoidCallback onSubmitted,
                    ) => TextField(
                      controller: controller,
                      focusNode: node,
                      onSubmitted: (_) => onSubmitted(),
                      decoration: const InputDecoration(
                        labelText: 'Your place in Ekori',
                        hintText: 'Ajere · Edang · Ukekeya',
                      ),
                    ),
                optionsViewBuilder:
                    (
                      BuildContext context,
                      void Function(Place) onSelected,
                      Iterable<Place> options,
                    ) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: AppRadius.smAll,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: options
                                .map(
                                  (Place option) => ListTile(
                                    dense: true,
                                    title: Text(option.name),
                                    subtitle: option.path == null
                                        ? null
                                        : Text(
                                            option.path!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    onTap: () => onSelected(option),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: widget.clan,
                decoration: const InputDecoration(labelText: 'Your clan (optional)'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// YOUR PICTURE, AND THE BAND BEHIND IT.
///
/// `avatar_media_id` has been a writable column on a profile since the
/// membership module was built, and there was no way for the profile's owner to
/// fill it — the media library needs a permission an ordinary member does not
/// have and should not be given. So the field existed and the person it
/// belonged to could not use it.
///
/// Both go to the avatars folder, which is the one place `ALLOWED_MIME_TYPES`
/// restricts to stills and the only folder every signed-in member can write to.
class _ProfilePhotos extends StatefulWidget {
  const _ProfilePhotos({
    required this.avatarUrl,
    required this.coverUrl,
    required this.name,
  });

  final String? avatarUrl;
  final String? coverUrl;
  final String name;

  @override
  State<_ProfilePhotos> createState() => _ProfilePhotosState();
}

class _ProfilePhotosState extends State<_ProfilePhotos> {
  late String? _avatar = widget.avatarUrl;
  late String? _cover = widget.coverUrl;
  bool _busy = false;
  String? _error;

  Future<void> _pick({required bool isCover}) async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: UploadExtensions.images,
      withData: true,
    );
    final PlatformFile? file = picked?.files.singleOrNull;
    final Uint8List? bytes = file?.bytes;
    if (file == null || bytes == null) return;

    if (!mounted) return;
    final MemberRepository repository = context.read<MemberRepository>();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String? url = await repository.uploadProfilePhoto(
            bytes: bytes,
            filename: file.name,
            isCover: isCover,
          );
      if (!mounted) return;
      setState(() {
        if (isCover) {
          _cover = url;
        } else {
          _avatar = url;
        }
      });
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove({required bool isCover}) async {
    setState(() => _busy = true);
    try {
      await context.read<MemberRepository>().removeProfilePhoto(isCover: isCover);
      if (!mounted) return;
      setState(() {
        if (isCover) {
          _cover = null;
        } else {
          _avatar = null;
        }
      });
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Your picture', style: theme.textTheme.titleMedium),
        const Gap.xs(),
        Text(
          'A photograph of you, and a wider image for the band behind it. Both are optional, '
          'and both are visible to anybody who can see your profile.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Gap.lg(),

        // The cover, with the portrait sitting on it — the same arrangement as
        // the profile itself, so what somebody is setting up is what they see.
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 3.4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.mdAll,
                  color: theme.colorScheme.surfaceContainerHighest,
                  image: _cover == null
                      ? null
                      : DecorationImage(image: NetworkImage(_cover!), fit: BoxFit.cover),
                ),
                alignment: Alignment.center,
                child: _cover != null
                    ? null
                    : Text(
                        'No cover image',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              bottom: -28,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navy,
                  border: Border.all(color: theme.colorScheme.surface, width: 3),
                  image: _avatar == null
                      ? null
                      : DecorationImage(image: NetworkImage(_avatar!), fit: BoxFit.cover),
                ),
                alignment: Alignment.center,
                child: _avatar != null
                    ? null
                    : Text(
                        _initials(widget.name),
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),

        if (_error != null) ...<Widget>[
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const Gap.sm(),
        ],

        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(isCover: false),
              icon: const Icon(Icons.person_outline, size: 18),
              label: Text(_avatar == null ? 'Add your picture' : 'Change your picture'),
            ),
            if (_avatar != null)
              TextButton(
                onPressed: _busy ? null : () => _remove(isCover: false),
                child: const Text('Remove picture'),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(isCover: true),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_cover == null ? 'Add a cover image' : 'Change cover image'),
            ),
            if (_cover != null)
              TextButton(
                onPressed: _busy ? null : () => _remove(isCover: true),
                child: const Text('Remove cover'),
              ),
          ],
        ),
        if (_busy) ...<Widget>[
          const Gap.md(),
          const LinearProgressIndicator(minHeight: 3),
        ],
      ],
    );
  }

  static String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((String p) => p[0].toUpperCase()).join();
  }
}
