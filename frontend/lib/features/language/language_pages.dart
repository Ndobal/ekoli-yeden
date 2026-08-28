import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/audio/audio_playback.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/language_entry.dart';
import '../../repositories/language_repository.dart';
import '../../services/api/api_response.dart';

/// THE DICTIONARY.
///
/// The rule this feature is built around, enforced from the database up: the
/// platform never generates, guesses or completes the meaning of a word. A word
/// whose meaning nobody has confirmed is shown with the field empty and a clear
/// note that it is awaiting a native speaker — never with an invented
/// definition.
///
/// What makes this a dictionary rather than a word list is that an entry holds
/// what a language actually does: several parts of speech at once, several
/// senses each with its own definition, variant forms from different quarters,
/// sentences showing the word in use, and recordings of somebody saying it.
class LanguageListPage extends StatefulWidget {
  const LanguageListPage({super.key});

  @override
  State<LanguageListPage> createState() => _LanguageListPageState();
}

class _LanguageListPageState extends State<LanguageListPage> {
  final TextEditingController _searchController = TextEditingController();
  DictionaryQuery _query = const DictionaryQuery();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(DictionaryQuery next) => setState(() => _query = next);

  @override
  Widget build(BuildContext context) {
    final LanguageRepository repository = context.read<LanguageRepository>();
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.language,
      seo: const SeoMetadata(
        title: 'The Lokaa Dictionary',
        description:
            'Words of Ekoli-Yeden with their meanings, variant forms, example sentences and '
            'pronunciation, recorded by native speakers and verified before publication.',
        canonicalPath: AppRoutes.language,
      ),
      child: Column(
        children: <Widget>[
          PageSection(
            eyebrow: 'Language preservation',
            title: 'The Lokaa Dictionary',
            description:
                'Words, expressions, greetings, numbers and proverbs of Ekoli-Yeden, with their '
                'meanings and the sound of them. Search in either direction — type a word in the '
                'language, or type the English meaning.',
            action: FilledButton.icon(
              onPressed: () => context.go(AppRoutes.contributeWord),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Contribute a word'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _LanguagePolicyNote(),
                const Gap.xl(),

                // The index arrives before the results because the A–Z row, the
                // parts of speech and the coverage figures all come from it,
                // and the page cannot draw its controls without them.
                AsyncContent<DictionaryIndex>(
                  load: repository.index,
                  loadingMessage: 'Opening the dictionary…',
                  builder: (BuildContext context, DictionaryIndex index) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _CoverageStrip(coverage: index.coverage),
                        const Gap.xl(),
                        _SearchField(
                          controller: _searchController,
                          onSubmitted: (String value) => _update(
                            _query.copyWith(search: value.trim(), clearLetter: true),
                          ),
                          onCleared: () {
                            _searchController.clear();
                            _update(_query.copyWith(clearSearch: true));
                          },
                        ),
                        const Gap.lg(),
                        _AlphabetIndex(
                          letters: index.letters,
                          selected: _query.letter,
                          onSelected: (String? letter) => _update(
                            letter == null
                                ? _query.copyWith(clearLetter: true)
                                : _query.copyWith(letter: letter),
                          ),
                        ),
                        const Gap.lg(),
                        _Filters(
                          index: index,
                          query: _query,
                          onChanged: _update,
                        ),
                      ],
                    );
                  },
                ),
                const Gap.xxl(),

                AsyncContent<PaginatedResult<LanguageEntry>>(
                  key: ValueKey<String>('dictionary:${_query.cacheKey}'),
                  load: () => repository.search(_query, perPage: 25),
                  loadingMessage: 'Searching the dictionary…',
                  isEmpty: (PaginatedResult<LanguageEntry> result) => result.isEmpty,
                  emptyBuilder: (BuildContext context) => _EmptyDictionary(query: _query),
                  builder: (BuildContext context, PaginatedResult<LanguageEntry> result) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          result.total == 1
                              ? '1 entry'
                              : '${Formatters.number(result.total)} entries',
                          style: theme.textTheme.labelMedium,
                        ),
                        const Gap.lg(),
                        ...result.items.map(
                          (LanguageEntry entry) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: LanguageEntryCard(entry: entry),
                          ),
                        ),
                        if (result.totalPages > 1) ...<Widget>[
                          const Gap.xl(),
                          _DictionaryPagination(
                            page: result.page,
                            totalPages: result.totalPages,
                            onChanged: (int page) => _update(
                              DictionaryQuery(
                                search: _query.search,
                                letter: _query.letter,
                                categoryId: _query.categoryId,
                                entryType: _query.entryType,
                                partOfSpeech: _query.partOfSpeech,
                                verifiedOnly: _query.verifiedOnly,
                                hasAudio: _query.hasAudio,
                                hasExample: _query.hasExample,
                                sortByRecent: _query.sortByRecent,
                                page: page,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How much of the language is recorded so far.
///
/// Stated openly. An archive that hides how empty it is cannot credibly ask
/// the community to help fill it, and the gaps are the most useful thing this
/// page can tell a speaker who wants to help.
class _CoverageStrip extends StatelessWidget {
  const _CoverageStrip({required this.coverage});

  final DictionaryCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (coverage.isEmpty) return const SizedBox.shrink();

    final List<({String label, int value, IconData icon})> figures =
        <({String label, int value, IconData icon})>[
      (label: 'entries', value: coverage.published, icon: Icons.menu_book_outlined),
      (label: 'verified', value: coverage.verified, icon: Icons.verified_outlined),
      (label: 'with a recording', value: coverage.withAudio, icon: Icons.volume_up_outlined),
      (label: 'with an example', value: coverage.withExample, icon: Icons.format_quote_outlined),
      (label: 'still need a meaning', value: coverage.withoutMeaning, icon: Icons.help_outline),
    ];

    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.md,
      children: figures
          .where((({String label, int value, IconData icon}) figure) => figure.value > 0)
          .map(
            (({String label, int value, IconData icon}) figure) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(figure.icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const Gap.hSm(),
                Text(
                  Formatters.number(figure.value),
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.greenDark),
                ),
                const Gap.hSm(),
                Text(figure.label, style: theme.textTheme.bodySmall),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search a word, a meaning, or a sentence',
          prefixIcon: const Icon(Icons.search, size: 20),
          helperText:
              'Variant forms are searched too, so the way your own family says it will find the entry.',
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onCleared,
                  tooltip: 'Clear the search',
                ),
        ),
      ),
    );
  }
}

/// The A–Z index.
///
/// ---------------------------------------------------------------------------
/// IT HIDES ITSELF UNTIL THERE IS SOMETHING TO INDEX
/// ---------------------------------------------------------------------------
///
/// This used to render all twenty-six letters always, greyed where nothing sat
/// behind them, on the reasoning that the gaps said honestly what had not been
/// recorded yet.
///
/// With an empty dictionary that reasoning produces a row of twenty-six dead
/// grey boxes above the search — a wall of clutter that cannot be pressed and
/// tells the reader nothing they wanted to know. The honest gap only reads as
/// an honest gap once most of the alphabet is filled.
///
/// So: nothing until at least two letters have entries. Then it appears, and
/// from that point the greyed letters do the job they were meant to.
class _AlphabetIndex extends StatelessWidget {
  const _AlphabetIndex({
    required this.letters,
    required this.selected,
    required this.onSelected,
  });

  final List<DictionaryLetter> letters;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final int filled = letters.where((DictionaryLetter l) => !l.isEmpty).length;
    if (filled < 2) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _LetterButton(
          label: 'All',
          enabled: true,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        ...letters.map(
          (DictionaryLetter letter) => Tooltip(
            message: letter.isEmpty
                ? 'No entries under ${letter.letter} yet'
                : '${letter.total} under ${letter.letter}',
            child: _LetterButton(
              label: letter.letter,
              enabled: !letter.isEmpty,
              selected: selected == letter.letter,
              onTap: letter.isEmpty ? null : () => onSelected(letter.letter),
            ),
          ),
        ),
        if (selected != null) ...<Widget>[
          const Gap.hSm(),
          TextButton(
            onPressed: () => onSelected(null),
            child: Text('Clear', style: theme.textTheme.labelMedium),
          ),
        ],
      ],
    );
  }
}

