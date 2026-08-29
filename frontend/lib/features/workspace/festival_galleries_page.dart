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
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/gallery.dart';
import '../../repositories/gallery_repository.dart';
import '../../services/api/mime_types.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// FESTIVAL PHOTOGRAPHS.
///
/// The screen that makes "a photograph belongs to a year" true in practice.
///
/// Every festival edition owns one album, and this lists them by year so a
/// Media Team volunteer picks 2026 rather than hunting for an album by name.
/// Opening a year and dropping forty photographs into it files all forty under
/// that festival — and because a festival album is an ordinary gallery, the
/// same photographs appear in the main Gallery section without being uploaded
/// a second time.
///
/// Albums are created by being asked for: the list creates any that is missing
/// as it loads, so an edition added before festivals had galleries repairs
/// itself by somebody looking at it.
class FestivalGalleriesPage extends StatefulWidget {
  const FestivalGalleriesPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<FestivalGalleriesPage> createState() => _FestivalGalleriesPageState();
}

class _FestivalGalleriesPageState extends State<FestivalGalleriesPage> {
  int _reloads = 0;
  String? _openAlbumId;
  String? _notice;

  void _reload([String? notice]) {
    setState(() {
      _reloads += 1;
      _notice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GalleryRepository repository = context.read<GalleryRepository>();

    final bool isAdmin = widget.workspace == WorkspaceKind.admin;
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath:
          isAdmin ? AppRoutes.adminFestivalGalleries : AppRoutes.editorialFestivalGalleries,
      title: 'Festival photographs and film',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Every festival has one album, and a photograph put into it is filed under that year '
            'for good. The same photographs also appear in the main Gallery — one upload, not two.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.xxl(),
          if (_notice != null) ...<Widget>[
            _NoticeBanner(message: _notice!),
            const Gap.xl(),
          ],
          AsyncContent<List<FestivalWithYears>>(
            key: ValueKey<int>(_reloads),
            load: repository.festivalAlbums,
            loadingMessage: 'Opening the festivals…',
            isEmpty: (List<FestivalWithYears> items) => items.isEmpty,
            emptyBuilder: (BuildContext context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const EmptyView(
                  icon: Icons.celebration_outlined,
                  title: 'No festivals recorded yet',
                  message:
                      'Record a festival first — Leboku, Odagum, Ekpirikum — and then add a year '
                      'to it for each celebration you have photographs of.',
                  showContributeAction: false,
                ),
                const Gap.lg(),
                FilledButton.icon(
                  onPressed: _createFestival,
                  icon: const Icon(Icons.add),
                  label: const Text('Record a festival'),
                ),
              ],
            ),
            builder: (BuildContext context, List<FestivalWithYears> festivals) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final FestivalWithYears festival in festivals)
                    _FestivalBlock(
                      festival: festival,
                      openAlbumId: _openAlbumId,
                      onToggleAlbum: (String id) => setState(
                        () => _openAlbumId = _openAlbumId == id ? null : id,
                      ),
                      onAddYear: () => _addYear(festival),
                      onChanged: _reload,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Records a festival. The parent only — a festival just recorded has no
  /// year yet, and inventing one would put an empty year in the timeline.
  Future<void> _createFestival() async {
    final _NewFestival? result = await showDialog<_NewFestival>(
      context: context,
      builder: (BuildContext context) => const _NewFestivalDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await context.read<GalleryRepository>().createFestival(
            name: result.name,
            shortDescription: result.shortDescription,
            usuallyCelebrated: result.usuallyCelebrated,
          );
      _reload('${result.name} is recorded. Add a year to it when you have photographs.');
    } on AppException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    }
  }

  /// Adds a year to an existing festival.
  Future<void> _addYear(FestivalWithYears festival) async {
    final int? year = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _AddYearDialog(festival: festival),
    );
    if (year == null || !mounted) return;

    try {
      final String message = await context.read<GalleryRepository>().addFestivalYear(
            festivalId: festival.festivalId,
            year: year,
          );
      _reload(message);
    } on AppException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    }
  }
}

