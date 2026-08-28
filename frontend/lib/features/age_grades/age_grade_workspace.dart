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
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/age_grade.dart';
import '../../repositories/age_grade_repository.dart';
import '../about/about_pages.dart';
import 'age_grade_pages.dart';

/// REGISTERING AN AGE GRADE.
///
/// Any signed-in member of the community may do this. The grade waits for the
/// Preservation Team before it appears publicly — a page that speaks for a body
/// of the community should be confirmed by somebody — and the person who
/// registers it becomes its lead administrator, so it is never left with
/// nobody able to correct it.
class RegisterAgeGradePage extends StatefulWidget {
  const RegisterAgeGradePage({super.key});

  @override
  State<RegisterAgeGradePage> createState() => _RegisterAgeGradePageState();
}

class _RegisterAgeGradePageState extends State<RegisterAgeGradePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _subtitle = TextEditingController();
  final TextEditingController _formedYear = TextEditingController();
  final TextEditingController _birthYears = TextEditingController();
  final TextEditingController _motto = TextEditingController();
  final TextEditingController _excerpt = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _office = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  bool _submitting = false;
  String? _error;
  ({String slug, String message})? _registered;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title,
      _subtitle,
      _formedYear,
      _birthYears,
      _motto,
      _excerpt,
      _body,
      _office,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final ({String id, String slug, String message}) result =
          await context.read<AgeGradeRepository>().register(
                title: _title.text.trim(),
                subtitle: _optional(_subtitle),
                formedYear: int.tryParse(_formedYear.text.trim()),
                birthYears: _optional(_birthYears),
                motto: _optional(_motto),
                excerpt: _optional(_excerpt),
                body: _optional(_body),
                office: _optional(_office),
                contactPhone: _optional(_phone),
              );
      if (mounted) {
        setState(() => _registered = (slug: result.slug, message: result.message));
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _optional(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.ageGrades,
      seo: const SeoMetadata(
        title: 'Register your age grade',
        description:
            'Register an age grade of Ekoli-Yeden and keep its page yourself — its members, its '
            'photographs and its news.',
        canonicalPath: AppRoutes.registerAgeGrade,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'Age grades',
            titleKey: 'page.age_grades.register.title',
            titleFallback: 'Register your age grade',
            introKey: 'page.age_grades.register.intro',
            introFallback:
                'If you belong to an age grade of Ekoli-Yeden, you can register it here and keep '
                'its page yourself. Give its name and the year it was formed. Once the '
                'Preservation Team has confirmed it, you and anybody you appoint can add its '
                'members, its photographs and its news.',
            accent: AppColors.navy,
          ),
          PageSection(
            reading: true,
            child: _registered != null
                ? _RegistrationReceipt(slug: _registered!.slug, message: _registered!.message)
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: 'The name of the grade *',
                            helperText: 'As the grade itself calls it.',
                          ),
                          validator: (String? value) =>
                              (value == null || value.trim().length < 2)
                                  ? 'Please give the name of the age grade.'
                                  : null,
                        ),
                        const Gap.lg(),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: <Widget>[
                            SizedBox(
                              width: 180,
                              child: TextFormField(
                                controller: _formedYear,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Year it was formed',
                                  helperText: 'Leave blank if unsure.',
                                ),
                                validator: (String? value) {
                                  if (value == null || value.trim().isEmpty) return null;
                                  final int? year = int.tryParse(value.trim());
                                  if (year == null || year < 1800 || year > 2200) {
                                    return 'Enter a four-digit year.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: _birthYears,
                                decoration: const InputDecoration(
                                  labelText: 'Birth years it covers',
                                  helperText: 'For example: 1974–1979.',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _subtitle,
                          decoration: const InputDecoration(
                            labelText: 'Also known as',
                            helperText: 'Any other name the grade goes by.',
                          ),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _motto,
                          decoration: const InputDecoration(labelText: 'Motto, if it has one'),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _excerpt,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'In one or two sentences',
                            alignLabelWithHint: true,
                            helperText: 'What appears under the name on the age grades page.',
                          ),
                        ),
                        const Gap.lg(),
                        TextFormField(
                          controller: _body,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'About the grade',
                            alignLabelWithHint: true,
                            helperText:
                                'How it was formed, what it has done for the community, and '
                                'anything the grade wants recorded. You can add to this later.',
                          ),
                        ),

                        const Gap.xxl(),
                        Text('About you', style: theme.textTheme.titleMedium),
                        const Gap.xs(),
                        Text(
                          'You become the lead administrator of this grade, so the Preservation '
                          'Team can reach you about it and you can appoint others to help.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Gap.lg(),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: <Widget>[
                            SizedBox(
                              width: 240,
                              child: TextFormField(
                                controller: _office,
                                decoration: const InputDecoration(
                                  labelText: 'Your office in the grade',
                                  helperText: 'Secretary, chairman, member…',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(labelText: 'Contact phone'),
                              ),
                            ),
                          ],
                        ),

                        if (_error != null) ...<Widget>[
                          const Gap.lg(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.error),
                            ),
                          ),
                        ],

                        const Gap.xl(),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Register this age grade'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationReceipt extends StatelessWidget {
  const _RegistrationReceipt({required this.slug, required this.message});

  final String slug;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 32, color: AppColors.green),
              const Gap.md(),
              Text('Registered', style: theme.textTheme.headlineSmall),
              const Gap.sm(),
              Text(message, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        const Gap.xxl(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.ageGradeManage(slug)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Start filling in the page'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.ageGrades),
              child: const Text('All age grades'),
            ),
          ],
        ),
      ],
    );
  }
}

