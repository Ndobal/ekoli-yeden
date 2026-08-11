import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/language_entry.dart';
import '../../repositories/language_repository.dart';
import '../../services/api/api_response.dart';

/// THE EKOLI DIGITAL LANGUAGE ACADEMY.
///
/// The most important rule in this feature, and one that is enforced from the
/// database up: the platform never generates, guesses or completes the meaning
/// of an Ekoli word. A word whose meaning nobody has confirmed is displayed
/// with the meaning field empty and a clear note that it is awaiting a native
/// speaker — never with an invented definition.
class LanguageListPage extends StatefulWidget {
  const LanguageListPage({super.key});

  @override
  State<LanguageListPage> createState() => _LanguageListPageState();
}

class _LanguageListPageState extends State<LanguageListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _entryType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LanguageRepository repository = context.read<LanguageRepository>();

    return AppScaffold(
      currentPath: AppRoutes.language,
      seo: const SeoMetadata(
        title: 'The Ekoli Language',
        description:
            'Ekoli words, meanings, expressions, proverbs and pronunciation, recorded by native '
            'speakers and verified before publication.',
        canonicalPath: AppRoutes.language,
      ),
      child: PageSection(
        eyebrow: 'Language preservation',
        title: 'The Ekoli Language',
        description:
            'Words, expressions, greetings, numbers and proverbs, with pronunciation recorded by '
            'native speakers. Search in Ekoli or in English — both are searched at once.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _LanguagePolicyNote(),
            const Gap.xl(),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: TextField(
                controller: _searchController,
                onSubmitted: (String value) => setState(() => _search = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search an Ekoli word or an English meaning',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const Gap.lg(),

            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilterChip(
                  label: const Text('All'),
                  selected: _entryType == null,
                  onSelected: (_) => setState(() => _entryType = null),
                ),
                ...LanguageEntryTypes.all.map(
                  (String type) => FilterChip(
                    label: Text(LanguageEntryTypes.label(type)),
                    selected: _entryType == type,
                    onSelected: (bool selected) =>
                        setState(() => _entryType = selected ? type : null),
                  ),
                ),
              ],
            ),
            const Gap.xxl(),

            AsyncContent<PaginatedResult<LanguageEntry>>(
              key: ValueKey<String>('language:$_search:$_entryType'),
              load: () => repository.entries(
                search: _search.isEmpty ? null : _search,
                entryType: _entryType,
                perPage: 50,
              ),
              loadingMessage: 'Opening the dictionary…',
              isEmpty: (PaginatedResult<LanguageEntry> result) => result.isEmpty,
              emptyBuilder: (BuildContext context) => EmptyView(
                icon: Icons.translate_outlined,
                title: _search.isEmpty
                    ? 'The dictionary is empty'
                    : 'No entry found for “$_search”',
                message: _search.isEmpty
                    ? 'No Ekoli words have been recorded yet. Words are entered only by native '
                        'speakers and language scholars — nothing here is generated. If you speak '
                        'Ekoli and can contribute words, meanings or recordings, please do.'
                    : 'That word has not been recorded yet. If you know it, the archive would '
                        'welcome your contribution.',
              ),
              builder: (BuildContext context, PaginatedResult<LanguageEntry> result) {
                return Column(
                  children: result.items
                      .map((LanguageEntry entry) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: LanguageEntryCard(entry: entry),
                          ))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// States the editorial policy plainly, at the top of the section.
class _LanguagePolicyNote extends StatelessWidget {
  const _LanguagePolicyNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.06),
        borderRadius: AppRadius.smAll,
        border: const Border(left: BorderSide(color: AppColors.green, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.green),
          const Gap.hMd(),
          Expanded(
            child: Text(
              'Every entry in this dictionary is supplied by a native speaker or a recognised Ekoli '
              'language scholar. No meaning is ever generated or guessed. Where a word has been '
              'recorded but its meaning not yet confirmed, the entry says so.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// One dictionary entry.
class LanguageEntryCard extends StatelessWidget {
  const LanguageEntryCard({required this.entry, super.key});

  final LanguageEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Text(entry.word, style: AppTypography.ekoliWord(context))),
              const Gap.hMd(),
              VerificationBadge(entry.verificationStatus),
            ],
          ),
          const Gap.sm(),

          Row(
            children: <Widget>[
              Text(
                entry.entryTypeLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
              ),
              if (entry.partOfSpeech != null) ...<Widget>[
                const Gap.hSm(),
                Text('· ${entry.partOfSpeech}', style: theme.textTheme.labelSmall),
              ],
            ],
          ),
          const Gap.md(),

          // The meaning, or an honest statement that it has not been supplied.
          Text(
            entry.meaningOrPlaceholder,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: entry.hasMeaning ? FontStyle.normal : FontStyle.italic,
              color: entry.hasMeaning
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),

          if (entry.definition != null) ...<Widget>[
            const Gap.md(),
            Text(entry.definition!, style: theme.textTheme.bodyMedium),
          ],

          if (entry.hasExample) ...<Widget>[
            const Gap.lg(),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.exampleSentence!,
                    style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  if (entry.exampleTranslation != null) ...<Widget>[
                    const Gap.xs(),
                    Text(entry.exampleTranslation!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],

          if (entry.dialectOrVariation != null) ...<Widget>[
            const Gap.md(),
            Text('Variation: ${entry.dialectOrVariation}', style: theme.textTheme.bodySmall),
          ],

          const Gap.lg(),
          _PronunciationRow(entry: entry),
        ],
      ),
    );
  }
}

/// The pronunciation recordings for a word.
///
/// Preserving the sound of the language is the point of the section, so the
/// absence of a recording is stated rather than hidden.
class _PronunciationRow extends StatelessWidget {
  const _PronunciationRow({required this.entry});

  final LanguageEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!entry.hasAudio) {
      return Row(
        children: <Widget>[
          Icon(Icons.volume_off_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const Gap.hSm(),
          Expanded(
            child: Text(
              'Pronunciation not yet recorded. A recording by a native speaker would complete this entry.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: entry.pronunciations
          .map(
            (Pronunciation pronunciation) => ActionChip(
              avatar: const Icon(Icons.volume_up_outlined, size: 16),
              label: Text(pronunciation.speakerLabel),
              // The audio element itself is added in Module 2; the archive
              // records and exposes the recording now so nothing is lost.
              onPressed: () => showDialog<void>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(entry.word),
                  content: SelectableText(
                    'Recording by ${pronunciation.speakerLabel}\n\n${pronunciation.audioUrl}',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