/// One festival, with its years under it.
class _FestivalBlock extends StatelessWidget {
  const _FestivalBlock({
    required this.festival,
    required this.openAlbumId,
    required this.onToggleAlbum,
    required this.onAddYear,
    required this.onChanged,
  });

  final FestivalWithYears festival;
  final String? openAlbumId;
  final ValueChanged<String> onToggleAlbum;
  final VoidCallback onAddYear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(festival.festivalName, style: theme.textTheme.titleLarge),
                    if ((festival.shortDescription ?? '').isNotEmpty)
                      Text(
                        festival.shortDescription!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAddYear,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add a year'),
              ),
            ],
          ),
          const Gap.md(),
          if (festival.years.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.mdAll,
              ),
              child: Text(
                'No years recorded yet. Add one for each celebration you have photographs or '
                'film of — they will appear on the festival page and in the Gallery.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (final FestivalYear year in festival.years)
              _AlbumRow(
                festivalName: festival.festivalName,
                year: year,
                expanded: openAlbumId == year.galleryId,
                onToggle: () => onToggleAlbum(year.galleryId),
                onChanged: onChanged,
              ),
        ],
      ),
    );
  }
}

/// What the "record a festival" dialog collects.
class _NewFestival {
  const _NewFestival({
    required this.name,
    this.shortDescription,
    this.usuallyCelebrated,
  });

  final String name;
  final String? shortDescription;
  final String? usuallyCelebrated;
}

class _NewFestivalDialog extends StatefulWidget {
  const _NewFestivalDialog();

  @override
  State<_NewFestivalDialog> createState() => _NewFestivalDialogState();
}

class _NewFestivalDialogState extends State<_NewFestivalDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _short = TextEditingController();
  final TextEditingController _when = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _when.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a festival'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'The festival itself, not one year of it. Its history and significance can be '
              'written in full afterwards; the years are added one at a time.',
            ),
            const Gap.lg(),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Leboku, Odagum, Ekpirikum',
              ),
            ),
            const Gap.md(),
            TextField(
              controller: _short,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'In one line',
                hintText: 'What somebody should know about it at a glance',
              ),
            ),
            const Gap.md(),
            TextField(
              controller: _when,
              decoration: const InputDecoration(
                labelText: 'When it is usually celebrated',
                hintText: 'The last week of August, after the yam harvest',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final String name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _NewFestival(
                name: name,
                shortDescription: _short.text.trim().isEmpty ? null : _short.text.trim(),
                usuallyCelebrated: _when.text.trim().isEmpty ? null : _when.text.trim(),
              ),
            );
          },
          child: const Text('Record it'),
        ),
      ],
    );
  }
}

class _AddYearDialog extends StatefulWidget {
  const _AddYearDialog({required this.festival});

  final FestivalWithYears festival;

  @override
  State<_AddYearDialog> createState() => _AddYearDialogState();
}

class _AddYearDialogState extends State<_AddYearDialog> {
  late final TextEditingController _year =
      TextEditingController(text: DateTime.now().year.toString());
  String? _error;

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add a year to ${widget.festival.festivalName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'An album for that year’s celebration. It appears on the festival page and in '
            'the Gallery — one album, both places, so a photograph added in either is in '
            'both.',
          ),
          const Gap.lg(),
          TextField(
            controller: _year,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Year',
              errorText: _error,
            ),
          ),
          if (widget.festival.recordedYears.isNotEmpty) ...<Widget>[
            const Gap.md(),
            Text(
              'Already recorded: ${(widget.festival.recordedYears.toList()..sort()).reversed.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final int? year = int.tryParse(_year.text.trim());
            if (year == null || year < 1900 || year > 2200) {
              setState(() => _error = 'Give a year between 1900 and 2200.');
              return;
            }
            if (widget.festival.recordedYears.contains(year)) {
              setState(() => _error = 'That year is already recorded.');
              return;
            }
            Navigator.of(context).pop(year);
          },
          child: const Text('Add the year'),
        ),
      ],
    );
  }
}

