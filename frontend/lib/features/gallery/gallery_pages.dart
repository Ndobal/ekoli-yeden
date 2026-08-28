import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/video/archive_video.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/gallery.dart';
import '../../repositories/gallery_repository.dart';
import '../videos/video_pages.dart' show VideoBrowser;
import '../../services/api/api_response.dart';

/// THE PHOTO GALLERY.
///
/// A gallery is an ordered set of photographs plus the labels that turn a
/// picture into an archive record: who is in it, where, when, and who took it.
/// Those labels are what make a photograph findable in fifty years; an
/// unlabelled photograph is preserved but not yet documented, and the archive
/// says which it is.
///
/// Festival photographs reach this section without being filed twice. Every
/// festival edition owns an album, and a festival album is an ordinary gallery
/// — so a picture from Leboku 2026 is in that year's album, in the album list
/// here, and in the combined stream below, from one upload.
class GalleryListPage extends StatefulWidget {
  const GalleryListPage({this.initialTab = GalleryTab.photographs, super.key});

  /// Which tab opens. `/videos` still resolves and opens on the film.
  final GalleryTab initialTab;

  @override
  State<GalleryListPage> createState() => _GalleryListPageState();
}

/// The two halves of the same question.
enum GalleryTab { photographs, videos }

class _GalleryListPageState extends State<GalleryListPage> {
  /// The album being shown, or null for everything.
  AlbumSummary? _album;
  int _page = 1;
  late GalleryTab _tab = widget.initialTab;

  void _choose(AlbumSummary? album) {
    setState(() {
      _album = album;
      // Page 3 of one album is not page 3 of another, and landing on an empty
      // page after changing the filter reads as an album with nothing in it.
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GalleryRepository repository = context.read<GalleryRepository>();

    return AppScaffold(
      currentPath: AppRoutes.gallery,
      seo: const SeoMetadata(
        title: 'Gallery',
        description:
            'Photographs and film of Ekoli-Yeden — its people, ceremonies, festivals, schools and '
            'everyday life — labelled with what they show.',
        canonicalPath: AppRoutes.gallery,
      ),
      child: PageSection(
        eyebrow: 'Photographs and film',
        title: 'Gallery',
        description:
            'Pictures and film of Ekoli-Yeden — its people, ceremonies, festivals and everyday '
            'life.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Photographs and film, in one section.
            //
            // They answer the same question — "show me what this looked like" —
            // and keeping them in two sections meant somebody looking for the
            // festival found half of it and assumed that was all there was.
            SegmentedButton<GalleryTab>(
              segments: const <ButtonSegment<GalleryTab>>[
                ButtonSegment<GalleryTab>(
                  value: GalleryTab.photographs,
                  label: Text('Photographs'),
                  icon: Icon(Icons.photo_library_outlined, size: 18),
                ),
                ButtonSegment<GalleryTab>(
                  value: GalleryTab.videos,
                  label: Text('Videos'),
                  icon: Icon(Icons.play_circle_outline, size: 18),
                ),
              ],
              selected: <GalleryTab>{_tab},
              onSelectionChanged: (Set<GalleryTab> value) =>
                  setState(() => _tab = value.first),
            ),
            const Gap.xxl(),
            if (_tab == GalleryTab.videos)
              const VideoBrowser()
            else
              _photographs(repository),
          ],
        ),
      ),
    );
  }

  Widget _photographs(GalleryRepository repository) {
    return AsyncContent<List<AlbumSummary>>(
          load: repository.albums,
          loadingMessage: 'Opening the archive…',
          // No albums at all is a different situation from an album with
          // nothing in it, and only the first is worth a whole empty state.
          isEmpty: (List<AlbumSummary> albums) => albums.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyView(
            icon: Icons.photo_library_outlined,
            title: 'The gallery is being prepared',
            message:
                'Photographs will appear here as they are collected, labelled and verified. If you '
                'have old pictures of Ekoli-Yeden, they are among the most valuable things this '
                'archive can receive.',
          ),
          builder: (BuildContext context, List<AlbumSummary> albums) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AlbumFilterBar(albums: albums, selected: _album, onChanged: _choose),
                if (_album != null) ...<Widget>[
                  const Gap.lg(),
                  _SelectedAlbumNote(album: _album!),
                ],
                const Gap.xl(),
                _PhotographResults(
                  // Keyed on both, so changing either starts a fresh load
                  // rather than showing the previous album's pictures under
                  // the new album's name.
                  key: ValueKey<String>('${_album?.id ?? 'all'}:$_page'),
                  albumId: _album?.id,
                  albumName: _album?.title,
                  page: _page,
                  onPage: (int page) => setState(() => _page = page),
                ),
              ],
            );
          },
    );
  }
}