/// THE GRADES YOU ADMINISTER.
class MyAgeGradesPage extends StatelessWidget {
  const MyAgeGradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AgeGradeRepository repository = context.read<AgeGradeRepository>();
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.myAgeGrades,
      seo: const SeoMetadata(
        title: 'My age grades',
        description: 'The age grade pages you help keep.',
        canonicalPath: AppRoutes.myAgeGrades,
        noIndex: true,
      ),
      child: PageSection(
        eyebrow: 'Your workspace',
        title: 'My age grades',
        description: 'The pages you help keep. Open one to add members, photographs or news.',
        child: AsyncContent<List<AgeGrade>>(
          load: repository.mine,
          loadingMessage: 'Checking…',
          isEmpty: (List<AgeGrade> grades) => grades.isEmpty,
          emptyBuilder: (BuildContext context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const EmptyView(
                icon: Icons.groups_outlined,
                title: 'You do not administer an age grade yet',
                message:
                    'If you belong to an age grade, you can register it and keep its page. If your '
                    'grade is already here, ask one of its administrators to add you.',
                showContributeAction: false,
              ),
              const Gap.xl(),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.registerAgeGrade),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Register your age grade'),
              ),
            ],
          ),
          builder: (BuildContext context, List<AgeGrade> grades) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...grades.map(
                  (AgeGrade grade) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(grade.title, style: theme.textTheme.titleMedium),
                                    const Gap.hMd(),
                                    StatusBadge(grade.status),
                                    if (grade.isLead) ...<Widget>[
                                      const Gap.hSm(),
                                      Chip(
                                        label: const Text('Lead'),
                                        labelStyle: theme.textTheme.labelSmall,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ],
                                ),
                                if (grade.metaLine != null) ...<Widget>[
                                  const Gap.xs(),
                                  Text(grade.metaLine!, style: theme.textTheme.bodySmall),
                                ],
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => context.go(AppRoutes.ageGradeManage(grade.slug)),
                            child: const Text('Manage'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap.xl(),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.registerAgeGrade),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Register another grade'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// THE GRADE'S OWN WORKSPACE.
///
/// Everything the grade controls, and nothing it does not. There is no control
/// here for publishing the grade or marking it verified: those are the
/// Preservation Team's, and leaving the buttons out is clearer than showing
/// ones the server will refuse.
class AgeGradeManagePage extends StatefulWidget {
  const AgeGradeManagePage({required this.slug, super.key});

  final String slug;

  @override
  State<AgeGradeManagePage> createState() => _AgeGradeManagePageState();
}

class _AgeGradeManagePageState extends State<AgeGradeManagePage> {
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) {
    setState(() {
      _reloads += 1;
      _notice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AgeGradeRepository repository = context.read<AgeGradeRepository>();

    return AppScaffold(
      currentPath: AppRoutes.ageGrades,
      seo: SeoMetadata(
        title: 'Manage this age grade',
        canonicalPath: AppRoutes.ageGradeManage(widget.slug),
        noIndex: true,
      ),
      child: AsyncContent<AgeGradeWorkspace>(
        key: ValueKey<int>(_reloads),
        load: () => repository.workspace(widget.slug),
        loadingMessage: 'Opening your workspace…',
        builder: (BuildContext context, AgeGradeWorkspace workspace) {
          return _Workspace(
            workspace: workspace,
            notice: _notice,
            onChanged: _reload,
          );
        },
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.workspace, required this.onChanged, this.notice});

  final AgeGradeWorkspace workspace;
  final void Function([String? notice]) onChanged;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AgeGrade grade = workspace.grade;

    return Column(
      children: <Widget>[
        PageSection(
          eyebrow: 'Your workspace',
          title: grade.title,
          description:
              'What you add here appears on the public page for this grade. Whether the page '
              'itself is published, and whether the archive marks it as verified community '
              'history, stay with the Preservation Team.',
          action: OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.ageGrade(grade.slug)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('View the page'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (notice != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(notice!, style: theme.textTheme.bodyMedium),
                ),
                const Gap.xl(),
              ],
              if (grade.isAwaitingConfirmation)
                const AwaitingMaterialNote(
                  message:
                      'This grade is waiting for the Ekoli-Yeden Preservation Team to confirm it. '
                      'You can fill the page in now — everything you add will appear as soon as '
                      'the grade is confirmed.',
                ),
              const Gap.xl(),
              Row(
                children: <Widget>[
                  StatusBadge(grade.status),
                  const Gap.hMd(),
                  Text(
                    workspace.canAppointAdmins
                        ? 'You are a lead administrator of this grade.'
                        : 'You are an administrator of this grade.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- Posts --------------------------------------------------------
        PageSection(
          background: theme.colorScheme.surfaceContainerHigh,
          title: 'News',
          description:
              'Meeting notices, reports, projects — whatever the grade wants recorded. Published '
              "under the grade's own name, and labelled on the page as the grade speaking for "
              'itself.',
          action: FilledButton.icon(
            onPressed: () => _openPostDialog(context, workspace, onChanged),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Write a post'),
          ),
          child: workspace.posts.isEmpty
              ? const AwaitingMaterialNote(
                  message: 'Nothing posted yet. The first post is usually the easiest: what the '
                      'grade did most recently.',
                )
              : Column(
                  children: workspace.posts
                      .map(
                        (AgeGradePost post) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AgeGradePostCard(
                            post: post,
                            gradeSlug: workspace.grade.slug,
                            trailing: IconButton(
                              onPressed: () => _confirmDeletePost(context, workspace, post, onChanged),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Delete this post',
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),

        // --- Members -------------------------------------------------------
        PageSection(
          title: 'Members',
          description:
              "The grade's roster. A living person's name on a public page is personal data, so a "
              'new name waits for confirmation before it appears.',
          action: FilledButton.icon(
            onPressed: () => _openMemberDialog(context, workspace, onChanged),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add a member'),
          ),
          child: workspace.members.isEmpty
              ? const AwaitingMaterialNote(
                  message: 'No members recorded yet.',
                )
              : Column(
                  children: workspace.members
                      .map(
                        (AgeGradeMember member) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(member.fullName, style: theme.textTheme.bodyLarge),
                                    if (member.metaLine != null)
                                      Text(member.metaLine!, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              StatusBadge(member.status),
                              IconButton(
                                onPressed: () => _removeMember(context, workspace, member, onChanged),
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Remove from the roster',
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),

        // --- Administrators -------------------------------------------------
        PageSection(
          background: theme.colorScheme.surfaceContainerHigh,
          title: 'Who can keep this page',
          description: workspace.canAppointAdmins
              ? 'Only a lead administrator can appoint or remove somebody. They need an account '
                  'here already — ask them to register first, then add them by their email address.'
              : 'Only a lead administrator of this grade can change this list.',
          action: workspace.canAppointAdmins
              ? FilledButton.icon(
                  onPressed: () => _openAdminDialog(context, workspace, onChanged),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Appoint somebody'),
                )
              : null,
          child: Column(
            children: workspace.administrators
                .map(
                  (AgeGradeAdmin admin) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          admin.isLead ? Icons.star_outline : Icons.person_outline,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const Gap.hMd(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(admin.displayName, style: theme.textTheme.bodyLarge),
                              Text(
                                admin.office == null
                                    ? admin.roleLabel
                                    : '${admin.roleLabel} · ${admin.office}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (workspace.canAppointAdmins && admin.userId != null)
                          IconButton(
                            onPressed: () => _removeAdmin(context, workspace, admin, onChanged),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove this administrator',
                          ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The dialogs. Each one calls the API and reloads the workspace on success, so
// what is on screen is always what the server actually stored.
// ---------------------------------------------------------------------------

Future<void> _openPostDialog(
  BuildContext context,
  AgeGradeWorkspace workspace,
  void Function([String? notice]) onChanged,
) async {
  final TextEditingController title = TextEditingController();
  final TextEditingController body = TextEditingController();
  String postType = 'update';

  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
        title: const Text('Write a post'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: postType,
                  decoration: const InputDecoration(labelText: 'What kind of post'),
                  items: AgeGradePostTypes.all
                      .map(
                        (String type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(AgeGradePostTypes.label(type)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) =>
                      setDialogState(() => postType = value ?? postType),
                ),
                const Gap.lg(),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const Gap.lg(),
                TextField(
                  controller: body,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'The post',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(postType),
            child: const Text('Post'),
          ),
        ],
      ),
    ),
  );

  if (result == null || !context.mounted) return;

  if (title.text.trim().length < 3) {
    _showError(context, 'Please give the post a title.');
    return;
  }

  try {
    final ({AgeGradePost post, String message}) created =
        await context.read<AgeGradeRepository>().createPost(
              workspace.grade.slug,
              title: title.text.trim(),
              body: body.text.trim().isEmpty ? null : body.text.trim(),
              postType: result,
            );
    onChanged(created.message);
  } on AppException catch (error) {
    if (context.mounted) _showError(context, error.message);
  }
}

Future<void> _confirmDeletePost(
  BuildContext context,
  AgeGradeWorkspace workspace,
  AgeGradePost post,
  void Function([String? notice]) onChanged,
) async {
  final bool confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Delete this post?'),
          content: Text('“${post.title}” will be removed from the page. This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed || !context.mounted) return;

  try {
    await context.read<AgeGradeRepository>().deletePost(workspace.grade.slug, post.id);
    onChanged('The post was deleted.');
  } on AppException catch (error) {
    if (context.mounted) _showError(context, error.message);
  }
}

Future<void> _openMemberDialog(
  BuildContext context,
  AgeGradeWorkspace workspace,
  void Function([String? notice]) onChanged,
) async {
  final TextEditingController name = TextEditingController();
  final TextEditingController office = TextEditingController();
  final TextEditingController joined = TextEditingController();

  final bool add = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Add a member'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const Gap.lg(),
                TextField(
                  controller: office,
                  decoration: const InputDecoration(
                    labelText: 'Office in the grade',
                    helperText: 'Optional — secretary, treasurer, chairman.',
                  ),
                ),
                const Gap.lg(),
                TextField(
                  controller: joined,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year they joined (optional)'),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ) ??
      false;

  if (!add || !context.mounted) return;

  if (name.text.trim().length < 2) {
    _showError(context, 'Please give the full name.');
    return;
  }

  try {
    await context.read<AgeGradeRepository>().addMember(
          workspace.grade.slug,
          fullName: name.text.trim(),
          office: office.text.trim().isEmpty ? null : office.text.trim(),
          joinedYear: int.tryParse(joined.text.trim()),
        );
    onChanged('Added to the roster. The name appears publicly once it has been confirmed.');
  } on AppException catch (error) {
    if (context.mounted) _showError(context, error.message);
  }
}

Future<void> _removeMember(
  BuildContext context,
  AgeGradeWorkspace workspace,
  AgeGradeMember member,
  void Function([String? notice]) onChanged,
) async {
  try {
    await context.read<AgeGradeRepository>().removeMember(workspace.grade.slug, member.id);
    onChanged('${member.fullName} was removed from the roster.');
  } on AppException catch (error) {
    if (context.mounted) _showError(context, error.message);
  }
}

Future<void> _openAdminDialog(
  BuildContext context,
  AgeGradeWorkspace workspace,
  void Function([String? notice]) onChanged,
) async {
  final TextEditingController email = TextEditingController();
  final TextEditingController office = TextEditingController();
  String role = 'admin';

  final bool appoint = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
            title: const Text('Appoint an administrator'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Their email address',
                      helperText: 'They need an account here already.',
                    ),
                  ),
                  const Gap.lg(),
                  TextField(
                    controller: office,
                    decoration: const InputDecoration(labelText: 'Their office (optional)'),
                  ),
                  const Gap.lg(),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'What they may do'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'admin',
                        child: Text('Administrator — can post and edit'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'lead',
                        child: Text('Lead — can also appoint others'),
                      ),
                    ],
                    onChanged: (String? value) => setDialogState(() => role = value ?? role),
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
                child: const Text('Appoint'),
              ),
            ],
          ),
        ),
      ) ??
      false;

  if (!appoint || !context.mounted) return;

  try {
    final String message = await context.read<AgeGradeRepository>().appointAdmin(
          workspace.grade.slug,
          email: email.text.trim(),
          adminRole: role,
          office: office.text.trim().isEmpty ? null : office.text.trim(),
        );
    onChanged(message);
  } on AppException catch (error) {
    if (context.mounted) _showError(context, error.message);
  }
}

Future<void> _removeAdmin(
  BuildContext context,
  AgeGradeWorkspace workspace,
  AgeGradeAdmin admin,
  void Function([String? notice]) onChanged,
) async {
  if (admin.userId == null) return;

  try {
    await context.read<AgeGradeRepository>().removeAdmin(workspace.grade.slug, admin.userId!);
    onChanged('${admin.displayName} no longer administers this page.');
  } on AppException catch (error) {
    // The server refuses to remove the last lead — a grade with nobody able to
    // hand it on would need somebody outside it to intervene. Surfaced as it
    // was written rather than reworded here.
    if (context.mounted) _showError(context, error.message);
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
