import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/async_content.dart';
import '../../models/media_asset.dart';
import '../../models/news.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/news_portal_repository.dart';
import '../editorial/editorial_shell.dart';
import '../news/news_blocks.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// WRITING A STORY.
///
/// ---------------------------------------------------------------------------
/// NOBODY IS ASKED TO WRITE MARKUP
/// ---------------------------------------------------------------------------
///
/// The Editorial Team are volunteers. A "rich text editor" that hands them a
/// box and hopes they produce valid HTML fails twice: it produces markup nobody
/// can trust, and it produces markup the server then has to scrub — which is a
/// denylist, and denylists lose.
///
/// So the story is built from blocks. Each one is a paragraph, a heading, a
/// quote, a list, a photograph, a video, a rule or a table, added from a menu
/// and edited in a plain field. The result cannot contain markup because there
/// is nowhere in the shape to put any, and the server validates a structure
/// rather than trying to out-think an attacker's parser.
///
/// ---------------------------------------------------------------------------
/// AND THEY CAN SEE IT
/// ---------------------------------------------------------------------------
///
/// The preview is the same renderer the public page uses — literally the same
/// widget, `NewsBody`. Not an approximation of it. An editor pressing "Preview"
/// sees exactly what a visitor will see, because it is the same code.
class NewsComposerPage extends StatelessWidget {
  const NewsComposerPage({required this.workspace, this.newsId, super.key});

  final WorkspaceKind workspace;

  /// Null when writing something new.
  final String? newsId;

  @override
  Widget build(BuildContext context) {
    if (newsId == null) {
      return _Composer(workspace: workspace, existing: null);
    }

    return AsyncContent<EditorialNews>(
      key: ValueKey<String>(newsId!),
      load: () => context.read<NewsPortalRepository>().editorialStory(newsId!),
      loadingMessage: 'Opening the story…',
      builder: (BuildContext context, EditorialNews story) =>
          _Composer(workspace: workspace, existing: story),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.workspace, required this.existing});

  final WorkspaceKind workspace;
  final EditorialNews? existing;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _excerpt = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _author = TextEditingController();
  final TextEditingController _tags = TextEditingController();

  List<NewsBlock> _blocks = <NewsBlock>[];
  List<NewsCategory> _categories = const <NewsCategory>[];
  String? _categoryId;
  DateTime? _newsDate;
  bool _preview = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  String? _id;

