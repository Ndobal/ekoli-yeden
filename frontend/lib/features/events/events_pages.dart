import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/calendar_entry.dart';
import '../../models/content_record.dart';
import '../../repositories/event_repository.dart';
import '../shared/content_detail_page.dart';

/// WHAT IS HAPPENING IN EKOLI-YEDEN.
///
/// Town hall meetings, ceremonies, burials, launches — and the festivals, which
/// are a different record in the database and the same thing to a visitor.
///
/// A calendar that showed events but not festivals would be wrong in the most
/// confusing way possible: the biggest thing the community does would be
/// missing from its own list of what is happening. So both are here, each
/// linking back to the kind of page that suits it — an event to its own page, a
/// festival to the festival page with its editions and its programme.
class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    final EventRepository repository = context.read<EventRepository>();

    return AppScaffold(
      currentPath: AppRoutes.events,
      seo: const SeoMetadata(
        title: 'Events',
        description:
            'Meetings, ceremonies, festivals and gatherings of Ekoli-Yeden — what is coming, and '
            'what has already been held.',
        canonicalPath: AppRoutes.events,
      ),
      child: PageSection(
        eyebrow: 'What is happening',
        title: 'Events',
        description:
            'Meetings, ceremonies, festivals and gatherings of Ekoli-Yeden — what is coming, and '
            'what has already been held. Each one keeps its own photographs, so an occasion can '
            'still be seen years later.',
        child: AsyncContent<EventsCalendar>(
          key: ValueKey<String>(_type ?? 'all'),
          load: () => repository.calendar(type: _type),
          loadingMessage: 'Loading…',
          isEmpty: (EventsCalendar calendar) => calendar.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyView(
            icon: Icons.event_outlined,
            title: 'Nothing listed yet',
            message: 'Events appear here as they are announced.',
          ),
          builder: (BuildContext context, EventsCalendar calendar) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TypeFilter(
                  types: calendar.types,
                  selected: _type,
                  onChanged: (String? type) => setState(() => _type = type),
                ),
                const Gap.xl(),

                // Upcoming first. Somebody opening this page is far more often
                // asking "what is coming?" than "what happened?".
                if (calendar.upcoming.isNotEmpty)
                  _EntryGroup(
                    title: 'Coming up',
                    entries: calendar.upcoming,
                  ),

                // Dateless entries between the two, rather than sorted into the
                // past. An occasion whose date has not been fixed has not
                // happened, and filing it under "already held" is simply wrong.
                if (calendar.undated.isNotEmpty)
                  _EntryGroup(
                    title: 'Date to be announced',
                    description:
                        'These have been recorded but not yet dated. If you know when one of them '
                        'is, please tell the Preservation Team.',
                    entries: calendar.undated,
                  ),

                if (calendar.past.isNotEmpty)
                  _EntryGroup(
                    title: 'Already held',
                    description:
                        'Photographs and film from these are kept in the Gallery, filed under the '
                        'occasion they belong to.',
                    entries: calendar.past,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.types, required this.selected, required this.onChanged});

  final List<({String value, String label})> types;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        FilterChip(
          selected: selected == null,
          showCheckmark: false,
          label: const Text('Everything'),
          onSelected: (bool _) => onChanged(null),
        ),
        ...types.map(
          (({String value, String label}) type) => FilterChip(
            selected: selected == type.value,
            showCheckmark: false,
            label: Text(type.label),
            onSelected: (bool _) => onChanged(type.value),
          ),
        ),
      ],
    );
  }
}

class _EntryGroup extends StatelessWidget {
  const _EntryGroup({required this.title, required this.entries, this.description});

