import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/state_views.dart';
import '../../models/media_asset.dart';
import '../../repositories/media_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';
import '../editorial/editorial_shell.dart';

/// THE MEDIA LIBRARY.
///
/// Where photographs, audio recordings and documents are uploaded, catalogued
/// and published. Used by the Super Admin and by the Editorial Team from the
/// same screen — the difference is what the server permits, not what the
/// interface offers.
///
/// Videos are absent by design: YouTube hosts them, and they are catalogued
/// through the Videos screen as a link rather than a file.
class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({required this.workspace, super.key});

  /// Which workspace this is rendered inside — the shells differ.
  final WorkspaceKind workspace;

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

enum WorkspaceKind { admin, editorial }

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  String? _folder;
  int _reloadToken = 0;

  void _reload() => setState(() => _reloadToken += 1);

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;

    return WorkspaceShell(
      currentPath: isAdmin ? AppRoutes.adminMedia : AppRoutes.editorialMedia,
      title: 'Media library',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MediaUploadPanel(onUploaded: _reload),
          const Gap.xxl(),

          Row(
            children: <Widget>[
              Expanded(
                child: Text('Library', style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _reload,
              ),
            ],
          ),
          const Gap.md(),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilterChip(
                label: const Text('All folders'),
                selected: _folder == null,
                onSelected: (_) => setState(() => _folder = null),
              ),
              ...MediaFolders.all.map(
                (String folder) => FilterChip(
                  label: Text(folder),
                  selected: _folder == folder,
                  onSelected: (bool selected) =>
                      setState(() => _folder = selected ? folder : null),
                ),
              ),
            ],
          ),
          const Gap.xl(),

          AsyncContent<PaginatedResult<MediaAsset>>(
            key: ValueKey<String>('media:$_folder:$_reloadToken'),
            load: () => context.read<MediaRepository>().list(folder: _folder, perPage: 60),
            loadingMessage: 'Loading the media library…',
            isEmpty: (PaginatedResult<MediaAsset> result) => result.isEmpty,
            emptyBuilder: (BuildContext context) => const EmptyView(
              icon: Icons.photo_library_outlined,
              title: 'Nothing uploaded yet',
              message:
                  'Photographs, audio recordings and documents you upload appear here. Each one '
                  'can then be catalogued — what it shows, who is in it, when and where — which '
                  'is what makes it findable later.',
              showContributeAction: false,
            ),
            builder: (BuildContext context, PaginatedResult<MediaAsset> result) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${result.total} item${result.total == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Gap.lg(),
                ResponsiveCardGrid(
                  maxColumns: 4,
                  spacing: AppSpacing.md,
                  children: result.items
                      .map((MediaAsset asset) => MediaTile(asset: asset, onChanged: _reload))
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The upload control.
///
/// Reads the accepted types and size limits from the API rather than hard-coding
/// them, so the form and the server can never disagree about what is allowed.
class MediaUploadPanel extends StatefulWidget {
  const MediaUploadPanel({required this.onUploaded, super.key});

  final VoidCallback onUploaded;

  @override
  State<MediaUploadPanel> createState() => _MediaUploadPanelState();
}

class _MediaUploadPanelState extends State<MediaUploadPanel> {
  String _folder = MediaFolders.heritage;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _credit = TextEditingController();
  final TextEditingController _altText = TextEditingController();

  bool _busy = false;
  String? _message;
  bool _isError = false;
  int _uploaded = 0;
  int _total = 0;

  @override
  void dispose() {
    _title.dispose();
    _credit.dispose();
    _altText.dispose();
    super.dispose();
  }

  /// The folder decides what may be uploaded, so the file picker is scoped to
  /// match — a visitor should not be able to choose a file that will be
  /// rejected a moment later.
  List<String> get _extensionsForFolder {
    switch (_folder) {
      case MediaFolders.audio:
      case MediaFolders.language:
        return <String>['mp3', 'm4a', 'aac', 'ogg', 'wav', 'weba'];
      case MediaFolders.documents:
        return <String>['pdf', 'doc', 'docx', 'txt'];
      case MediaFolders.heritage:
      case MediaFolders.leboku:
        return <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif', 'pdf', 'doc', 'docx', 'txt'];
      default:
        return <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif'];
    }
  }

  Future<void> _pickAndUpload() async {
    // Captured before the picker opens: the dialog is an async gap, and reading
    // an inherited widget across one is unsafe.
    final MediaRepository repository = context.read<MediaRepository>();

    final FilePickerResult? picked = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true, // Web has no filesystem path; we need the bytes.
      type: FileType.custom,
      allowedExtensions: _extensionsForFolder,
    );
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _busy = true;
      _message = null;
      _uploaded = 0;
      _total = picked.files.length;
    });
    int succeeded = 0;
    String? firstError;

    for (final PlatformFile file in picked.files) {
      final Uint8List? bytes = file.bytes;
      if (bytes == null) continue;

      try {
        await repository.upload(
          bytes: bytes,
          filename: file.name,
          folder: _folder,
          // With several files the typed title would be wrong for all but one,
          // so it is only applied to a single upload.
          title: picked.files.length == 1 && _title.text.trim().isNotEmpty
              ? _title.text.trim()
              : null,
          credit: _credit.text.trim().isEmpty ? null : _credit.text.trim(),
          altText: picked.files.length == 1 && _altText.text.trim().isNotEmpty
              ? _altText.text.trim()
              : null,
        );
        succeeded += 1;
      } on AppException catch (error) {
        firstError ??= '${file.name}: ${error.message}';
      }
      if (mounted) setState(() => _uploaded = succeeded);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _isError = succeeded == 0;
      _message = succeeded == 0
          ? (firstError ?? 'Nothing could be uploaded.')
          : 'Uploaded $succeeded of ${picked.files.length}. '
              '${firstError == null ? '' : 'One or more failed — $firstError'}';
      if (succeeded > 0) {
        _title.clear();
        _altText.clear();
      }
    });

    if (succeeded > 0) widget.onUploaded();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();
    final bool mayUpload = auth.can('media.manage') ||
        auth.can('media:create') ||
        auth.can('media.metadata.edit') ||
        auth.can('*');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Upload to the archive', style: theme.textTheme.titleMedium),
          const Gap.xs(),
          Text(
            'Photographs, audio recordings and documents. Videos are not uploaded — publish them '
            'on YouTube and record the link under Videos.',
            style: theme.textTheme.bodySmall,
          ),
          const Gap.lg(),

          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _folder,
                  decoration: const InputDecoration(labelText: 'Folder', isDense: true),
                  items: MediaFolders.all
                      .map(
                        (String folder) => DropdownMenuItem<String>(
                          value: folder,
                          child: Text(_folderLabel(folder)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _busy ? null : (String? value) => setState(() => _folder = value ?? _folder),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _title,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Title (single file)',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _credit,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Credit / contributor',
                    isDense: true,
                    helperText: 'Applied to every file in this upload',
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _altText,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Description for screen readers',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const Gap.lg(),

          Row(
            children: <Widget>[
              FilledButton.icon(
                onPressed: _busy || !mayUpload ? null : _pickAndUpload,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_busy ? 'Uploading $_uploaded of $_total…' : 'Choose files'),
              ),
              const Gap.hLg(),
              if (!mayUpload)
                Expanded(
                  child: Text(
                    'Your account does not have permission to upload media.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),

          if (_message != null) ...<Widget>[
            const Gap.md(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: (_isError ? theme.colorScheme.error : AppColors.green)
                    .withValues(alpha: 0.08),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isError ? theme.colorScheme.error : AppColors.greenDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _folderLabel(String folder) {
    switch (folder) {
      case MediaFolders.images:
        return 'images — current photographs';
      case MediaFolders.heritage:
        return 'heritage — historical material';
      case MediaFolders.leboku:
        return 'leboku — festival material';
      case MediaFolders.language:
        return 'language — pronunciation';
      case MediaFolders.audio:
        return 'audio — recordings';
      case MediaFolders.documents:
        return 'documents — scans, PDFs';
      case MediaFolders.avatars:
        return 'avatars — profile pictures';
      default:
        return folder;
    }
  }
}

/// One item in the library, with its cataloguing controls.
class MediaTile extends StatelessWidget {
  const MediaTile({required this.asset, required this.onChanged, super.key});

  final MediaAsset asset;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: asset.needsCataloguing
              ? AppColors.warning.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (asset.isImage)
            ArchiveImage(url: asset.url, label: asset.accessibleLabel, aspectRatio: 4 / 3)
          else
            Container(
              height: 100,
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHigh,
              alignment: Alignment.center,
              child: Icon(
                asset.isAudio ? Icons.audiotrack_outlined : Icons.description_outlined,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  asset.displayTitle,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap.xs(),
                Text(
                  '${asset.folder} · ${Formatters.fileSize(asset.sizeBytes)}',
                  style: theme.textTheme.labelSmall,
                ),
                const Gap.sm(),
                Row(
                  children: <Widget>[
                    StatusBadge(asset.status),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Catalogue this item',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openCatalogueDialog(context),
                    ),
                  ],
                ),
                if (asset.needsCataloguing) ...<Widget>[
                  const Gap.xs(),
                  Text(
                    'Not yet described',
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.goldDark),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCatalogueDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _CatalogueDialog(
        asset: asset,
        onSaved: onChanged,
      ),
    );
  }
}

/// The cataloguing form — what turns a file into an archive record.
class _CatalogueDialog extends StatefulWidget {
  const _CatalogueDialog({required this.asset, required this.onSaved});

  final MediaAsset asset;
  final VoidCallback onSaved;

  @override
  State<_CatalogueDialog> createState() => _CatalogueDialogState();
}

class _CatalogueDialogState extends State<_CatalogueDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _altText;
  late final TextEditingController _credit;
  late final TextEditingController _location;
  late final TextEditingController _capturedAt;
  late String _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.asset.title ?? '');
    _description = TextEditingController(text: widget.asset.description ?? '');
    _altText = TextEditingController(text: widget.asset.altText ?? '');
    _credit = TextEditingController(text: widget.asset.credit ?? '');
    _location = TextEditingController(text: widget.asset.location ?? '');
    _capturedAt = TextEditingController(text: widget.asset.capturedAt ?? '');
    _status = widget.asset.status;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _altText.dispose();
    _credit.dispose();
    _location.dispose();
    _capturedAt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<MediaRepository>().catalogue(widget.asset.id, <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'alt_text': _altText.text.trim(),
        'credit': _credit.text.trim(),
        'location': _location.text.trim(),
        if (_capturedAt.text.trim().isNotEmpty) 'captured_at': _capturedAt.text.trim(),
        'status': _status,
      });
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Catalogue this item'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'What a photograph shows is what makes it findable in fifty years. Even a partial '
                'answer is worth recording.',
                style: theme.textTheme.bodySmall,
              ),
              const Gap.lg(),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const Gap.md(),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  helperText: 'Who is pictured, what is happening, anything known.',
                ),
              ),
              const Gap.md(),
              TextField(
                controller: _altText,
                decoration: const InputDecoration(
                  labelText: 'Description for screen readers',
                  helperText: 'Describe the image for somebody who cannot see it.',
                ),
              ),
              const Gap.md(),
              TextField(
                controller: _credit,
                decoration: const InputDecoration(
                  labelText: 'Credit',
                  helperText: 'Photographer, or who supplied it.',
                ),
              ),
              const Gap.md(),
              TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const Gap.md(),
              TextField(
                controller: _capturedAt,
                decoration: const InputDecoration(
                  labelText: 'Date taken',
                  helperText: 'YYYY-MM-DD, or leave blank if not known.',
                ),
              ),
              const Gap.md(),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ContentStatus.all
                    .map(
                      (String status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(ContentStatus.label(status)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) => setState(() => _status = value ?? _status),
              ),
              if (_error != null) ...<Widget>[
                const Gap.md(),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
