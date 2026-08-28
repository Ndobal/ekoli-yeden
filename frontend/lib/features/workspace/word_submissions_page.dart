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
import '../../core/widgets/state_views.dart';
import '../../models/content_status.dart';
import '../../repositories/language_repository.dart';
import '../editorial/editorial_shell.dart';
import 'media_library_page.dart' show WorkspaceKind;

/// WORDS THE COMMUNITY HAS PROPOSED.
///
/// The other half of the dictionary contribution path. What arrives here is a
/// whole entry — variants, parts of speech, meanings, sentences — already in
/// the shape the dictionary stores, so accepting it is one action rather than
/// a re-typing. That is the difference between a review queue that gets worked
/// through and one that quietly grows.
///
/// Accepting creates a **draft**, unverified entry. Saying "this is worth
/// having" and saying "this is what the word means" are different statements,
/// and only the second belongs to somebody with the standing to make it.
class WordSubmissionsPage extends StatefulWidget {
  const WordSubmissionsPage({required this.workspace, super.key});

  final WorkspaceKind workspace;

  @override
  State<WordSubmissionsPage> createState() => _WordSubmissionsPageState();
}

class _WordSubmissionsPageState extends State<WordSubmissionsPage> {
  String _status = 'pending_review';
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) {
    setState(() {
      _reloads += 1;
      _notice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final LanguageRepository repository = context.read<LanguageRepository>();
    final bool isAdmin = widget.workspace == WorkspaceKind.admin;
    final ThemeData theme = Theme.of(context);

    return WorkspaceShell(
      currentPath: AppRoutes.editorialWordSubmissions,
      title: 'Proposed words',
      workspaceName: isAdmin ? 'Administration' : 'Editorial',
      accent: isAdmin ? AppColors.gold : AppColors.skyBlue,
      navigation: isAdmin ? adminNavigation : editorialNavigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Dictionary entries the community has sent in. Accepting one adds it as a draft, '
            'unverified, with the contributor credited — check the meaning and publish it when '
            'you are satisfied.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap.xl(),

          if (_notice != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.08),
                borderRadius: AppRadius.smAll,
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Text(_notice!, style: theme.textTheme.bodyMedium),
            ),
            const Gap.xl(),
          ],

          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final ({String value, String label}) option in <({String value, String label})>[
                (value: 'pending_review', label: 'Waiting'),
                (value: 'promoted', label: 'Added'),
                (value: 'rejected', label: 'Not accepted'),
              ])
                ChoiceChip(
                  label: Text(option.label),
                  selected: _status == option.value,
                  onSelected: (_) => setState(() {
                    _status = option.value;
                    _reloads += 1;
                    _notice = null;
                  }),
                ),
            ],
          ),
          const Gap.xl(),

          AsyncContent<List<ProposedWord>>(
            key: ValueKey<String>('$_status:$_reloads'),
            load: () => repository.wordSubmissions(status: _status),
            loadingMessage: 'Opening the queue…',
            isEmpty: (List<ProposedWord> words) => words.isEmpty,
            emptyBuilder: (BuildContext context) => EmptyView(
              icon: Icons.translate_outlined,
              title: _status == 'pending_review'
                  ? 'Nothing waiting'
                  : 'Nothing in this list',
              message: _status == 'pending_review'
                  ? 'No words are waiting for review. When somebody proposes an entry from the '
                      'dictionary page, it appears here.'
                  : 'Nothing has reached this state yet.',
              showContributeAction: false,
            ),
            builder: (BuildContext context, List<ProposedWord> words) {
              return Column(
                children: words
                    .map(
                      (ProposedWord word) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ProposedWordCard(
                          word: word,
                          reviewable: _status == 'pending_review',
                          onChanged: _reload,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProposedWordCard extends StatelessWidget {
  const _ProposedWordCard({
    required this.word,
    required this.reviewable,
    required this.onChanged,
  });

  final ProposedWord word;
  final bool reviewable;
  final void Function([String? notice]) onChanged;

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
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(word.word, style: theme.textTheme.headlineSmall),
                    if (word.phoneticRespelling != null)
                      Text(
                        '/${word.phoneticRespelling}/',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (word.tonePattern != null)
                      Text('tone ${word.tonePattern}', style: theme.textTheme.labelSmall),
                    Text(
                      LanguageEntryTypes.label(word.entryType).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              Text(word.referenceCode, style: theme.textTheme.labelSmall),
            ],
          ),

          // The one thing a reviewer most needs to know before acting.
          if (word.duplicatesExistingEntry) ...<Widget>[
            const Gap.md(),
            AwaitingMaterialNote(
              message:
                  '“${word.existingEntryWord}” is already in the dictionary. Consider merging this '
                  'into the existing entry rather than adding a second one — a further speaker '
                  'confirming a meaning, or giving another, is exactly what the dictionary needs.',
            ),
          ],

          const Gap.lg(),
          ...word.senses.asMap().entries.map(
                (MapEntry<int, Map<String, dynamic>> entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${entry.key + 1}.',
                        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.greenDark),
                      ),
                      const Gap.hMd(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                if (Json.strOrNull(entry.value, 'part_of_speech') != null) ...<Widget>[
                                  Text(
                                    PartsOfSpeech.abbreviation(
                                      Json.str(entry.value, 'part_of_speech'),
                                    ),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const Gap.hSm(),
                                ],
                                Expanded(
                                  child: Text(
                                    Json.str(entry.value, 'english_meaning', fallback: '—'),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                            if (Json.strOrNull(entry.value, 'definition') != null) ...<Widget>[
                              const Gap.xs(),
                              Text(
                                Json.str(entry.value, 'definition'),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          if (word.examples.isNotEmpty) ...<Widget>[
            const Gap.md(),
            ...word.examples.map(
              (Map<String, dynamic> example) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.smAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      Json.str(example, 'sentence_ekoli'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.greenDark,
                      ),
                    ),
                    if (Json.strOrNull(example, 'pronunciation') != null)
                      Text(
                        Json.str(example, 'pronunciation'),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (Json.strOrNull(example, 'sentence_english') != null)
                      Text(
                        Json.str(example, 'sentence_english'),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],

          if (word.variants.isNotEmpty) ...<Widget>[
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('Also said', style: theme.textTheme.labelSmall),
                ...word.variants.map(
                  (Map<String, dynamic> variant) => Chip(
                    label: Text(Json.str(variant, 'variant')),
                    labelStyle: theme.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],

          const Gap.lg(),
          Divider(color: theme.colorScheme.outlineVariant),
          const Gap.md(),

          // Who supplied it. A word's authority rests on this more than on
          // anything above, so it is set out rather than tucked into a tooltip.
          Text('Supplied by', style: theme.textTheme.labelMedium),
          const Gap.xs(),
          Text(
            word.contributorName ?? 'Anonymous',
            style: theme.textTheme.bodyMedium,
          ),
          if (word.speakerCredentials != null) ...<Widget>[
            const Gap.xs(),
            Text(word.speakerCredentials!, style: theme.textTheme.bodySmall),
          ],
          if (word.contributorEmail != null || word.contributorPhone != null) ...<Widget>[
            const Gap.xs(),
            Text(
              <String>[
                if (word.contributorEmail != null) word.contributorEmail!,
                if (word.contributorPhone != null) word.contributorPhone!,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (word.createdAt != null) ...<Widget>[
            const Gap.xs(),
            Text(
              'Sent ${Formatters.relative(word.createdAt)}',
              style: theme.textTheme.labelSmall,
            ),
          ],

          if (reviewable) ...<Widget>[
            const Gap.lg(),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => _promote(context, word, onChanged),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Add to the dictionary'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reject(context, word, onChanged),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Not accepted'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _promote(
  BuildContext context,
  ProposedWord word,
  void Function([String? notice]) onChanged,
) async {
  try {
    final String message = await context.read<LanguageRepository>().promoteWord(word.id);
    onChanged(message);
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _reject(
  BuildContext context,
  ProposedWord word,
  void Function([String? notice]) onChanged,
) async {
  final TextEditingController notes = TextEditingController();

  final bool confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('Do not accept “${word.word}”?'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'The submission is kept, not deleted — a word one editor cannot confirm may be '
                  'a word another can, and the community should be able to revisit it.',
                ),
                const Gap.lg(),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Why (optional)',
                    alignLabelWithHint: true,
                  ),
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
              child: const Text('Do not accept'),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed || !context.mounted) return;

  try {
    final String message = await context.read<LanguageRepository>().rejectWord(
          word.id,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
    onChanged(message);
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