  final String title;
  final String? description;
  final List<CalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.headlineSmall),
        if (description != null) ...<Widget>[
          const Gap.xs(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
            child: Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const Gap.lg(),
        ...entries.map((CalendarEntry entry) => _EntryRow(entry: entry)),
        const Gap.xxl(),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final CalendarEntry entry;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // A festival goes to the festival page with its editions and its
        // programme; an event goes to its own. The server decides which,
        // because it is the one that knows what kind of record this is.
        onTap: () => context.go(entry.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DateBlock(entry: entry),
              const Gap.hLg(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(entry.title, style: theme.textTheme.titleMedium)),
                        if (entry.isFestival)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Text('Festival', style: theme.textTheme.labelSmall),
                          )
                        else
                          Text(entry.typeLabel, style: theme.textTheme.labelSmall),
                      ],
                    ),
                    if (entry.description != null) ...<Widget>[
                      const Gap.xs(),
                      Text(
                        entry.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (entry.where != null) ...<Widget>[
                      const Gap.sm(),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const Gap.hXs(),
                          Expanded(
                            child: Text(entry.where!, style: theme.textTheme.labelSmall),
                          ),
                        ],
                      ),
                    ],
                    // An event that belongs to a festival says so, and links
                    // there. It appears in both places from one record: hiding
                    // it inside the festival is how a busy year looks empty.
                    if (entry.isPartOfFestival) ...<Widget>[
                      const Gap.sm(),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.festival(entry.festivalSlug!)),
                        icon: const Icon(Icons.celebration_outlined, size: 14),
                        label: const Text('Part of the festival'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                    // Its own album, where it has one. This is what makes a
                    // photograph from a town hall meeting findable years later
                    // by the occasion rather than by luck.
                    if (entry.gallerySlug != null) ...<Widget>[
                      const Gap.sm(),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.galleryAlbum(entry.gallerySlug!)),
                        icon: const Icon(Icons.photo_library_outlined, size: 14),
                        label: const Text('Its photographs'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
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

/// The date, drawn as a block so a list of events can be scanned down the side.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (entry.startsAt == null) {
      return SizedBox(
        width: 64,
        child: Text(
          'TBA',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final DateTime? date = DateTime.tryParse(entry.startsAt!);
    if (date == null) return const SizedBox(width: 64);

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            Formatters.monthAbbreviation(date),
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.greenDark),
          ),
          Text('${date.day}', style: theme.textTheme.titleLarge),
          Text('${date.year}', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// ONE EVENT.
class EventDetailPage extends StatelessWidget {
  const EventDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'events',
      identifier: slug,
      basePath: AppRoutes.events,
      sectionTitle: 'Events',
      detailFields: <DetailField>[
        DetailField(
          label: 'Starts',
          key: 'start_datetime',
          formatter: (dynamic value) => Formatters.dateTime(value.toString()),
        ),
        DetailField(
          label: 'Ends',
          key: 'end_datetime',
          formatter: (dynamic value) => Formatters.dateTime(value.toString()),
        ),
        const DetailField(label: 'Venue', key: 'venue'),
        const DetailField(label: 'Location', key: 'location'),
        const DetailField(label: 'Organiser', key: 'organiser'),
        const DetailField(label: 'Contact', key: 'contact_info'),
      ],
      footerBuilder: (BuildContext context, ContentRecord record) =>
          _EventGalleryLink(record: record),
    );
  }
}

/// The link to an event's own album.
///
/// An event album is an ordinary gallery, so a photograph put into it appears
/// in the main Gallery as well — one upload, filed under the occasion it
/// belongs to, findable from both.
class _EventGalleryLink extends StatelessWidget {
  const _EventGalleryLink({required this.record});

  final ContentRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Gap.xxl(),
        Text('Photographs from this', style: theme.textTheme.titleMedium),
        const Gap.sm(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
          child: Text(
            'Pictures and film from this occasion are kept in its own album, and appear in the '
            'main Gallery too. If you took any, they belong here — labelled with what they show, '
            'so somebody who was not there can still understand them.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const Gap.lg(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Open the Gallery'),
            ),
            FilledButton.icon(
              onPressed: () => context.go(
                AppRoutes.suggestCorrection('Photographs for', record.text('title') ?? 'this event'),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Contribute photographs or video'),
            ),
          ],
        ),
      ],
    );
  }
}