  @override
  void initState() {
    super.initState();

    final EditorialNews? existing = widget.existing;
    if (existing != null) {
      _id = existing.story.summary.id;
      _title.text = existing.story.summary.title;
      _excerpt.text = existing.story.summary.excerpt ?? '';
      _location.text = existing.story.summary.location ?? '';
      _author.text = existing.story.summary.authorName ?? '';
      _tags.text = existing.story.tags
          .map((({String slug, String name}) tag) => tag.name)
          .join(', ');
      _categoryId = existing.categoryId;
      _blocks = List<NewsBlock>.from(existing.story.body);
      _newsDate = DateTime.tryParse(existing.story.summary.newsDate ?? '');
    }

    if (_blocks.isEmpty) {
      _blocks = <NewsBlock>[const NewsBlock(type: 'paragraph', text: '')];
    }

    _loadCategories();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title,
      _excerpt,
      _location,
      _author,
      _tags,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final List<NewsCategory> categories = await context
          .read<NewsPortalRepository>()
          .categories();
      if (mounted) setState(() => _categories = categories);
    } on AppException {
      // The form still saves without them; a category is optional.
    }
  }

  Map<String, dynamic> get _values => <String, dynamic>{
    'title': _title.text.trim(),
    'excerpt': _excerpt.text.trim(),
    'body': _blocks.map((NewsBlock block) => block.toJson()).toList(growable: false),
    'category_id': _categoryId,
    'location': _location.text.trim(),
    'author_name': _author.text.trim(),
    'news_date': _newsDate?.toIso8601String().split('T').first,
    'tags': _tags.text
        .split(',')
        .map((String tag) => tag.trim())
        .where((String tag) => tag.isNotEmpty)
        .toList(growable: false),
  };

  /// Saves without changing the state. A draft stays a draft.
  Future<void> _save({String? thenStatus, String? statusNotice}) async {
    if (_title.text.trim().length < 4) {
      setState(() => _error = 'Give the story a headline first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final NewsPortalRepository repository = context.read<NewsPortalRepository>();

      if (_id == null) {
        _id = await repository.create(_values);
      } else {
        await repository.update(_id!, _values);
      }

      if (thenStatus != null) {
        await repository.setState(_id!, status: thenStatus);
      }

      if (mounted) {
        setState(() => _notice = statusNotice ?? 'Saved.');
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;
    final EditorialNews? existing = widget.existing;

    return WorkspaceShell(
      currentPath: AppRoutes.editorialNews,
      title: _id == null ? 'Write a story' : 'Edit a story',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.editorialNews),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('The newsroom'),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Write'),
                    icon: Icon(Icons.edit_outlined, size: 16),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Preview'),
                    icon: Icon(Icons.visibility_outlined, size: 16),
                  ),
                ],
                selected: <bool>{_preview},
                onSelectionChanged: (Set<bool> value) =>
                    setState(() => _preview = value.first),
              ),
            ],
          ),
          const Gap.xl(),

          if (existing != null && existing.reviewNotes != null) ...<Widget>[
            _Banner(
              icon: Icons.rate_review_outlined,
              colour: AppColors.gold,
              text: 'The last editorial note: ${existing.reviewNotes}',
            ),
            const Gap.lg(),
          ],
          if (_notice != null) ...<Widget>[
            _Banner(icon: Icons.check_circle_outline, colour: AppColors.green, text: _notice!),
            const Gap.lg(),
          ],
          if (_error != null) ...<Widget>[
            _Banner(
              icon: Icons.error_outline,
              colour: theme.colorScheme.error,
              text: _error!,
            ),
            const Gap.lg(),
          ],

          if (_preview)
            _Preview(
              title: _title.text.trim(),
              excerpt: _excerpt.text.trim(),
              blocks: _blocks,
              media: existing?.story.media ?? const <NewsMedia>[],
              category: _categories
                  .where((NewsCategory c) => c.id == _categoryId)
                  .map((NewsCategory c) => c.name)
                  .firstOrNull,
              date: _newsDate,
              location: _location.text.trim(),
            )
          else
            _Form(
              title: _title,
              excerpt: _excerpt,
              location: _location,
              author: _author,
              tags: _tags,
              categories: _categories,
              categoryId: _categoryId,
              onCategory: (String? id) => setState(() => _categoryId = id),
              newsDate: _newsDate,
              onDate: (DateTime? date) => setState(() => _newsDate = date),
              blocks: _blocks,
              onBlocks: (List<NewsBlock> blocks) => setState(() => _blocks = blocks),
              newsId: _id,
              media: existing?.story.media ?? const <NewsMedia>[],
              onMediaChanged: () => setState(() {}),
            ),

          const Gap.section(),
          _Actions(
            busy: _busy,
            status: existing?.status ?? 'draft',
            hasId: _id != null,
            onSave: _save,
            onSubmit: () => _save(
              thenStatus: 'pending_review',
              statusNotice: 'Sent for review. An editor will read it.',
            ),
            onPublish: () => _save(thenStatus: 'published', statusNotice: 'Published.'),
          ),
        ],
      ),
    );
  }
}

/// The form: the facts, then the story, then the pictures.
class _Form extends StatelessWidget {
  const _Form({
    required this.title,
    required this.excerpt,
    required this.location,
    required this.author,
    required this.tags,
    required this.categories,
    required this.categoryId,
    required this.onCategory,
    required this.newsDate,
    required this.onDate,
    required this.blocks,
    required this.onBlocks,
    required this.newsId,
    required this.media,
    required this.onMediaChanged,
  });

