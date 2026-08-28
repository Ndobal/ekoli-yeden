import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/state_views.dart';
import '../../models/place.dart';
import '../../repositories/member_repository.dart';
import '../../repositories/place_repository.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// THE COMMUNITY SNAPSHOT, AND THE LIST OF PLACES.
///
/// ---------------------------------------------------------------------------
/// AGGREGATES ONLY, AND THE PAGE SAYS SO
/// ---------------------------------------------------------------------------
///
/// An administrator planning community development needs to know that a hundred
/// and eighty members are seeking work. They do not need — and this page cannot
/// show them — a list of who those people are. The server sends counts and
/// nothing else, and the note it sends with them is printed here rather than
/// paraphrased, because the promise is the server's to make.
///
/// The second half is the places queue: what members have typed as where they
/// are from that the archive does not yet recognise. A name appearing here
/// again and again is the community telling you about a place, or telling you
/// that one of your spellings is wrong.
class CommunitySnapshotPage extends StatefulWidget {
  const CommunitySnapshotPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<CommunitySnapshotPage> createState() => _CommunitySnapshotPageState();
}

class _CommunitySnapshotPageState extends State<CommunitySnapshotPage> {
  /// Nothing on this half of the page changes anything, so it loads once. The
  /// places queue below keeps its own reload counter.
  static const int _reloads = 0;