/// THE FILTER BAR.
///
/// This section used to open on a list of albums rendered as text cards — a
/// title and three lines of description each — so that somebody arriving at the
/// gallery of a photographic archive read several paragraphs of prose and had
/// to click before seeing a single picture.
///
/// The albums are still here, because "show me Leboku 2026" is a real question.
/// They are a row of filters now, and the pictures are underneath them, where
/// somebody arriving at a gallery expects to find them.
class _AlbumFilterBar extends StatelessWidget {
  const _AlbumFilterBar({
    required this.albums,
    required this.selected,
    required this.onChanged,
  });

  final List<AlbumSummary> albums;
  final AlbumSummary? selected;
  final ValueChanged<AlbumSummary?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // An album nobody has filled yet is noise in a filter bar: pressing it
    // shows nothing and teaches a visitor that the filters are unreliable. The
    // Media Team still sees every album, empty or not, in the workspace.
    final List<AlbumSummary> filled =
        albums.where((AlbumSummary album) => !album.isEmpty).toList(growable: false);

    if (filled.isEmpty) return const SizedBox.shrink();

    final int total = filled.fold<int>(0, (int sum, AlbumSummary a) => sum + a.itemCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Albums', style: theme.textTheme.labelLarge),
        const Gap.sm(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _AlbumChip(
              label: 'Everything',
              count: total,
              selected: selected == null,
              onSelected: () => onChanged(null),
            ),
            ...filled.map(
              (AlbumSummary album) => _AlbumChip(
                label: album.title,
                count: album.itemCount,
                videoCount: album.videoCount,
                // A festival year is marked: those are the albums a visitor
                // most often arrives looking for.
                icon: album.isFestivalGallery ? Icons.celebration_outlined : null,
                selected: selected?.id == album.id,
                onSelected: () => onChanged(album),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AlbumChip extends StatelessWidget {
  const _AlbumChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.videoCount = 0,
  });

  final String label;
  final int count;
  final int videoCount;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color meta = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return FilterChip(
      selected: selected,
      onSelected: (bool _) => onSelected(),
      avatar: icon == null ? null : Icon(icon, size: 16),
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const Gap.hXs(),
          Text(
            Formatters.number(count),
            style: theme.textTheme.labelSmall?.copyWith(color: meta),
          ),
          // Film in an album is worth advertising: it is rarer than a
          // photograph, and it is the thing a visitor did not expect to find.
          if (videoCount > 0) ...<Widget>[
            const Gap.hXs(),
            Icon(Icons.play_circle_outline, size: 14, color: meta),
          ],
        ],
      ),
    );
  }
}