  final TextEditingController title;
  final TextEditingController excerpt;
  final TextEditingController location;
  final TextEditingController author;
  final TextEditingController tags;
  final List<NewsCategory> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final DateTime? newsDate;
  final ValueChanged<DateTime?> onDate;
  final List<NewsBlock> blocks;
  final ValueChanged<List<NewsBlock>> onBlocks;
  final String? newsId;
  final List<NewsMedia> media;
  final VoidCallback onMediaChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(
            labelText: 'The headline',
            hintText: 'What happened, in one line',
          ),
        ),
        const Gap.lg(),
        TextField(
          controller: excerpt,
          maxLines: 2,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Summary',
            helperText: 'The two lines under the headline. Left empty, it writes itself from '
                'the story.',
            helperMaxLines: 2,
            alignLabelWithHint: true,
          ),
        ),
        const Gap.lg(),

        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
                  ...categories.map(
                    (NewsCategory category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: onCategory,
              ),
            ),
            SizedBox(
              width: 240,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final DateTime now = DateTime.now();
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: newsDate ?? now,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 1),
                    helpText: 'When did it happen?',
                  );
                  if (picked != null) onDate(picked);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  newsDate == null
                      ? 'When it happened'
                      : Formatters.date(newsDate!.toIso8601String()),
                ),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Where'),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: author,
                decoration: const InputDecoration(labelText: 'Written by'),
              ),
            ),
          ],
        ),
        const Gap.lg(),
        TextField(
          controller: tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            helperText: 'Separated by commas. A tag the list does not have is added to it.',
            helperMaxLines: 2,
          ),
        ),

        const Gap.section(),
        Text('The story', style: theme.textTheme.titleLarge),
        const Gap.sm(),
        Text(
          'Built from blocks. Nobody writes markup, and nothing you add here can become script '
          'on the page.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap.lg(),
        _BlockEditor(blocks: blocks, onChanged: onBlocks, media: media),

        const Gap.section(),
        Text('Photographs and film', style: theme.textTheme.titleLarge),
        const Gap.sm(),
        Text(
          newsId == null
              ? 'Save the story first, then add its photographs and videos here.'
              : 'Photographs come from the media library. Videos stay on YouTube — paste the '
                    'link and the story carries the player.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap.lg(),
        if (newsId != null) _MediaManager(newsId: newsId!, media: media, onChanged: onMediaChanged),
      ],
    );
  }
}

/// The block editor.
class _BlockEditor extends StatelessWidget {
  const _BlockEditor({required this.blocks, required this.onChanged, required this.media});

  final List<NewsBlock> blocks;
  final ValueChanged<List<NewsBlock>> onChanged;
  final List<NewsMedia> media;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...blocks.asMap().entries.map(
          (MapEntry<int, NewsBlock> entry) => _BlockRow(
            key: ValueKey<int>(entry.key),
            index: entry.key,
            block: entry.value,
            total: blocks.length,
            media: media,
            onChanged: (NewsBlock updated) {
              final List<NewsBlock> next = List<NewsBlock>.from(blocks);
              next[entry.key] = updated;
              onChanged(next);
            },
            onRemove: () {
              final List<NewsBlock> next = List<NewsBlock>.from(blocks)..removeAt(entry.key);
              onChanged(
                next.isEmpty ? <NewsBlock>[const NewsBlock(type: 'paragraph', text: '')] : next,
              );
            },
            onMove: (int by) {
              final int target = entry.key + by;
              if (target < 0 || target >= blocks.length) return;
              final List<NewsBlock> next = List<NewsBlock>.from(blocks);
              final NewsBlock moved = next.removeAt(entry.key);
              next.insert(target, moved);
              onChanged(next);
            },
          ),
        ),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <({String type, String label, IconData icon})>[
            (type: 'paragraph', label: 'Paragraph', icon: Icons.notes),
            (type: 'heading', label: 'Heading', icon: Icons.title),
            (type: 'quote', label: 'Quote', icon: Icons.format_quote),
            (type: 'bullet_list', label: 'Bullets', icon: Icons.format_list_bulleted),
            (type: 'numbered_list', label: 'Numbers', icon: Icons.format_list_numbered),
            (type: 'divider', label: 'Rule', icon: Icons.horizontal_rule),
          ]
              .map(
                (({String type, String label, IconData icon}) option) => OutlinedButton.icon(
                  onPressed: () => onChanged(<NewsBlock>[
                    ...blocks,
                    NewsBlock(
                      type: option.type,
                      text: option.type == 'divider' ? null : '',
                      items: option.type.endsWith('_list') ? const <String>[''] : const <String>[],
                    ),
                  ]),
                  icon: Icon(option.icon, size: 16),
                  label: Text(option.label),
                ),
              )
              .toList(growable: false),
        ),
        if (media.isNotEmpty) ...<Widget>[
          const Gap.md(),
          Text(
            'To place a photograph or a video inside the story, add it below and press '
            '"Put in the story".',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// One block, with its controls.
class _BlockRow extends StatefulWidget {
  const _BlockRow({
    required this.index,
    required this.block,
    required this.total,
    required this.media,
    required this.onChanged,
    required this.onRemove,
    required this.onMove,
    super.key,
  });

  final int index;
  final NewsBlock block;
  final int total;
  final List<NewsMedia> media;
  final ValueChanged<NewsBlock> onChanged;
  final VoidCallback onRemove;
  final ValueChanged<int> onMove;

  @override
  State<_BlockRow> createState() => _BlockRowState();
}

class _BlockRowState extends State<_BlockRow> {
  late final TextEditingController _text = TextEditingController(text: widget.block.text ?? '');
  late final TextEditingController _items = TextEditingController(
    text: widget.block.items.join('\n'),
  );

  @override
  void dispose() {
    _text.dispose();
    _items.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NewsBlock block = widget.block;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              children: <Widget>[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  onPressed: widget.index > 0 ? () => widget.onMove(-1) : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  onPressed: widget.index < widget.total - 1 ? () => widget.onMove(1) : null,
                ),
              ],
            ),
            const Gap.hSm(),
            Expanded(child: _field(block, theme)),
            IconButton(
              tooltip: 'Remove this block',
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(NewsBlock block, ThemeData theme) {
    switch (block.type) {
      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Divider(),
        );

      case 'image':
        final NewsMedia? photograph = widget.media
            .where((NewsMedia item) => item.id == block.mediaId)
            .firstOrNull;
        return Row(
          children: <Widget>[
            if (photograph?.url != null)
              ClipRRect(
                borderRadius: AppRadius.xsAll,
                child: Image.network(photograph!.url!, width: 80, height: 56, fit: BoxFit.cover),
              ),
            const Gap.hMd(),
            Expanded(
              child: Text(
                photograph?.caption ?? 'A photograph from this story',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );

      case 'video':
        return Row(
          children: <Widget>[
            const Icon(Icons.play_circle_outline, color: AppColors.gold),
            const Gap.hMd(),
            Expanded(
              child: Text(
                block.caption ?? 'A video from this story',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );

      case 'bullet_list':
      case 'numbered_list':
        return TextField(
          controller: _items,
          minLines: 3,
          maxLines: 12,
          decoration: InputDecoration(
            labelText: block.type == 'bullet_list' ? 'Bullet points' : 'Numbered points',
            helperText: 'One per line.',
            border: InputBorder.none,
          ),
          onChanged: (String value) => widget.onChanged(
            block.copyWith(
              items: value
                  .split('\n')
                  .map((String line) => line.trim())
                  .where((String line) => line.isNotEmpty)
                  .toList(growable: false),
            ),
          ),
        );

      case 'heading':
        return Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _text,
                style: theme.textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'A heading',
                  border: InputBorder.none,
                ),
                onChanged: (String value) => widget.onChanged(block.copyWith(text: value)),
              ),
            ),
            DropdownButton<int>(
              value: block.level,
              underline: const SizedBox.shrink(),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 2, child: Text('Large')),
                DropdownMenuItem<int>(value: 3, child: Text('Medium')),
                DropdownMenuItem<int>(value: 4, child: Text('Small')),
              ],
              onChanged: (int? level) =>
                  widget.onChanged(block.copyWith(level: level ?? block.level)),
            ),
          ],
        );

      default:
        return TextField(
          controller: _text,
          minLines: block.type == 'quote' ? 2 : 3,
          maxLines: 20,
          textCapitalization: TextCapitalization.sentences,
          style: block.type == 'quote'
              ? theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)
              : null,
          decoration: InputDecoration(
            hintText: block.type == 'quote' ? 'What somebody said' : 'Write here',
            border: InputBorder.none,
          ),
          onChanged: (String value) => widget.onChanged(block.copyWith(text: value)),
        );
    }
  }
}

