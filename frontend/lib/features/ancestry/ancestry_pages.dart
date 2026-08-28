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
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/ancestry.dart';
import '../../repositories/remembrance_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';

/// THE ANCESTRY RECORDS.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS SECTION IS, AND THE ONE RULE IT KEEPS
/// ---------------------------------------------------------------------------
///
/// Nobody is removed from this archive when they die. Their account is stilled,
/// what they made public stays public, and they are remembered here.
///
/// **A date that is not known is left empty and said to be empty.** Never
/// guessed, never approximated, never quietly filled from a nearby record. For
/// the older dead nobody now living may be certain of a year — and a guessed
/// date on a memorial becomes the archive's answer, which the next person then
/// cites. "The year is not recorded" is the truthful page.
class AncestryListPage extends StatefulWidget {
  const AncestryListPage({super.key});

  @override
  State<AncestryListPage> createState() => _AncestryListPageState();
}

class _AncestryListPageState extends State<AncestryListPage> {
  final TextEditingController _search = TextEditingController();
  String? _query;
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RemembranceRepository repository = context.read<RemembranceRepository>();

    return AppScaffold(
      currentPath: AppRoutes.ancestry,
      seo: SeoMetadata(
        title: context.cms('page.ancestry.title', fallback: 'Ancestry Records'),
        description:
            'The people Ekoli-Yeden came from. Nobody is removed from this archive when '
            'they die.',
        canonicalPath: AppRoutes.ancestry,
      ),
      child: PageSection(
        eyebrow: 'Remembrance',
        title: context.cmsWatch('page.ancestry.title', fallback: 'Ancestry Records'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
              child: CmsText(
                'page.ancestry.intro',
                fallback:
                    'The people Ekoli-Yeden came from. Nobody is removed from this archive '
                    'when they die — their account is stilled, what they made public stays '
                    'public, and they are remembered here. If you can tell us about somebody '
                    'who is not yet recorded, please do.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Gap.xl(),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: context.isMobile ? double.infinity : 380,
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (String value) => setState(() {
                      _query = value.trim().isEmpty ? null : value.trim();
                      _page = 1;
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Search by name',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.reportPassing),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Tell us somebody has died'),
                ),
              ],
            ),
            const Gap.xxl(),
            AsyncContent<PaginatedResult<AncestryRecord>>(
              key: ValueKey<String>('${_query ?? ''}:$_page'),
              load: () => repository.ancestry(page: _page, query: _query),
              loadingMessage: 'Opening the records…',
              isEmpty: (PaginatedResult<AncestryRecord> r) => r.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: Icons.local_florist_outlined,
                showContributeAction: false,
                title: _query == null ? 'Nobody is recorded here yet' : 'Nobody by that name',
                message: _query == null
                    ? 'This section fills as the community records the people it has lost, '
                          'and as families tell us about the elders who came before.'
                    : 'Try part of the name, or a name they were also known by.',
              ),
              builder: (BuildContext context, PaginatedResult<AncestryRecord> result) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.total == 1
                        ? '1 person remembered'
                        : '${Formatters.number(result.total)} people remembered',
                    style: theme.textTheme.labelMedium,
                  ),
                  const Gap.lg(),
                  _RecordGrid(records: result.items),
                  if (result.totalPages > 1) ...<Widget>[
                    const Gap.xxl(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
                          child: const Text('Back'),
                        ),
                        const Gap.hLg(),
                        Text(
                          '${result.page} of ${result.totalPages}',
                          style: theme.textTheme.labelMedium,
                        ),
                        const Gap.hLg(),
                        OutlinedButton(
                          onPressed: result.hasMore ? () => setState(() => _page += 1) : null,
                          child: const Text('More'),
                        ),
                      ],
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

class _RecordGrid extends StatelessWidget {
  const _RecordGrid({required this.records});

  final List<AncestryRecord> records;

  @override
  Widget build(BuildContext context) {
    final double width = context.screenWidth;
    final int columns = width < 600
        ? 1
        : width < 1000
        ? 2
        : 3;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.lg;
        final double itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: records
              .map(
                (AncestryRecord record) =>
                    SizedBox(width: itemWidth, child: _RecordCard(record: record)),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final AncestryRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: () => context.go(AppRoutes.ancestryRecord(record.slug)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Portrait(record: record, size: 64),
              const Gap.hLg(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(record.fullName, style: theme.textTheme.titleSmall),
                    const Gap.xs(),
                    Text(
                      // Said rather than left blank, so an empty date reads as
                      // a fact about the archive and not as a broken card.
                      record.lifespan ?? 'Dates not recorded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: record.hasDates ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                    if (record.groupTitle != null) ...<Widget>[
                      const Gap.sm(),
                      Text(record.groupTitle!, style: theme.textTheme.labelSmall),
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

/// A photograph where there is one, initials where there is not.
class Portrait extends StatelessWidget {
  const Portrait({required this.record, this.size = 96, super.key});

  final AncestryRecord record;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (record.portraitUrl != null) {
      return ClipRRect(
        borderRadius: AppRadius.smAll,
        child: Image.network(
          record.portraitUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Initials(record: record, size: size),
        ),
      );
    }

    return _Initials(record: record, size: size);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.record, required this.size});

  final AncestryRecord record;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        record.initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.navy,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One memorial
// ---------------------------------------------------------------------------

class AncestryDetailPage extends StatefulWidget {
  const AncestryDetailPage({required this.slug, super.key});

  final String slug;

  @override
  State<AncestryDetailPage> createState() => _AncestryDetailPageState();
}

class _AncestryDetailPageState extends State<AncestryDetailPage> {
  int _reloads = 0;

  @override
  Widget build(BuildContext context) {
    final RemembranceRepository repository = context.read<RemembranceRepository>();

    return AsyncContent<AncestryRecord>(
      key: ValueKey<String>('${widget.slug}:$_reloads'),
      load: () => repository.record(widget.slug),
      loadingMessage: 'Opening the record…',
      builder: (BuildContext context, AncestryRecord record) => _Memorial(
        record: record,
        onChanged: () => setState(() => _reloads += 1),
      ),
    );
  }
}

class _Memorial extends StatelessWidget {
  const _Memorial({required this.record, required this.onChanged});

  final AncestryRecord record;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.ancestry,
      seo: SeoMetadata(
        title: record.fullName,
        description: record.lifespan == null
            ? 'Remembered in the Ekoli-Yeden archive.'
            : '${record.fullName}, ${record.lifespan}. Remembered in the Ekoli-Yeden archive.',
        canonicalPath: AppRoutes.ancestryRecord(record.slug),
      ),
      child: PageSection(
        reading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.ancestry),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('All the records'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.xl(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Portrait(record: record, size: context.isMobile ? 88 : 120),
                const Gap.hXl(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SelectableText(
                        record.fullName,
                        style: context.isMobile
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.headlineMedium,
                      ),
                      if (record.alsoKnownAs != null) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          'Also known as ${record.alsoKnownAs}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Gap.md(),
                      Text(
                        record.lifespan ?? 'The dates are not recorded',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: record.hasDates ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      const Gap.md(),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          VerificationBadge(record.verificationStatus),
                          if (record.groupTitle != null)
                            Chip(
                              avatar: const Icon(Icons.groups_outlined, size: 16),
                              label: Text(record.groupTitle!),
                            ),
                          if (record.quarter != null)
                            Chip(
                              avatar: const Icon(Icons.place_outlined, size: 16),
                              label: Text(record.quarter!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (record.biography != null) ...<Widget>[
              const Gap.xxl(),
              Text('Their life', style: theme.textTheme.titleMedium),
              const Gap.md(),
              SelectableText(record.biography!, style: theme.textTheme.bodyLarge),
            ],
            if (record.contribution != null) ...<Widget>[
              const Gap.xl(),
              Text('What they gave the community', style: theme.textTheme.titleMedium),
              const Gap.md(),
              SelectableText(record.contribution!, style: theme.textTheme.bodyMedium),
            ],
            if (record.survivedBy != null) ...<Widget>[
              const Gap.xl(),
              Text('Survived by', style: theme.textTheme.titleMedium),
              const Gap.md(),
              SelectableText(record.survivedBy!, style: theme.textTheme.bodyMedium),
            ],

            // Said where somebody who knew them will read it, rather than only
            // on the contribution page they would have to go looking for.
            if (record.biography == null && record.contribution == null) ...<Widget>[
              const Gap.xxl(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Nothing has been written here yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Gap.sm(),
                    Text(
                      'If you knew them, what you remember is what this page is for. Send it '
                      'to the Preservation Team and it will be added.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap.md(),
                    OutlinedButton(
                      onPressed: () => context.go(
                        AppRoutes.suggestCorrection('Ancestry record', record.fullName),
                      ),
                      child: const Text('Tell us about them'),
                    ),
                  ],
                ),
              ),
            ],

            const Gap.section(),
            _Tributes(record: record, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// What people have left, and the box to leave one.
class _Tributes extends StatelessWidget {
  const _Tributes({required this.record, required this.onChanged});

  final AncestryRecord record;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          record.tributes.isEmpty
              ? 'Tributes'
              : record.tributes.length == 1
              ? '1 tribute'
              : '${record.tributes.length} tributes',
          style: theme.textTheme.titleMedium,
        ),
        const Gap.lg(),
        if (record.tributes.isEmpty)
          Text(
            'Nobody has written here yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...record.tributes.map((Tribute tribute) => _TributeCard(tribute: tribute)),
        const Gap.xl(),
        if (auth.isSignedIn)
          _TributeForm(slug: record.slug, name: record.fullName, onPosted: onChanged)
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: AppRadius.mdAll,
            ),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Sign in to leave a tribute.',
                  style: theme.textTheme.bodyMedium,
                ),
                FilledButton(
                  onPressed: () => context.go(
                    AppRoutes.signInReturningTo(AppRoutes.ancestryRecord(record.slug)),
                  ),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TributeCard extends StatelessWidget {
  const _TributeCard({required this.tribute});

  final Tribute tribute;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(tribute.message, style: theme.textTheme.bodyMedium),
            const Gap.md(),
            Text(
              <String?>[
                tribute.authorName,
                tribute.relationship,
                Formatters.relative(tribute.createdAt),
              ].whereType<String>().join('  ·  '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TributeForm extends StatefulWidget {
  const _TributeForm({required this.slug, required this.name, required this.onPosted});

  final String slug;
  final String name;
  final VoidCallback onPosted;

  @override
  State<_TributeForm> createState() => _TributeFormState();
}

class _TributeFormState extends State<_TributeForm> {
  final TextEditingController _message = TextEditingController();
  final TextEditingController _relationship = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String message = _message.text.trim();
    if (message.length < 2) {
      setState(() => _error = 'Write something first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String reply = await context.read<RemembranceRepository>().leaveTribute(
        widget.slug,
        message: message,
        relationship: _relationship.text.trim().isEmpty ? null : _relationship.text.trim(),
      );
      _message.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reply)));
      }
      widget.onPosted();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Leave a tribute', style: theme.textTheme.titleSmall),
          const Gap.sm(),
          Text(
            'It appears straight away, signed with your name.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.lg(),
          TextField(
            controller: _relationship,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'How you knew them (optional)',
              hintText: 'Their nephew · A neighbour in Ajere · We farmed together',
            ),
          ),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 8,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'What you want to say',
              alignLabelWithHint: true,
              errorText: _error,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Leave it'),
            ),
          ),
        ],
      ),
    );
  }
}