/// One line about the chosen album, and a way into its own page.
///
/// The description sits here rather than in the filter bar because it is worth
/// reading once you have chosen an album, and worth nobody's time before that.
class _SelectedAlbumNote extends StatelessWidget {
  const _SelectedAlbumNote({required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(album.title, style: theme.textTheme.titleMedium)),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.galleryAlbum(album.slug)),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Open album'),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          if (album.description != null) ...<Widget>[
            const Gap.sm(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: Text(album.description!, style: theme.textTheme.bodyMedium),
            ),
          ],
          if (album.eventDate != null || album.location != null) ...<Widget>[
            const Gap.md(),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (album.eventDate != null)
                  _Fact(
                    icon: Icons.calendar_today_outlined,
                    text: Formatters.date(album.eventDate),
                  ),
                if (album.location != null)
                  _Fact(icon: Icons.place_outlined, text: album.location!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The pictures themselves, filtered and paged.
class _PhotographResults extends StatelessWidget {
  const _PhotographResults({
    required this.albumId,
    required this.albumName,
    required this.page,
    required this.onPage,
    super.key,
  });

  final String? albumId;
  final String? albumName;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final GalleryRepository repository = context.read<GalleryRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<PaginatedResult<Photograph>>(
      load: () => repository.photographs(page: page, perPage: 36, galleryId: albumId),
      loadingMessage: 'Loading the pictures…',
      isEmpty: (PaginatedResult<Photograph> result) => result.isEmpty,
      emptyBuilder: (BuildContext context) => EmptyView(
        icon: Icons.photo_library_outlined,
        title: albumName == null ? 'No photographs yet' : 'Nothing published in $albumName yet',
        message: albumName == null
            ? 'Pictures will appear here as they are collected and labelled. If you have old '
                'photographs of Ekoli-Yeden, they are among the most valuable things this archive '
                'can receive.'
            : 'Nothing from this album has been published yet. If you took photographs or filmed '
                'any of it, they belong here.',
      ),
      builder: (BuildContext context, PaginatedResult<Photograph> result) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              albumName == null
                  ? '${Formatters.number(result.total)} in the archive'
                  : '${Formatters.number(result.total)} in $albumName',
              style: theme.textTheme.labelMedium,
            ),
            const Gap.lg(),
            // The album name appears on each tile only when looking at
            // everything; under a chosen album it would repeat the heading on
            // every single picture.
            PhotographGrid(photographs: result.items, showAlbum: albumId == null),
            if (result.totalPages > 1) ...<Widget>[
              const Gap.xxl(),
              _Pager(page: result.page, totalPages: result.totalPages, onPage: onPage),
            ],
          ],
        );
      },
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.totalPages, required this.onPage});

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Previous'),
        ),
        const Gap.hMd(),
        Text('Page $page of $totalPages', style: Theme.of(context).textTheme.bodySmall),
        const Gap.hMd(),
        OutlinedButton.icon(
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next'),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }
}

/// EVERY PHOTOGRAPH IN THE ARCHIVE.
class AllPhotographsPage extends StatefulWidget {
  const AllPhotographsPage({super.key});

  @override
  State<AllPhotographsPage> createState() => _AllPhotographsPageState();
}

