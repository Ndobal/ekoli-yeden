import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_status.dart';
import '../../models/gallery.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/gallery_repository.dart';
import '../../services/auth/auth_controller.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart';
import 'workspace_pages.dart';

/// CONTRIBUTED FILES AWAITING REVIEW.
///
/// Photographs, documents and recordings sent in by the community. These live
/// in their own R2 bucket, apart from the published archive, and nothing here
/// is reachable by the public.
///
/// Approving copies the file into the archive and credits the contributor. It
/// does not publish it — that remains a separate, deliberate act, so nobody
/// accidentally puts a family photograph on the front page while triaging a
/// queue.
class ContributionsReviewPage extends StatefulWidget {
  const ContributionsReviewPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<ContributionsReviewPage> createState() => _ContributionsReviewPageState();
}

class _ContributionsReviewPageState extends State<ContributionsReviewPage> {
  String _status = 'pending_review';
  int _reloadToken = 0;

  String? _notice;

  void _reload([String? outcome]) => setState(() {
        _reloadToken += 1;
        _notice = outcome;
      });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: isAdmin ? AppRoutes.adminContributions : AppRoutes.editorialContributions,
      title: 'Contributed files',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminNote(
            message:
                'Files sent in by the community. They are held in a separate store from the '
                'published archive and are not reachable by anybody outside this screen.\n\n'
                'Approving copies a file into the archive and records the contributor — that '
                'credit survives every later edit.\n\n'
                'A file becomes visible to the public only once it is BOTH published and in an '
                'album. Choose both when you approve, or it stays in the archive with nobody '
                'able to see it.',
          ),
          const Gap.xl(),

