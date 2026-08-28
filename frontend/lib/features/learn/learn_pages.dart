/// LEARN ABOUT EKORI — §17 of the proposal.
///
/// ---------------------------------------------------------------------------
/// NOTHING A CHILD DOES HERE IS RECORDED
/// ---------------------------------------------------------------------------
///
/// The quiz is marked in this file. There is no submit, no score sent anywhere,
/// and nothing written to the device either — `shared_preferences` would leave
/// a child's answers on a shared family computer, which is the same problem as
/// a server record with a smaller radius.
///
/// A child closes the tab and the archive has learned nothing about them. That
/// is the intended behaviour, and the line saying so is on the page in words a
/// parent can read.
///
/// ---------------------------------------------------------------------------
/// AND THE TONE
/// ---------------------------------------------------------------------------
///
/// This is the one section of the archive whose readers are children, many of
/// them growing up outside Nigeria and meeting Ekori through a screen. Getting
/// an answer wrong here should feel like being told something interesting, not
/// like being marked. So every answer shows its explanation, right or wrong,
/// and the score at the end is deliberately quiet.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/audio/audio_playback.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/learning.dart';
import '../../repositories/discover_repository.dart';

// ---------------------------------------------------------------------------
// The landing page
// ---------------------------------------------------------------------------

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DiscoverRepository repository = context.read<DiscoverRepository>();
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.learn,
      seo: const SeoMetadata(
        title: 'Learn About Ekori — for children',
        description:
            'Greetings, numbers, proverbs and the story of Ekori, for children of the '
            'community wherever they are growing up.',
        canonicalPath: AppRoutes.learn,
      ),
      child: PageSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const CmsText(
              'page.children.title',
              fallback: 'Learn About Ekori',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.15),
            ),
            const Gap.md(),
            const CmsText(
              'page.children.intro',
              fallback:
                  'For children of Ekori, wherever they are growing up. Greetings, numbers, '
                  'proverbs and the story of where your family comes from — with quizzes to '
                  'try. Nothing you answer here is saved or sent anywhere.',
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const Gap.xl(),
            const _WhereToStart(),
            const Gap.xxl(),
            Text('Quizzes to try', style: theme.textTheme.headlineSmall),
            const Gap.md(),
            AsyncContent<List<QuizSummary>>(
              load: repository.quizzes,
              loadingMessage: 'Finding the quizzes…',
              isEmpty: (List<QuizSummary> items) => items.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.quiz_outlined,
                title: 'No quizzes yet',
                message:
                    'The first quizzes will be written by the Language Team, from words and '
                    'proverbs the community has already verified. Until then, the language '
                    'section is the place to start.',
              ),
              builder: (BuildContext context, List<QuizSummary> items) => ResponsiveCardGrid(
                children: items
                    .map((QuizSummary quiz) => _QuizCard(quiz: quiz))
                    .toList(growable: false),
              ),
            ),
            const Gap.xxl(),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }
}

/// Sends children into the sections that already hold real material, so the
/// page is useful before a single quiz has been written.
class _WhereToStart extends StatelessWidget {
  const _WhereToStart();

  @override
  Widget build(BuildContext context) {
    const List<(IconData, String, String, String)> doors =
        <(IconData, String, String, String)>[
      (Icons.waving_hand_outlined, 'Greetings', 'How to greet somebody in Ekoli',
          AppRoutes.language),
      (Icons.menu_book_outlined, 'Proverbs', 'What the old sayings mean', AppRoutes.language),
      (Icons.history_edu_outlined, 'Our history', 'Where Ekori comes from', AppRoutes.history),
      (Icons.celebration_outlined, 'Leboku', 'The festival, and what happens at it',
          AppRoutes.leboku),
      (Icons.explore_outlined, 'The places', 'The wards and quarters of Ekori', AppRoutes.map),
      (Icons.record_voice_over_outlined, 'Voices', 'Elders telling it themselves',
          AppRoutes.voices),
    ];

    return ResponsiveCardGrid(
      children: <Widget>[
        for (final (IconData icon, String title, String blurb, String path) in doors)
          _DoorCard(icon: icon, title: title, blurb: blurb, path: path),
      ],
    );
  }
}