class _AllPhotographsPageState extends State<AllPhotographsPage> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final GalleryRepository repository = context.read<GalleryRepository>();

    return AppScaffold(
      currentPath: AppRoutes.gallery,
      seo: const SeoMetadata(
        title: 'Every photograph',
        description:
            'Every photograph in the Ekoli Yeden archive, from every album and every festival '
            'year, newest first.',
        canonicalPath: AppRoutes.photographs,
      ),
      child: PageSection(
        eyebrow: 'Photographs',
        title: 'Every photograph',
        description:
            'From every album and every festival year, newest first. A photograph taken at a '
            'festival is filed under that year and appears here too — one upload, not two.',
        child: AsyncContent<PaginatedResult<Photograph>>(
          key: ValueKey<int>(_page),
          load: () => repository.photographs(page: _page, perPage: 48),
          loadingMessage: 'Opening the archive…',
          isEmpty: (PaginatedResult<Photograph> result) => result.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyView(
            icon: Icons.photo_library_outlined,
            title: 'No photographs yet',
            message:
                'Photographs will appear here as they are collected and labelled. If you have old '
                'photographs of Ekoli-Yeden, they are among the most valuable things this archive '
                'can receive.',
          ),
          builder: (BuildContext context, PaginatedResult<Photograph> result) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${Formatters.number(result.total)} photographs',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Gap.lg(),
                PhotographGrid(photographs: result.items, showAlbum: true),
                if (result.totalPages > 1) ...<Widget>[
                  const Gap.xxl(),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Previous'),
                      ),
                      const Gap.hMd(),
                      Text(
                        'Page ${result.page} of ${result.totalPages}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Gap.hMd(),
                      OutlinedButton.icon(
                        onPressed: _page < result.totalPages
                            ? () => setState(() => _page += 1)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('Next'),
                        iconAlignment: IconAlignment.end,
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ONE ALBUM.
class GalleryDetailPage extends StatelessWidget {
  const GalleryDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final GalleryRepository repository = context.read<GalleryRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<Gallery>(
      load: () => repository.album(slug),
      loadingMessage: 'Opening the album…',
      builder: (BuildContext context, Gallery album) {
        return AppScaffold(
          currentPath: AppRoutes.gallery,
          seo: SeoMetadata(
            title: album.title,
            description: album.description,
            imageUrl: album.items.isEmpty ? null : album.items.first.url,
            canonicalPath: AppRoutes.galleryAlbum(album.slug),
            type: 'article',
          ),
          child: Column(
            children: <Widget>[
              PageSection(
                eyebrow: album.isFestivalGallery ? 'Festival photographs' : 'Album',
                title: album.title,
                description: album.description,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => context.go(AppRoutes.gallery),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('All albums'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    const Gap.lg(),
                    Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        if (album.eventDate != null)
                          _Fact(
                            icon: Icons.calendar_today_outlined,
                            text: Formatters.date(album.eventDate),
                          ),
                        if (album.location != null)
                          _Fact(icon: Icons.place_outlined, text: album.location!),
                        _Fact(
                          icon: Icons.photo_outlined,
                          text: album.items.length == 1
                              ? '1 picture'
                              : '${album.items.length} pictures',
                        ),
                        if (album.videoCount > 0)
                          _Fact(
                            icon: Icons.play_circle_outline,
                            text: album.videoCount == 1
                                ? '1 of them a video'
                                : '${album.videoCount} of them videos',
                          ),
                      ],
                    ),
                    const Gap.xxl(),
                    if (album.isEmpty)
                      EmptyView(
                        icon: Icons.photo_library_outlined,
                        title: 'This album is empty',
                        message: album.isFestivalGallery
                            ? 'Nothing from this festival has been published yet. If you took '
                                'photographs, or filmed any of it, they belong here — filed under '
                                'this year, where they will still be findable in fifty years.'
                            : 'Nothing has been published in this album yet.',
                      )
                    else
                      PhotographGrid(photographs: album.items),
                  ],
                ),
              ),
              PageSection(
                background: theme.colorScheme.surfaceContainerHigh,
                child: _AlbumContributeNote(album: album),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumContributeNote extends StatelessWidget {
  const _AlbumContributeNote({required this.album});

  final Gallery album;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Do you have pictures of this?', style: theme.textTheme.titleMedium),
        const Gap.sm(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
          child: Text(
            'Send them in, with whatever you can tell us: who is in the picture, where it was '
            'taken, and roughly when. Even a partial answer is worth having — an unlabelled '
            'photograph is preserved, but a labelled one can still be understood by somebody who '
            'was not there.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const Gap.lg(),
        FilledButton.icon(
          onPressed: () => context.go(
            AppRoutes.suggestCorrection('Photographs for', album.title),
          ),
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('Contribute photographs or video'),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const Gap.hSm(),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// A grid of photographs, each opening full-size with its labels.
class PhotographGrid extends StatelessWidget {
  const PhotographGrid({required this.photographs, this.showAlbum = false, super.key});

  final List<Photograph> photographs;

  /// Names the album each picture came from. On the combined stream this is
  /// what lets somebody trace a photograph back to the year it belongs to.
  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final int columns = context.gridColumns(max: 4);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: photographs
              .map(
                (Photograph photograph) => SizedBox(
                  width: width,
                  child: _PhotographTile(photograph: photograph, showAlbum: showAlbum),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _PhotographTile extends StatelessWidget {
  const _PhotographTile({required this.photograph, required this.showAlbum});

  final Photograph photograph;
  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (BuildContext context) => _PhotographDialog(photograph: photograph),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 4 / 3,
              child: photograph.isVideo
                  ? _VideoThumbnail(photograph: photograph)
                  : Image.network(
                photograph.url,
                fit: BoxFit.cover,
                semanticLabel: photograph.accessibleLabel,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) return child;
                  return Container(
                    color: theme.colorScheme.surfaceContainerHigh,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                // A photograph that will not load is stated rather than left as
                // a broken frame: the archive should never look like it has
                // lost something when it has not.
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    photograph.caption ?? 'Not yet described',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: photograph.caption == null ? FontStyle.italic : FontStyle.normal,
                      color: photograph.caption == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (showAlbum && photograph.galleryTitle != null) ...<Widget>[
                    const Gap.xs(),
                    Text(
                      photograph.galleryTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.greenDark),
                    ),
                  ],
                  if (photograph.takenAt != null) ...<Widget>[
                    const Gap.xs(),
                    Text(
                      Formatters.shortDate(photograph.takenAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photograph at full size, with everything the archive knows about it.
class _PhotographDialog extends StatelessWidget {
  const _PhotographDialog({required this.photograph});

  final Photograph photograph;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: context.screenHeight * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (photograph.isVideo)
                _VideoPlayer(photograph: photograph)
              else
                Image.network(
                  photograph.url,
                  fit: BoxFit.contain,
                  semanticLabel: photograph.accessibleLabel,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'This photograph could not be loaded.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      photograph.caption ?? 'This ${photograph.kindNoun} has not been described yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle:
                            photograph.caption == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const Gap.md(),
                    // The labels, and an honest note where they are missing.
                    // Naming the gap is how the archive asks somebody to close
                    // it — the alternative is a picture nobody can place.
                    if (photograph.peoplePictured != null)
                      _Detail(label: 'Who is pictured', value: photograph.peoplePictured!),
                    if (photograph.takenAt != null)
                      _Detail(label: 'Taken', value: Formatters.date(photograph.takenAt)),
                    if (photograph.location != null)
                      _Detail(label: 'Where', value: photograph.location!),
                    if (photograph.creditLine != null)
                      _Detail(label: 'Credit', value: photograph.creditLine!),
                    if (!photograph.isDocumented) ...<Widget>[
                      const Gap.sm(),
                      const AwaitingMaterialNote(
                        message:
                            'Nobody has told us what this shows. If you recognise it — '
                            'the people, the place, roughly when — please tell the Preservation '
                            'Team.',
                      ),
                    ],
                    const Gap.lg(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go(
                              AppRoutes.suggestCorrection(
                                photograph.isVideo ? 'Video' : 'Photograph',
                                photograph.caption ?? 'an undescribed ${photograph.kindNoun}',
                              ),
                            );
                          },
                          child: Text('Tell us about this ${photograph.kindNoun}'),
                        ),
                        const Gap.hSm(),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// A VIDEO IN THE GRID.
///
/// The archive cannot make a poster frame of its own — that would mean decoding
/// the file on a server, which is a whole piece of infrastructure for a
/// thumbnail. So the browser's own element is asked for its first frame and
/// nothing else is downloaded until somebody presses play.
///
/// The play badge is drawn by Flutter over the top rather than by the browser,
/// because the element deliberately ignores pointer events so a tap reaches the
/// tile underneath and opens the video properly.
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.photograph});

  final Photograph photograph;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: Colors.black),
        if (ArchiveVideo.isSupported)
          ArchiveVideo.player(photograph.url, controls: false)
        else
          Center(
            child: Icon(
              Icons.movie_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        // Ignored for hit-testing so the tile's own InkWell still receives the
        // tap — the badge says "this plays", it is not the control.
        IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                'Video',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A video at full size inside the lightbox.
///
/// Where the browser cannot play it, the file is offered as a link rather than
/// leaving a dead black rectangle — a visitor who cannot watch it in place can
/// still download it, which is the point of preserving it.
class _VideoPlayer extends StatelessWidget {
  const _VideoPlayer({required this.photograph});

  final Photograph photograph;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!ArchiveVideo.isSupported) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.movie_outlined, color: theme.colorScheme.onSurfaceVariant),
            const Gap.md(),
            Text('This video cannot be played here.', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ArchiveVideo.player(photograph.url),
    );
  }
}