/// The photographs and film attached to a story.
class _MediaManager extends StatefulWidget {
  const _MediaManager({required this.newsId, required this.media, required this.onChanged});

  final String newsId;
  final List<NewsMedia> media;
  final VoidCallback onChanged;

  @override
  State<_MediaManager> createState() => _MediaManagerState();
}

class _MediaManagerState extends State<_MediaManager> {
  final TextEditingController _youtube = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _youtube.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.media.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: widget.media
                .map((NewsMedia item) => _MediaTile(newsId: widget.newsId, item: item, onChanged: widget.onChanged))
                .toList(growable: false),
          ),
          const Gap.xl(),
        ],

        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPhotograph,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Add a photograph'),
            ),
            SizedBox(
              width: 340,
              child: TextField(
                controller: _youtube,
                decoration: const InputDecoration(
                  labelText: 'Paste a YouTube link',
                  isDense: true,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: _busy ? null : _addVideo,
              child: const Text('Add the video'),
            ),
          ],
        ),
        const Gap.sm(),
        Text(
          'Videos are not uploaded here. They stay on YouTube, and the story carries the '
          'player — which keeps the archive’s storage for the photographs that exist nowhere '
          'else.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _addVideo() async {
    final String url = _youtube.text.trim();
    if (url.isEmpty) return;

    setState(() => _busy = true);
    try {
      await context.read<NewsPortalRepository>().addMedia(
        widget.newsId,
        mediaType: 'youtube_video',
        youtubeUrl: url,
      );
      _youtube.clear();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video added. Reopen to see it.')));
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Photographs come from the media library rather than a second upload path.
  ///
  /// Everything that reaches R2 goes through the media service, which checks
  /// the type and the size against a per-folder allow-list. A second upload
  /// route would be a second place for those checks to be forgotten.
  Future<void> _pickPhotograph() async {
    final MediaRepository media = context.read<MediaRepository>();

    final MediaAsset? chosen = await showDialog<MediaAsset>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Choose a photograph'),
        content: SizedBox(
          width: 640,
          height: 460,
          child: AsyncContent<List<MediaAsset>>(
            load: () async => (await media.list(folder: 'images', perPage: 60)).items,
            loadingMessage: 'Opening the library…',
            isEmpty: (List<MediaAsset> items) => items.isEmpty,
            emptyBuilder: (BuildContext context) => const Center(
              child: Text('Nothing in the library yet. Upload photographs there first.'),
            ),
            builder: (BuildContext context, List<MediaAsset> items) => GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              children: items
                  .map(
                    (MediaAsset asset) => GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(asset),
                      child: ClipRRect(
                        borderRadius: AppRadius.xsAll,
                        child: Image.network(
                          asset.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0x11000000)),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<NewsPortalRepository>().addMedia(
        widget.newsId,
        mediaType: 'image',
        mediaId: chosen.id,
        caption: chosen.title,
        altText: chosen.altText,
        photographer: chosen.credit,
      );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added. Reopen the story to see it.')));
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.newsId, required this.item, required this.onChanged});

  final String newsId;
  final NewsMedia item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: (item.url ?? item.thumbnailUrl) == null
                  ? ColoredBox(color: theme.colorScheme.surfaceContainerHigh)
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.network((item.url ?? item.thumbnailUrl)!, fit: BoxFit.cover),
                        if (item.isVideo)
                          const Center(
                            child: Icon(Icons.play_circle, color: Colors.white, size: 32),
                          ),
                      ],
                    ),
            ),
          ),
          const Gap.xs(),
          Text(
            item.caption ?? item.videoTitle ?? (item.isVideo ? 'Video' : 'Photograph'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () async {
                  try {
                    await context.read<NewsPortalRepository>().removeMedia(newsId, item.id);
                    onChanged();
                  } on AppException catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.message)));
                    }
                  }
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the public will see, rendered by the public renderer.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.title,
    required this.excerpt,
    required this.blocks,
    required this.media,
    required this.category,
    required this.date,
    required this.location,
  });

  final String title;
  final String excerpt;
  final List<NewsBlock> blocks;
  final List<NewsMedia> media;
  final String? category;
  final DateTime? date;
  final String location;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (category != null)
              Text(
                category!.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.goldDark,
                  letterSpacing: 1.6,
                ),
              ),
            const Gap.sm(),
            Text(
              title.isEmpty ? 'Untitled' : title,
              style: context.isMobile
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.displaySmall?.copyWith(height: 1.15),
            ),
            if (excerpt.isNotEmpty) ...<Widget>[
              const Gap.lg(),
              Text(
                excerpt,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            const Gap.lg(),
            Text(
              <String>[
                if (date != null) Formatters.date(date!.toIso8601String()),
                if (location.isNotEmpty) location,
              ].join('  ·  '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap.xl(),
            const Divider(height: 1),
            const Gap.xl(),
            // The same widget the public page uses. Not an approximation of it.
            NewsBody(blocks: blocks, media: media),
          ],
        ),
      ),
    );
  }
}

/// Save, send for review, publish.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.busy,
    required this.status,
    required this.hasId,
    required this.onSave,
    required this.onSubmit,
    required this.onPublish,
  });

  final bool busy;
  final String status;
  final bool hasId;
  final VoidCallback onSave;
  final VoidCallback onSubmit;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton.icon(
            onPressed: busy ? null : onSave,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save the draft'),
          ),
          OutlinedButton(
            onPressed: busy ? null : onSubmit,
            child: const Text('Send for review'),
          ),
          // Publishing is a separate permission on the server. The button is
          // shown to everybody who can edit, and the API refuses whoever may
          // not — hiding it here would be a courtesy, not a control.
          OutlinedButton(
            onPressed: busy ? null : onPublish,
            child: const Text('Publish now'),
          ),
          Text(
            'This story is ${NewsStatus.label(status).toLowerCase()}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.colour, required this.text});

  final IconData icon;
  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: colour.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colour),
          const Gap.hMd(),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
