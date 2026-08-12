import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/cms_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_status.dart';
import '../../repositories/cms_repository.dart';
import '../../repositories/content_repository.dart';
import '../../core/config/service_locator.dart';
import '../../services/api/api_response.dart';
import '../../models/content_record.dart';
import '../../services/auth/auth_controller.dart';
import '../workspace/content_editor.dart';
import 'editorial_shell.dart';

/// EDIT THE WEBSITE'S TEXT.
///
/// This is the screen that satisfies Module 2's central requirement: an
/// Editorial Team member can change any public-facing wording — headings,
/// paragraphs, button labels, empty states, notices — without touching code
/// and without a deployment.
///
/// Each string moves through the same workflow as an article: save a draft,
/// submit it, have it approved, have it published. The live site is unaffected
/// until the last step, so an editor can work in the open without risk.
class EditorialTextPage extends StatefulWidget {
  const EditorialTextPage({this.group, this.title = 'Website text', super.key});

  /// Restricts the screen to one group, e.g. `home`.
  final String? group;

  final String title;

  @override
  State<EditorialTextPage> createState() => _EditorialTextPageState();
}

class _EditorialTextPageState extends State<EditorialTextPage> {
  int _reloadToken = 0;

  void _reload() => setState(() => _reloadToken += 1);