class _LetterButton extends StatelessWidget {
  const _LetterButton({
    required this.label,
    required this.enabled,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color foreground = selected
        ? Colors.white
        : enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    return Material(
      color: selected ? AppColors.green : theme.colorScheme.surfaceContainerHigh,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

/// The filters that make the dictionary usable once it holds real material.
class _Filters extends StatelessWidget {
  const _Filters({required this.index, required this.query, required this.onChanged});

  final DictionaryIndex index;
  final DictionaryQuery query;
  final ValueChanged<DictionaryQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: query.entryType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kind of entry', isDense: true),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('Any kind')),
                  ...LanguageEntryTypes.all.map(
                    (String type) => DropdownMenuItem<String?>(
                      value: type,
                      child: Text(LanguageEntryTypes.label(type)),
                    ),
                  ),
                ],
                onChanged: (String? value) => onChanged(
                  value == null
                      ? query.copyWith(clearEntryType: true)
                      : query.copyWith(entryType: value),
                ),
              ),
            ),
            if (index.partsOfSpeech.isNotEmpty)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: query.partOfSpeech,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Part of speech', isDense: true),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Any part of speech')),
                    ...index.partsOfSpeech.map(
                      (PartOfSpeech part) => DropdownMenuItem<String?>(
                        value: part.slug,
                        child: Text(part.label),
                      ),
                    ),
                  ],
                  onChanged: (String? value) => onChanged(
                    value == null
                        ? query.copyWith(clearPartOfSpeech: true)
                        : query.copyWith(partOfSpeech: value),
                  ),
                ),
              ),
            if (index.categories.isNotEmpty)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: query.categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Group', isDense: true),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('All groups')),
                    ...index.categories.map(
                      (LanguageCategory category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (String? value) => onChanged(
                    value == null
                        ? query.copyWith(clearCategory: true)
                        : query.copyWith(categoryId: value),
                  ),
                ),
              ),
          ],
        ),
        const Gap.md(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilterChip(
              avatar: const Icon(Icons.volume_up_outlined, size: 16),
              label: const Text('Has a recording'),
              selected: query.hasAudio,
              onSelected: (bool value) => onChanged(query.copyWith(hasAudio: value)),
            ),
            FilterChip(
              avatar: const Icon(Icons.format_quote_outlined, size: 16),
              label: const Text('Has an example'),
              selected: query.hasExample,
              onSelected: (bool value) => onChanged(query.copyWith(hasExample: value)),
            ),
            FilterChip(
              avatar: const Icon(Icons.verified_outlined, size: 16),
              label: const Text('Verified only'),
              selected: query.verifiedOnly,
              onSelected: (bool value) => onChanged(query.copyWith(verifiedOnly: value)),
            ),
            FilterChip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: const Text('Newest first'),
              selected: query.sortByRecent,
              onSelected: (bool value) => onChanged(query.copyWith(sortByRecent: value)),
            ),
            if (query.hasFilters)
              TextButton.icon(
                onPressed: () => onChanged(DictionaryQuery(search: query.search)),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: Text('Clear filters', style: theme.textTheme.labelMedium),
              ),
          ],
        ),
      ],
    );
  }
}