  @override
  Widget build(BuildContext context) {
    final MemberRepository members = context.read<MemberRepository>();
    final ThemeData theme = Theme.of(context);
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;

    return WorkspaceShell(
      currentPath: AppRoutes.adminCommunity,
      title: 'The community',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AsyncContent<CommunitySnapshot>(
            key: const ValueKey<int>(_reloads),
            load: members.statistics,
            loadingMessage: 'Counting…',
            isEmpty: (CommunitySnapshot snapshot) => snapshot.isEmpty,
            emptyBuilder: (BuildContext context) => const EmptyView(
              icon: Icons.insights_outlined,
              showContributeAction: false,
              title: 'Nobody has joined yet',
              message:
                  'These figures fill as members join and fill in their profiles. An empty '
                  'count is the correct answer on the first day.',
            ),
            builder: (BuildContext context, CommunitySnapshot snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Tiles(snapshot: snapshot),
                const Gap.xxl(),
                if (snapshot.byWorkGroup.isNotEmpty) ...<Widget>[
                  Text('What members are doing', style: theme.textTheme.titleMedium),
                  const Gap.md(),
                  _Bars(
                    rows: snapshot.byWorkGroup.entries
                        .map(
                          (MapEntry<String, int> entry) =>
                              (label: _workGroupLabel(entry.key), total: entry.value),
                        )
                        .where((({String label, int total}) row) => row.total > 0)
                        .toList(growable: false),
                  ),
                  const Gap.xxl(),
                ],
                if (snapshot.topSkills.isNotEmpty) ...<Widget>[
                  Text('What the community can do', style: theme.textTheme.titleMedium),
                  const Gap.sm(),
                  Text(
                    'The skills members have recorded. This is the list to read before asking '
                    'anybody outside for help.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap.md(),
                  _Bars(rows: snapshot.topSkills),
                  const Gap.xxl(),
                ],
                if (snapshot.byCountry.isNotEmpty) ...<Widget>[
                  Text('Where members are', style: theme.textTheme.titleMedium),
                  const Gap.md(),
                  _Bars(rows: snapshot.byCountry),
                  const Gap.xxl(),
                ],
                // The server's own words about what these figures are. Printed
                // rather than paraphrased: it is the server's promise to make.
                if (snapshot.note != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.lock_outline, size: 18),
                        const Gap.hMd(),
                        Expanded(
                          child: Text(snapshot.note!, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Gap.section(),
          const _PlaceCandidates(),
        ],
      ),
    );
  }
}

/// The headline counts.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.snapshot});

  final CommunitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<({String label, int value, String note})> tiles =
        <({String label, int value, String note})>[
          (label: 'People', value: snapshot.total, note: 'Registered users of Ekoli-Yeden'),
          (
            label: 'In Ekoli-Yeden',
            value: snapshot.inEkoliYeden,
            note: 'Living in the community',
          ),
          (label: 'Away', value: snapshot.diaspora, note: 'Members outside Nigeria'),
          (
            label: 'In the directory',
            value: snapshot.inDirectory,
            note: 'Chose to be findable — it is off by default',
          ),
        ];

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: tiles
          .map(
            (({String label, int value, String note}) tile) => SizedBox(
              width: context.isMobile ? double.infinity : 240,
              child: _Tile(label: tile.label, value: tile.value, note: tile.note),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.note});

  final String label;
  final int value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          const Gap.sm(),
          Text(Formatters.number(value), style: theme.textTheme.headlineMedium),
          const Gap.xs(),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A count per row, drawn as a proportion of the largest.
///
/// Bars rather than a pie: a reader can compare two lengths accurately and
/// cannot compare two angles, and these lists are read to answer "which is
/// bigger" more often than "what share is this".
class _Bars extends StatelessWidget {
  const _Bars({required this.rows});

  final List<({String label, int total})> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();

    final int largest = rows
        .map((({String label, int total}) row) => row.total)
        .reduce((int a, int b) => a > b ? a : b);

    return Column(
      children: rows
          .map(
            (({String label, int total}) row) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 200,
                    child: Text(
                      row.label,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Gap.hMd(),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.pillAll,
                      child: LinearProgressIndicator(
                        value: largest == 0 ? 0 : row.total / largest,
                        minHeight: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const Gap.hMd(),
                  SizedBox(
                    width: 64,
                    child: Text(
                      Formatters.number(row.total),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// What members typed that the archive does not recognise yet.
class _PlaceCandidates extends StatefulWidget {
  const _PlaceCandidates();

  @override
  State<_PlaceCandidates> createState() => _PlaceCandidatesState();
}

class _PlaceCandidatesState extends State<_PlaceCandidates> {
  int _reloads = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PlaceRepository repository = context.read<PlaceRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Places members have named', style: theme.textTheme.titleMedium),
        const Gap.sm(),
        Text(
          'What people typed as where they are from that is not yet a place. Two different '
          'people saying the same thing makes it one automatically — these are the ones only '
          'one person has said, or that want their spelling corrected first.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap.lg(),
        AsyncContent<List<PlaceCandidate>>(
          key: ValueKey<int>(_reloads),
          load: repository.candidates,
          loadingMessage: 'Reading what people have typed…',
          isEmpty: (List<PlaceCandidate> items) => items.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyView(
            icon: Icons.place_outlined,
            showContributeAction: false,
            title: 'Nothing waiting',
            message:
                'Every name members have given is already a place the archive recognises.',
          ),
          builder: (BuildContext context, List<PlaceCandidate> items) => Column(
            children: items
                .map(
                  (PlaceCandidate candidate) => _CandidateRow(
                    candidate: candidate,
                    onChanged: () => setState(() => _reloads += 1),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.candidate, required this.onChanged});

  final PlaceCandidate candidate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(candidate.rawName, style: theme.textTheme.titleSmall),
                  Text(
                    candidate.timesSeen == 1
                        ? 'One person has said it'
                        : '${candidate.timesSeen} people have said it',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: candidate.meetsThreshold
                          ? AppColors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Last ${Formatters.relative(candidate.lastSeenAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _promote(context),
              child: const Text('Make it a place'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await context.read<PlaceRepository>().dismiss(candidate.id);
                  onChanged();
                } on AppException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('Not a place'),
            ),
          ],
        ),
      ),
    );
  }

  /// Promoting is the moment to fix the spelling and say where it sits, because
  /// afterwards it is a real place that members are already attached to.
  Future<void> _promote(BuildContext context) async {
    final PlaceRepository repository = context.read<PlaceRepository>();
    final TextEditingController name = TextEditingController(text: candidate.rawName);

    List<Place> places = const <Place>[];
    try {
      places = await repository.all();
    } on AppException {
      // The parent picker is a convenience. Without it the place sits directly
      // under Ekori, which is where the server puts it anyway.
    }
    if (!context.mounted) return;

    String? parentId;

    final bool go =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => StatefulBuilder(
            builder: (BuildContext inner, StateSetter setInner) => AlertDialog(
              title: const Text('Add it to the places of Ekori'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Its name',
                        helperText: 'Correct the spelling now — members are already attached '
                            'to it.',
                        helperMaxLines: 2,
                      ),
                    ),
                    const Gap.lg(),
                    DropdownButtonFormField<String?>(
                      initialValue: parentId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'It sits inside'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Ekori itself'),
                        ),
                        ...places.map(
                          (Place place) => DropdownMenuItem<String?>(
                            value: place.id,
                            child: Text(place.path ?? place.name),
                          ),
                        ),
                      ],
                      onChanged: (String? value) => setInner(() => parentId = value),
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
                  child: const Text('Add it'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!go || !context.mounted) return;

    try {
      await repository.promote(candidate.id, name: name.text.trim(), parentId: parentId);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${name.text.trim()} is now one of the places of Ekori.')),
        );
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

String _workGroupLabel(String key) {
  switch (key) {
    case 'working':
      return 'Working';
    case 'seeking':
      return 'Looking for work';
    case 'studying':
      return 'Studying';
    case 'business':
      return 'Running a business';
    case 'retired':
      return 'Retired';
    default:
      return key;
  }
}