/// What just happened, said once above the list.
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.greenDark),
          const Gap.hMd(),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({
    required this.festivalName,
    required this.year,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final String festivalName;
  final FestivalYear year;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.mdAll,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const Gap.hMd(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              year.year == null
                                  ? year.galleryTitle
                                  : '$festivalName ${year.year}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const Gap.hMd(),
                            StatusBadge(year.galleryStatus),
                          ],
                        ),
                        const Gap.xs(),
                        Text(
                          year.holdings,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _upload(context, year, onChanged),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Add photographs or video'),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: _AlbumContents(year: year, onChanged: onChanged),
            ),
        ],
      ),
    );
  }
}

class _AlbumContents extends StatelessWidget {
  const _AlbumContents({required this.year, required this.onChanged});

  final FestivalYear year;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final GalleryRepository repository = context.read<GalleryRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<({Gallery gallery, List<Photograph> items, Map<String, int> counts})>(
      load: () => repository.manage(year.galleryId),
      loadingMessage: 'Opening the album…',
      builder: (
        BuildContext context,
        ({Gallery gallery, List<Photograph> items, Map<String, int> counts}) data,
      ) {
        if (data.items.isEmpty) {
          return Text(
            'Nothing in this album yet. Photographs added here are filed under '
            '${year.galleryTitle} and appear in the main Gallery as well.',
            style: theme.textTheme.bodySmall,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.items
              .map(
                (Photograph photograph) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: AppRadius.smAll,
                        // A video has no still to show here, and putting its
                        // URL through Image.network would land in the error
                        // builder — a broken-picture icon on a file that is
                        // perfectly fine.
                        child: photograph.isVideo
                            ? Container(
                                width: 64,
                                height: 48,
                                color: Colors.black,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                              )
                            : Image.network(
                                photograph.url,
                                width: 64,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stack,
                                ) =>
                                    Container(
                                  width: 64,
                                  height: 48,
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  child: const Icon(Icons.image_not_supported_outlined, size: 16),
                                ),
                              ),
                      ),
                      const Gap.hMd(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              // Naming an undescribed picture as such is the
                              // point of this screen: cataloguing is the step
                              // that turns it into a record somebody can find.
                              photograph.caption ?? 'Not yet described',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: photograph.caption == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            // Undated is called out for the same reason
                            // undescribed is. A missing date is invisible
                            // otherwise, and it is the label most often
                            // forgotten and hardest to recover later.
                            Text(
                              photograph.takenAt ?? 'No date recorded',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: photograph.takenAt == null
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (photograph.status != null) StatusBadge(photograph.status!),
                      IconButton(
                        onPressed: () => _label(context, photograph, onChanged),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Describe this, and date it',
                      ),
                      IconButton(
                        onPressed: () => _remove(context, photograph, onChanged),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remove from this album',
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

Future<void> _upload(
  BuildContext context,
  FestivalYear year,
  ValueChanged<String> onChanged,
) async {
  final FilePickerResult? picked = await FilePicker.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.custom,
    // Photographs and short clips together. Four seconds of the Mr and Miss
    // Leboku crowning belongs in that year's album beside the stills, not on
    // another platform behind a pasted link.
    allowedExtensions: UploadExtensions.gallery,
  );
  if (picked == null || picked.files.isEmpty || !context.mounted) return;

  final GalleryRepository repository = context.read<GalleryRepository>();
  int uploaded = 0;
  String? firstError;

  for (final PlatformFile file in picked.files) {
    final Uint8List? bytes = file.bytes;
    if (bytes == null) continue;
    try {
      await repository.uploadIntoAlbum(
        galleryId: year.galleryId,
        bytes: bytes,
        filename: file.name,
        folder: MediaFolders.leboku,
      );
      uploaded += 1;
    } on AppException catch (error) {
      firstError ??= '${file.name}: ${error.message}';
    }
  }

  if (!context.mounted) return;

  onChanged(
    firstError != null
        ? '$uploaded of ${picked.files.length} uploaded. $firstError'
        : '$uploaded file${uploaded == 1 ? '' : 's'} added to ${year.galleryTitle}. They are in '
            'the main Gallery too. Describe and date each one so it can still be found in fifty '
            'years.',
  );
}

/// CATALOGUING ONE PICTURE.
///
/// The labels are what turn a picture into a record somebody can find in fifty
/// years. Without them an album is a pile of images that only the person who
/// took them can explain, and that person will not always be here.
///
/// THE DATE.
///
/// This dialog used to ask what a picture showed, who was in it, who took it
/// and where — and never when. `taken_at` existed in the database, the API
/// accepted it and the public page displayed it; the only thing missing was a
/// field, so every picture in the archive was undated.
///
/// It takes free text rather than only a picker, because the archive's most
/// valuable photographs are old ones where nobody remembers more than the
/// year. "1998" has to be a permissible answer, or the honest response to a
/// required date field is a made-up one.
Future<void> _label(
  BuildContext context,
  Photograph photograph,
  ValueChanged<String> onChanged,
) async {
  final TextEditingController caption = TextEditingController(text: photograph.caption ?? '');
  final TextEditingController people =
      TextEditingController(text: photograph.peoplePictured ?? '');
  final TextEditingController photographer =
      TextEditingController(text: photograph.photographer ?? '');
  final TextEditingController location = TextEditingController(text: photograph.location ?? '');
  final TextEditingController takenAt = TextEditingController(text: photograph.takenAt ?? '');

  final bool save = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('Describe this ${photograph.kindNoun}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: caption,
                    decoration: InputDecoration(
                      labelText: 'What does it show?',
                      helperText: photograph.isVideo
                          ? 'One sentence. This is what a visitor reads under the video.'
                          : 'One sentence. This is what a visitor reads under the picture.',
                    ),
                  ),
                  const Gap.lg(),
                  TextField(
                    controller: people,
                    decoration: const InputDecoration(
                      labelText: 'Who is pictured',
                      helperText: 'Names, left to right where you can. Titles too — "Mr Leboku '
                          '2026", "Miss Leboku 2026" — so the crowning can be found by name.',
                    ),
                  ),
                  const Gap.lg(),
                  _TakenAtField(controller: takenAt),
                  const Gap.lg(),
                  TextField(
                    controller: photographer,
                    decoration: InputDecoration(
                      labelText: photograph.isVideo ? 'Who filmed it' : 'Who took it',
                    ),
                  ),
                  const Gap.lg(),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Where'),
                  ),
                ],
              ),
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

  if (!save || !context.mounted) return;

  try {
    await context.read<GalleryRepository>().label(
          photograph.id,
          caption: caption.text.trim(),
          peoplePictured: people.text.trim(),
          photographer: photographer.text.trim(),
          location: location.text.trim(),
          takenAt: takenAt.text.trim(),
        );
    onChanged('Saved.');
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// The date field: type it, or pick it.
///
/// Both, deliberately. A picker is quicker for last Saturday and useless for a
/// photograph from the eighties, where the true answer is a year and a shrug.
class _TakenAtField extends StatelessWidget {
  const _TakenAtField({required this.controller});

  final TextEditingController controller;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? chosen = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text.trim()) ?? now,
      // Far enough back for the oldest photograph anybody is likely to hold.
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (chosen == null) return;

    controller.text = chosen.toIso8601String().split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'When was it taken?',
        helperText: 'A full date where you know it. A year on its own is fine — "1998" is worth '
            'far more than nothing.',
        hintText: 'YYYY-MM-DD, or just the year',
        suffixIcon: IconButton(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          tooltip: 'Choose a date',
        ),
      ),
    );
  }
}

Future<void> _remove(
  BuildContext context,
  Photograph photograph,
  ValueChanged<String> onChanged,
) async {
  final bool confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Take this out of the album?'),
          content: const Text(
            'The photograph stays in the media library — only its place in this album is removed. '
            'Nothing is deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed || !context.mounted) return;

  try {
    await context.read<GalleryRepository>().removeFromAlbum(photograph.id);
    onChanged('Removed from the album. The photograph is still in the media library.');
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