/// What the dictionary says when it has nothing to show.
class _EmptyDictionary extends StatelessWidget {
  const _EmptyDictionary({required this.query});

  final DictionaryQuery query;

  @override
  Widget build(BuildContext context) {
    final bool searched = query.search != null && query.search!.isNotEmpty;

    return EmptyView(
      icon: Icons.translate_outlined,
      title: searched
          ? 'No entry found for “${query.search}”'
          : query.hasFilters
              ? 'No entries match those filters'
              : 'The dictionary is empty',
      message: searched
          ? 'That word has not been recorded yet. If you know it, the archive would welcome your '
              'entry — the word, what it means, and a sentence using it.'
          : query.hasFilters
              ? 'Try clearing a filter. Nothing recorded so far matches all of them at once.'
              : 'No words have been recorded yet. Entries are made only by native speakers and '
                  'language scholars — nothing here is generated. If you speak the language, '
                  'please add to it.',
      showContributeAction: false,
      onContribute: null,
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
              'Every entry in this dictionary is supplied by a native speaker or a recognised '
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

/// ONE DICTIONARY ENTRY.
///
/// Laid out the way a dictionary lays one out: headword, how it is said, what
/// parts of speech it belongs to, then the senses numbered, then the sentences
/// that show it in use, then the other forms it takes.
class LanguageEntryCard extends StatelessWidget {
  const LanguageEntryCard({required this.entry, this.compact = false, super.key});

  final LanguageEntry entry;

  /// Trims the entry to headword and first meaning, for a search result list.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WordSense> senses = entry.displaySenses;
    final List<WordExample> examples = entry.displayExamples;

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
          _Headword(entry: entry),
          const Gap.sm(),
          _EntryLabels(entry: entry),

          const Gap.lg(),
          if (senses.isEmpty)
            Text(
              entry.meaningOrPlaceholder,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            _Senses(senses: senses, numbered: senses.length > 1),

          if (entry.literalTranslation != null) ...<Widget>[
            const Gap.md(),
            Text(
              'Literally: ${entry.literalTranslation}',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],

          if (!compact && examples.isNotEmpty) ...<Widget>[
            const Gap.lg(),
            ...examples.map(
              (WordExample example) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ExampleBlock(example: example),
              ),
            ),
          ],

          if (!compact && entry.hasVariants) ...<Widget>[
            const Gap.md(),
            _Variants(variants: entry.variants),
          ],

          if (!compact && entry.usageNotes != null) ...<Widget>[
            const Gap.md(),
            Text(entry.usageNotes!, style: theme.textTheme.bodySmall),
          ],

          const Gap.lg(),
          _PronunciationRow(entry: entry),
        ],
      ),
    );
  }
}