class _DoorCard extends StatelessWidget {
  const _DoorCard({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String blurb;
  final String path;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(path),
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.gold, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(blurb, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz});

  final QuizSummary quiz;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(AppRoutes.quiz(quiz.slug)),
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.quiz_outlined, size: 18, color: AppColors.green),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  quiz.levelLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
                ),
              ],
            ),
            const Gap.sm(),
            Text(quiz.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(quiz.subjectLabel, style: theme.textTheme.bodySmall),
            if ((quiz.description ?? '').isNotEmpty) ...<Widget>[
              const Gap.sm(),
              Text(
                quiz.description!,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lock_outline, color: AppColors.green),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('A note for parents', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'These quizzes are marked in the browser. No answer, score or name is sent '
                  'to this website or stored on this device, and no account is needed. '
                  'Children can use this section without leaving any record behind.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One quiz
// ---------------------------------------------------------------------------

class QuizPage extends StatelessWidget {
  const QuizPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final DiscoverRepository repository = context.read<DiscoverRepository>();

    return AsyncContent<Quiz>(
      load: () => repository.quiz(slug),
      loadingMessage: 'Getting the questions ready…',
      builder: (BuildContext context, Quiz quiz) => AppScaffold(
        currentPath: AppRoutes.learn,
        seo: SeoMetadata(
          title: '${quiz.title} — Learn About Ekori',
          description: quiz.description ?? 'A quiz about Ekori, for children of the community.',
          canonicalPath: AppRoutes.quiz(quiz.slug),
        ),
        child: PageSection(
          reading: true,
          child: quiz.questions.isEmpty
              ? const EmptyView(
                  icon: Icons.quiz_outlined,
                  title: 'This quiz has no questions yet',
                  message: 'Somebody is still writing it. Try another one for now.',
                )
              : _QuizRunner(quiz: quiz),
        ),
      ),
    );
  }
}

class _QuizRunner extends StatefulWidget {
  const _QuizRunner({required this.quiz});

  final Quiz quiz;

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  late QuizAttempt _attempt = QuizAttempt(widget.quiz);
  bool _finished = false;

  void _choose(String optionId) {
    setState(() => _attempt.choose(optionId));
  }

  void _next() {
    setState(() {
      if (_attempt.isLast) {
        _finished = true;
      } else {
        _attempt.next();
      }
    });
  }

  void _restart() {
    setState(() {
      _attempt = QuizAttempt(widget.quiz);
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_finished) {
      return _QuizResult(attempt: _attempt, onRestart: _restart);
    }

    final QuizQuestion question = _attempt.current;
    final bool answered = _attempt.isAnswered;
    final String? picked = _attempt.chosenFor(question);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.quiz.title, style: theme.textTheme.displaySmall),
        const Gap.sm(),
        Text(
          'Question ${_attempt.index + 1} of ${_attempt.total}',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Gap.sm(),
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: LinearProgressIndicator(
            value: (_attempt.index + 1) / _attempt.total,
            minHeight: 7,
          ),
        ),
        const Gap.xl(),

        Text(question.prompt, style: theme.textTheme.headlineSmall),

        if ((question.ekoliText ?? '').isNotEmpty) ...<Widget>[
          const Gap.md(),
          _EkoliPrompt(question: question),
        ],

        const Gap.lg(),
        for (final QuizOption option in question.options) ...<Widget>[
          _OptionTile(
            option: option,
            answered: answered,
            isPicked: picked == option.id,
            onTap: answered ? null : () => _choose(option.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        if (answered) ...<Widget>[
          const Gap.md(),
          _Explanation(question: question, wasCorrect: _attempt.wasCorrect(question)),
          const Gap.lg(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _next,
              icon: Icon(_attempt.isLast ? Icons.flag_outlined : Icons.arrow_forward),
              label: Text(_attempt.isLast ? 'See how you did' : 'Next question'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EkoliPrompt extends StatefulWidget {
  const _EkoliPrompt({required this.question});

  final QuizQuestion question;

  @override
  State<_EkoliPrompt> createState() => _EkoliPromptState();
}

class _EkoliPromptState extends State<_EkoliPrompt> {
  bool _playing = false;

  void _toggle() {
    final String? url = widget.question.audioUrl;
    if (url == null || !ArchiveAudio.isSupported) return;
    if (_playing) {
      ArchiveAudio.stop();
      setState(() => _playing = false);
      return;
    }
    if (ArchiveAudio.play(url)) setState(() => _playing = true);
  }

  @override
  void dispose() {
    if (_playing) ArchiveAudio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasAudio = (widget.question.audioUrl ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              widget.question.ekoliText!,
              style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
          ),
          if (hasAudio && ArchiveAudio.isSupported)
            IconButton.filledTonal(
              onPressed: _toggle,
              tooltip: _playing ? 'Stop' : 'Hear it',
              icon: Icon(_playing ? Icons.stop_rounded : Icons.volume_up_rounded),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.answered,
    required this.isPicked,
    required this.onTap,
  });

  final QuizOption option;
  final bool answered;
  final bool isPicked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Before answering, nothing is coloured. Afterwards the right answer is
    // always shown — including when they picked it — so a child who guessed
    // still learns which one it was.
    Color background = theme.colorScheme.surface;
    Color border = theme.colorScheme.outlineVariant;
    IconData? icon;
    Color iconColour = AppColors.inkMuted;

    if (answered) {
      if (option.isCorrect) {
        background = AppColors.green.withValues(alpha: 0.10);
        border = AppColors.green;
        icon = Icons.check_circle_outline;
        iconColour = AppColors.green;
      } else if (isPicked) {
        background = theme.colorScheme.errorContainer.withValues(alpha: 0.45);
        border = theme.colorScheme.error;
        icon = Icons.cancel_outlined;
        iconColour = theme.colorScheme.error;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: border, width: answered && icon != null ? 2 : 1),
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(option.label, style: theme.textTheme.bodyLarge)),
            if (icon != null) Icon(icon, color: iconColour),
          ],
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.question, required this.wasCorrect});

  final QuizQuestion question;
  final bool wasCorrect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? explanation = question.explanation;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            wasCorrect ? Icons.celebration_outlined : Icons.lightbulb_outline,
            color: wasCorrect ? AppColors.green : AppColors.gold,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  wasCorrect ? 'That’s right' : 'Not this time',
                  style: theme.textTheme.titleSmall,
                ),
                if ((explanation ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(explanation!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({required this.attempt, required this.onRestart});

  final QuizAttempt attempt;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int score = attempt.score;
    final int total = attempt.total;

    // Deliberately warm at every score. A child who got two out of eight has
    // just learned six things about where their family comes from.
    final String headline = score == total
        ? 'Every one right'
        : score >= total * 0.6
            ? 'Well done'
            : 'Now you know a few more';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(headline, style: theme.textTheme.displaySmall),
        const Gap.sm(),
        Text(
          'You got $score of $total.',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if ((attempt.quiz.closing ?? '').isNotEmpty) ...<Widget>[
          const Gap.lg(),
          Text(attempt.quiz.closing!, style: theme.textTheme.bodyLarge),
        ],
        const Gap.xl(),

        // Every question again, with the right answer, so the quiz ends as a
        // page they can read rather than a number.
        for (int i = 0; i < attempt.quiz.questions.length; i++) ...<Widget>[
          _ReviewRow(
            index: i + 1,
            question: attempt.quiz.questions[i],
            wasCorrect: attempt.wasCorrect(attempt.quiz.questions[i]),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        const Gap.xl(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.learn),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Other quizzes'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.index,
    required this.question,
    required this.wasCorrect,
  });

  final int index;
  final QuizQuestion question;
  final bool wasCorrect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            wasCorrect ? Icons.check_circle_outline : Icons.info_outline,
            size: 20,
            color: wasCorrect ? AppColors.green : AppColors.gold,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$index. ${question.prompt}', style: theme.textTheme.bodyMedium),
                if (question.correctOption != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    question.correctOption!.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