          // What the last decision actually did. Worth its own line, because
          // "approved" and "on the public site" are different outcomes and the
          // gap between them is exactly what went wrong before.
          if (_notice != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(_notice!, style: theme.textTheme.bodyMedium),
            ),
            const Gap.lg(),
          ],

          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final ({String value, String label}) option in <({String value, String label})>[
                (value: 'pending_review', label: 'Awaiting review'),
                (value: 'promoted', label: 'Approved'),
                (value: 'rejected', label: 'Rejected'),
              ])
                FilterChip(
                  label: Text(option.label),
                  selected: _status == option.value,
                  onSelected: (_) => setState(() => _status = option.value),
                ),
            ],
          ),
          const Gap.xl(),

          AsyncContent<Map<String, dynamic>>(
            key: ValueKey<String>('contributions:$_status:$_reloadToken'),
            load: () => context.read<AccountRepository>().contributionQueue(status: _status),
            loadingMessage: 'Loading contributed files…',
            builder: (BuildContext context, Map<String, dynamic> data) {
              final List<Map<String, dynamic>> items = Json.objectList(data, 'items');
              if (items.isEmpty) {
                return EmptyView(
                  icon: Icons.inbox_outlined,
                  title: _status == 'pending_review'
                      ? 'Nothing waiting'
                      : 'Nothing in this state',
                  message: _status == 'pending_review'
                      ? 'Files uploaded through the contribution page appear here for review. '
                          'An empty queue means there is nothing outstanding.'
                      : 'No files have reached this state yet.',
                  showContributeAction: false,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${items.length} file${items.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Gap.lg(),
                  ...items.map(
                    (Map<String, dynamic> item) =>
                        _ContributionRow(item: item, onReviewed: _reload),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContributionRow extends StatefulWidget {
  const _ContributionRow({required this.item, required this.onReviewed});

  final Map<String, dynamic> item;

  /// Called once a decision is made, with the API's own account of what
  /// happened where there is one — "approved" and "on the public site" are
  /// different outcomes and the reviewer has to be told which they got.
  final void Function([String? outcome]) onReviewed;

  @override
  State<_ContributionRow> createState() => _ContributionRowState();
}

class _ContributionRowState extends State<_ContributionRow> {
  final TextEditingController _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Deferred: `context.read` is not safe during initState itself.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlbums());
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// The album to file this into, chosen by the reviewer. Null means none —
  /// which leaves the file accessioned but unfindable, so the interface says so
  /// rather than letting it happen quietly.
  String? _galleryId;
  bool _publish = true;
  List<AlbumSummary> _albums = const <AlbumSummary>[];
  bool _albumsLoaded = false;

  Future<void> _loadAlbums() async {
    if (_albumsLoaded) return;
    _albumsLoaded = true;
    try {
      final List<AlbumSummary> albums = await context.read<GalleryRepository>().albums();
      if (mounted) setState(() => _albums = albums);
    } on AppException {
      // A failure here costs the reviewer the album picker, not the ability to
      // approve. Silence is right: they have a decision to make either way.
    }
  }

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String message = await context.read<AccountRepository>().approveContribution(
            Json.str(widget.item, 'id'),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            galleryId: _galleryId,
            publish: _publish,
          );
      // The API's own account of what happened, shown as-is. "Approved" and
      // "on the public site" are different outcomes and the reviewer needs to
      // know which one they got.
      widget.onReviewed(message);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(Future<void> Function(String id, {String? notes}) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(
        Json.str(widget.item, 'id'),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      widget.onReviewed();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final AccountRepository repository = context.read<AccountRepository>();
    final Map<String, dynamic> item = widget.item;

    final String status = Json.str(item, 'status', fallback: 'pending_review');
    final bool pending = status == 'pending_review';
    final bool isImage = Json.str(item, 'mime_type').startsWith('image/');
    final bool canReview = auth.canReview || auth.can('submissions:review') || auth.can('*');
    // The preview URL is relative to the API and requires the reviewer's token,
    // so it is only shown as a link rather than loaded inline.
    final String previewUrl =
        '${AppConfig.apiBaseUrl}${Json.str(item, 'previewUrl')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: pending
                ? AppColors.warning.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: AppRadius.smAll,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isImage ? Icons.image_outlined : Icons.description_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        Json.strOrNull(item, 'caption') ??
                            Json.str(item, 'original_filename', fallback: 'Untitled file'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const Gap.xs(),
                      Text(
                        '${Json.str(item, 'mime_type')} · '
                        '${Formatters.fileSize(Json.intVal(item, 'size_bytes'))} · '
                        '${Formatters.relative(Json.strOrNull(item, 'created_at'))}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  status == 'promoted' ? ContentStatus.approved : status,
                ),
              ],
            ),

            const Gap.md(),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (Json.strOrNull(item, 'contributor_name') != null)
                  _Detail(label: 'From', value: Json.str(item, 'contributor_name')),
                if (Json.strOrNull(item, 'contributor_email') != null)
                  _Detail(label: 'Email', value: Json.str(item, 'contributor_email')),
                if (Json.strOrNull(item, 'people_pictured') != null)
                  _Detail(label: 'Pictured', value: Json.str(item, 'people_pictured')),
                if (Json.strOrNull(item, 'taken_at') != null)
                  _Detail(label: 'Taken', value: Json.str(item, 'taken_at')),
                if (Json.strOrNull(item, 'location') != null)
                  _Detail(label: 'Location', value: Json.str(item, 'location')),
                _Detail(
                  label: 'Permission',
                  value: Json.str(item, 'usage_permission', fallback: 'unspecified')
                      .replaceAll('_', ' '),
                ),
              ],
            ),

            const Gap.md(),
            SelectableText(
              previewUrl,
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.navyLight),
            ),

            if (_error != null) ...<Widget>[
              const Gap.sm(),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],

            if (pending && canReview) ...<Widget>[
              const Gap.lg(),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Review note (optional)',
                  isDense: true,
                  helperText: 'Recorded with the decision. Useful when rejecting.',
                ),
              ),
              const Gap.md(),

              // WHERE IT GOES.
              //
              // Approving used to be the whole interface, and it created a
              // media asset that lived in the library and nowhere else — not
              // in an album, not on the site, not even reachable at its own
              // URL, because an unpublished asset is refused to visitors.
              // Every contribution this archive received was lost in that gap.
              //
              // So the two steps that were missing are asked for here, at the
              // moment the decision is made.
              DropdownButtonFormField<String?>(
                initialValue: _galleryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Add it to which album?',
                  isDense: true,
                  helperText: 'A file in no album is in the archive but not on any page.',
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Do not file it yet'),
                  ),
                  ..._albums.map(
                    (AlbumSummary album) => DropdownMenuItem<String?>(
                      value: album.id,
                      child: Text(album.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _busy ? null : (String? value) => setState(() => _galleryId = value),
              ),
              const Gap.sm(),
              CheckboxListTile(
                value: _publish,
                onChanged: _busy ? null : (bool? value) => setState(() => _publish = value ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Publish it now'),
                subtitle: const Text(
                  'Until this is ticked, nobody outside this screen can see the file — not even '
                  'at its own address.',
                ),
              ),
              if (_galleryId == null && _publish) ...<Widget>[
                const Gap.xs(),
                Text(
                  'It will be visible at its own address but will not appear in the Gallery, '
                  'because it is not in an album.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ],
              const Gap.md(),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: _busy ? null : _approve,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Approve'),
                  ),
                  const Gap.hMd(),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _act(repository.rejectContribution),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],

            if (Json.strOrNull(item, 'review_notes') != null) ...<Widget>[
              const Gap.sm(),
              Text(
                'Note: ${Json.str(item, 'review_notes')}',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label: ', style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