class _Headword extends StatelessWidget {
  const _Headword({required this.entry});

  final LanguageEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.md,
            children: <Widget>[
              Text(entry.word, style: AppTypography.ekoliWord(context)),
              // How to say it. In a tonal language the tone pattern is not
              // decoration: two words differing only in tone are two words.
              if (entry.soundGuide != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/${entry.soundGuide}/',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (entry.tonePattern != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(
                      'tone ${entry.tonePattern}',
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.goldDark),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Gap.hMd(),
        VerificationBadge(entry.verificationStatus),
      ],
    );
  }
}

/// The line of grammatical labels under the headword.
class _EntryLabels extends StatelessWidget {
  const _EntryLabels({required this.entry});

  final LanguageEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> parts = entry.displayPartsOfSpeech;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          entry.entryTypeLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1),
        ),
        // A word can be a noun and a verb at once, so this is a list rather
        // than one label.
        ...parts.map(
          (String part) => Text(
            PartsOfSpeech.abbreviation(part),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        if (entry.pluralForm != null)
          Text('pl. ${entry.pluralForm}', style: theme.textTheme.labelSmall),
        if (entry.register != null)
          Text('· ${entry.register}', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// The meanings, numbered as a dictionary numbers them.
class _Senses extends StatelessWidget {
  const _Senses({required this.senses, required this.numbered});

  final List<WordSense> senses;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: senses.map((WordSense sense) {
        return Padding(
          padding: EdgeInsets.only(bottom: senses.last == sense ? 0 : AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (numbered) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '${sense.senseNumber}.',
                    style: theme.textTheme.titleSmall?.copyWith(color: AppColors.greenDark),
                  ),
                ),
                const Gap.hMd(),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (sense.partOfSpeech != null)
                          Text(
                            PartsOfSpeech.abbreviation(sense.partOfSpeech!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          // The honest fallback, per sense. A sense somebody
                          // began and never finished says so.
                          sense.hasMeaning
                              ? sense.englishMeaning!
                              : 'Meaning not yet supplied by a native speaker.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: sense.hasMeaning ? FontStyle.normal : FontStyle.italic,
                            color: sense.hasMeaning
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (sense.definition != null) ...<Widget>[
                      const Gap.xs(),
                      Text(sense.definition!, style: theme.textTheme.bodyMedium),
                    ],
                    if (sense.usageNote != null) ...<Widget>[
                      const Gap.xs(),
                      Text(
                        sense.usageNote!,
                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

/// A sentence showing the word in use.
///
/// Three lines where all three are known: the sentence, how to say it, and what
/// it means. The middle one is what a written archive preserves worst, which is
/// why it is given its own line rather than being folded into a note.
class _ExampleBlock extends StatelessWidget {
  const _ExampleBlock({required this.example});

  final WordExample example;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  example.sentenceEkoli,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.greenDark,
                  ),
                ),
              ),
              if (example.hasAudio) ...<Widget>[
                const Gap.hSm(),
                _PlayButton(url: example.audioUrl!, tooltip: 'Hear this sentence'),
              ],
            ],
          ),
          if (example.pronunciation != null) ...<Widget>[
            const Gap.xs(),
            Text(
              example.pronunciation!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (example.sentenceEnglish != null) ...<Widget>[
            const Gap.xs(),
            Text(example.sentenceEnglish!, style: theme.textTheme.bodyMedium),
          ],
          if (example.speaker != null) ...<Widget>[
            const Gap.xs(),
            Text('— ${example.speaker}', style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// Other forms of the same word.
class _Variants extends StatelessWidget {
  const _Variants({required this.variants});

  final List<WordVariant> variants;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('Also said', style: theme.textTheme.labelSmall),
        ...variants.map(
          (WordVariant variant) => Tooltip(
            message: variant.dialectOrArea == null
                ? variant.typeLabel
                : '${variant.typeLabel} · ${variant.dialectOrArea}',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(variant.variant, style: theme.textTheme.labelMedium),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pronunciation recordings for a word.
///
/// Preserving the sound of the language is the point of the section, so the
/// absence of a recording is stated rather than hidden — it is the single most
/// useful thing this page can ask a speaker for.
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
              'Pronunciation not yet recorded. A recording by a native speaker would complete '
              'this entry.',
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
            (Pronunciation pronunciation) => _PlayButton(
              url: pronunciation.audioUrl,
              label: pronunciation.speakerLabel,
              tooltip: pronunciation.dialectOrVariation == null
                  ? 'Hear ${entry.word}'
                  : 'Hear ${entry.word} — ${pronunciation.dialectOrVariation}',
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Plays a recording where the browser can, and offers the file where it
/// cannot — never a control that looks live and does nothing.
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.url, this.label, this.tooltip});

  final String url;
  final String? label;
  final String? tooltip;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _playing = false;

  void _toggle() {
    if (!ArchiveAudio.isSupported) {
      _showFallback();
      return;
    }
    if (_playing) {
      ArchiveAudio.stop();
      setState(() => _playing = false);
      return;
    }
    final bool started = ArchiveAudio.play(widget.url);
    if (started) {
      setState(() => _playing = true);
    } else {
      _showFallback();
    }
  }

  void _showFallback() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('The recording'),
        content: SelectableText(
          'This browser could not play the recording here. The file is at:\n\n${widget.url}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget chip = widget.label == null
        ? IconButton(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 22),
            color: AppColors.green,
            visualDensity: VisualDensity.compact,
          )
        : ActionChip(
            avatar: Icon(_playing ? Icons.stop : Icons.volume_up_outlined, size: 16),
            label: Text(widget.label!),
            onPressed: _toggle,
          );

    return widget.tooltip == null ? chip : Tooltip(message: widget.tooltip!, child: chip);
  }
}

class _DictionaryPagination extends StatelessWidget {
  const _DictionaryPagination({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Previous'),
        ),
        const Gap.hMd(),
        Text('Page $page of $totalPages', style: Theme.of(context).textTheme.bodySmall),
        const Gap.hMd(),
        OutlinedButton.icon(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next'),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }
}