  @override
  Widget build(BuildContext context) {
    return WorkspaceShell(
      currentPath: widget.group == 'home'
          ? AppRoutes.editorialHomepage
          : AppRoutes.editorialPages,
      title: widget.title,
      workspaceName: 'Editorial',
      accent: AppColors.skyBlue,
      navigation: editorialNavigation,
      child: AsyncContent<Map<String, dynamic>>(
        key: ValueKey<String>('strings:${widget.group}:$_reloadToken'),
        load: () => context.read<CmsRepository>().editorialStrings(group: widget.group),
        loadingMessage: 'Loading the website text…',
        builder: (BuildContext context, Map<String, dynamic> data) {
          final Map<String, dynamic> groups =
              (data['groups'] as Map<String, dynamic>?) ?? <String, dynamic>{};

          if (groups.isEmpty) {
            return const EmptyView(
              icon: Icons.text_fields,
              title: 'No editable text found',
              message:
                  'The content strings have not been seeded. Run the database migrations, then '
                  'reload this page.',
              showContributeAction: false,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _HowThisWorks(),
              const Gap.xxl(),
              ...groups.entries.map(
                (MapEntry<String, dynamic> entry) => _StringGroup(
                  groupName: entry.key,
                  strings: (entry.value as List<dynamic>)
                      .whereType<Map<String, dynamic>>()
                      .toList(growable: false),
                  onChanged: _reload,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HowThisWorks extends StatelessWidget {
  const _HowThisWorks();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('How this works', style: theme.textTheme.titleSmall),
          const Gap.sm(),
          Text(
            'Everything below appears on the public website. Editing saves a draft — visitors '
            'continue to see the current text until the change has been reviewed and published. '
            'Nothing you type here can break the site.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StringGroup extends StatelessWidget {
  const _StringGroup({
    required this.groupName,
    required this.strings,
    required this.onChanged,
  });

  final String groupName;
  final List<Map<String, dynamic>> strings;
  final VoidCallback onChanged;

  static const Map<String, String> _groupLabels = <String, String>{
    'brand': 'Brand',
    'home': 'Homepage',
    'footer': 'Footer',
    'system': 'System labels and messages',
    'pages': 'Page titles and introductions',
    'navigation': 'Navigation',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_groupLabels[groupName] ?? groupName, style: theme.textTheme.headlineSmall),
          const Gap.md(),
          ...strings.map(
            (Map<String, dynamic> string) => _StringEditor(
              string: string,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _StringEditor extends StatefulWidget {
  const _StringEditor({required this.string, required this.onChanged});

  final Map<String, dynamic> string;
  final VoidCallback onChanged;

  @override
  State<_StringEditor> createState() => _StringEditorState();
}

class _StringEditorState extends State<_StringEditor> {
  late final TextEditingController _controller;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  String get _key => Json.str(widget.string, 'key');
  String get _status => Json.str(widget.string, 'status', fallback: ContentStatus.published);
  bool get _isLocked => Json.boolVal(widget.string, 'isLocked');

  @override
  void initState() {
    super.initState();
    // Shows the pending draft if there is one, otherwise the live value.
    _controller = TextEditingController(
      text: Json.strOrNull(widget.string, 'draftValue') ??
          Json.str(widget.string, 'value'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      // The CMS is reloaded so the change is reflected across the running app
      // as soon as it goes live.
      if (mounted) await context.read<CmsController>().refresh();
      if (mounted) {
        setState(() {
          _message = success;
          _isError = false;
        });
        widget.onChanged();
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final CmsRepository repository = context.read<CmsRepository>();

    final bool multiline = Json.str(widget.string, 'valueType') == 'richtext';
    final bool pending = Json.boolVal(widget.string, 'hasPendingChange');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: pending ? AppColors.warning.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    Json.str(widget.string, 'label', fallback: _key),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                StatusBadge(_status),
              ],
            ),
            if (Json.strOrNull(widget.string, 'helpText') != null) ...<Widget>[
              const Gap.xs(),
              Text(widget.string['helpText'].toString(), style: theme.textTheme.bodySmall),
            ],
            const Gap.md(),

            TextField(
              controller: _controller,
              enabled: !_isLocked && !_busy,
              maxLines: multiline ? 6 : 2,
              minLines: multiline ? 3 : 1,
              maxLength: Json.intOrNull(widget.string, 'maxLength'),
              decoration: InputDecoration(
                isDense: true,
                helperText: _isLocked ? 'This text is locked and cannot be edited.' : null,
              ),
            ),

            if (pending) ...<Widget>[
              const Gap.sm(),
              Row(
                children: <Widget>[
                  const Icon(Icons.pending_outlined, size: 14, color: AppColors.warning),
                  const Gap.hSm(),
                  Expanded(
                    child: Text(
                      'There is an unpublished change. Visitors still see: '
                      '“${Json.str(widget.string, 'value', fallback: '(empty)')}”',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.goldDark),
                    ),
                  ),
                ],
              ),
            ],

            if (_message != null) ...<Widget>[
              const Gap.sm(),
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isError ? theme.colorScheme.error : AppColors.green,
                ),
              ),
            ],

            const Gap.md(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _isLocked || _busy
                      ? null
                      : () => _run(
                            () => repository.saveDraft(_key, _controller.text),
                            'Draft saved. Not yet visible on the website.',
                          ),
                  child: const Text('Save draft'),
                ),
                OutlinedButton(
                  onPressed: _isLocked || _busy
                      ? null
                      : () => _run(
                            () => repository.submitForReview(_key),
                            'Submitted for review.',
                          ),
                  child: const Text('Submit for review'),
                ),
                // Approving and publishing appear only for accounts that hold
                // those permissions. The server checks again regardless.
                if (auth.canReview)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => repository.reviewString(_key, approved: true),
                              'Approved.',
                            ),
                    child: const Text('Approve'),
                  ),
                if (auth.canPublish)
                  FilledButton(
                    onPressed: _isLocked || _busy
                        ? null
                        : () => _run(
                              () => repository.publishString(_key),
                              'Published. This is now live on the website.',
                            ),
                    child: const Text('Publish'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The editorial list screen for one content type.
///
/// Shows every record in every status with its position in the workflow, and
/// lets an authorised account create a new one or edit an existing one. This is
/// where a Super Admin or an editor actually contributes material, rather than
/// only adjusting text that already exists.
class EditorialContentPage extends StatefulWidget {
  const EditorialContentPage({
    required this.resource,
    required this.title,
    required this.path,
    super.key,
  });

  final String resource;
  final String title;
  final String path;

  @override
  State<EditorialContentPage> createState() => _EditorialContentPageState();
}

class _EditorialContentPageState extends State<EditorialContentPage> {
  int _reloadToken = 0;
  String? _status;

  void _reload() => setState(() => _reloadToken += 1);

  Future<void> _openEditor({ContentRecord? record}) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => ContentEditorDialog(
        resource: widget.resource,
        title: widget.title,
        record: record,
      ),
    );
    if (saved ?? false) _reload();
  }

  Future<void> _changeStatus(ContentRecord record, String status) async {
    try {
      await context.contentRepository(widget.resource).changeStatus(record.id, status);
      _reload();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final ContentRepository repository = context.contentRepository(widget.resource);

    final bool canCreate = auth.can('content.create') ||
        auth.can('${widget.resource}:create') ||
        auth.can('*');

    return WorkspaceShell(
      currentPath: widget.path,
      title: widget.title,
      workspaceName: 'Editorial',
      accent: AppColors.skyBlue,
      navigation: editorialNavigation,
      actions: <Widget>[
        if (canCreate)
          FilledButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Icons.add, size: 18),
            label: Text('New ${widget.title.toLowerCase()}'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilterChip(
                label: const Text('All'),
                selected: _status == null,
                onSelected: (_) => setState(() => _status = null),
              ),
              ...ContentStatus.all.map(
                (String status) => FilterChip(
                  label: Text(ContentStatus.label(status)),
                  selected: _status == status,
                  onSelected: (bool selected) =>
                      setState(() => _status = selected ? status : null),
                ),
              ),
            ],
          ),
          const Gap.xl(),

          AsyncContent<PaginatedResult<ContentRecord>>(
            key: ValueKey<String>('${widget.resource}:$_status:$_reloadToken'),
            load: () => repository.adminList(perPage: 60, status: _status),
            loadingMessage: 'Loading ${widget.title.toLowerCase()}…',
            isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
            emptyBuilder: (BuildContext context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EmptyView(
                  icon: Icons.article_outlined,
                  title: 'No ${widget.title.toLowerCase()} records yet',
                  message:
                      'Nothing has been created in this section. Use “New '
                      '${widget.title.toLowerCase()}” above to add the first entry — it starts as '
                      'a draft and only reaches the public site once it has been published.',
                  showContributeAction: false,
                ),
              ],
            ),
            builder: (BuildContext context, PaginatedResult<ContentRecord> result) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${result.total} record${result.total == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                const Gap.lg(),
                ...result.items.map(
                  (ContentRecord record) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: AppRadius.smAll,
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(record.displayTitle, style: theme.textTheme.titleSmall),
                                    if (record.summary != null) ...<Widget>[
                                      const Gap.xs(),
                                      Text(
                                        record.summary!,
                                        style: theme.textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Gap.hLg(),
                              if (record.verificationStatus != null) ...<Widget>[
                                VerificationBadge(record.verificationStatus!),
                                const Gap.hSm(),
                              ],
                              StatusBadge(record.status),
                            ],
                          ),
                          const Gap.md(),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: () => _openEditor(record: record),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                ),
                              ),
                              if (record.status == ContentStatus.draft &&
                                  (auth.can('content.submit') || auth.can('*')))
                                _WorkflowButton(
                                  label: 'Submit for review',
                                  onPressed: () =>
                                      _changeStatus(record, ContentStatus.pendingReview),
                                ),
                              if (record.status == ContentStatus.pendingReview && auth.canReview)
                                _WorkflowButton(
                                  label: 'Approve',
                                  onPressed: () => _changeStatus(record, ContentStatus.approved),
                                ),
                              if (record.status != ContentStatus.published && auth.canPublish)
                                _WorkflowButton(
                                  label: 'Publish',
                                  emphasised: true,
                                  onPressed: () => _changeStatus(record, ContentStatus.published),
                                ),
                              if (record.status == ContentStatus.published && auth.canPublish)
                                _WorkflowButton(
                                  label: 'Unpublish',
                                  onPressed: () => _changeStatus(record, ContentStatus.draft),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _WorkflowButton extends StatelessWidget {
  const _WorkflowButton({
    required this.label,
    required this.onPressed,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 34)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
    );

    return emphasised
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
  }
}
