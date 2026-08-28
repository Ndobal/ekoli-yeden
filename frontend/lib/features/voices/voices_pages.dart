/// VOICES OF EKORI — §8 of the proposal.
///
/// ---------------------------------------------------------------------------
/// THE ONE RULE THIS PAGE IS BUILT AROUND
/// ---------------------------------------------------------------------------
///
/// The transcript and the English interpretation never share a block.
///
/// It would be tidier to show one flowing text with the translation folded in.
/// It would also, slowly and invisibly, turn somebody's words into somebody
/// else's summary of them. An elder describing a naming ceremony said what they
/// said; the interpretation is a second person's reading, made at a particular
/// time, and a reader fifty years from now needs to be able to tell which is
/// which and who is responsible for each.
///
/// So they sit in two labelled panels, the original first, and the
/// interpretation always carries the name of whoever made it.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/audio/audio_playback.dart';
import '../../core/utils/video/youtube_embed.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/recording.dart';
import '../../repositories/discover_repository.dart';

// ---------------------------------------------------------------------------
// The list
// ---------------------------------------------------------------------------

class VoicesPage extends StatefulWidget {
  const VoicesPage({super.key});

  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> {
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final DiscoverRepository repository = context.read<DiscoverRepository>();

    return AppScaffold(
      currentPath: AppRoutes.voices,
      seo: const SeoMetadata(
        title: 'Voices of Ekori — oral history',
        description:
            'Elders and others who remember Ekori, recorded in their own words, with '
            'transcripts and English interpretations.',
        canonicalPath: AppRoutes.voices,
      ),
      child: PageSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const CmsText(
              'page.voices.title',
              fallback: 'Voices of Ekori',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.15),
            ),
            const Gap.md(),
            const CmsText(
              'page.voices.intro',
              fallback:
                  'Elders, traditional leaders and others who remember, recorded in their own '
                  'words. Each recording is kept as it was spoken. Where an English '
                  'interpretation is given it sits beside the original and never replaces it.',
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const Gap.xl(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilterChip(
                  label: const Text('Everything'),
                  selected: _topic == null,
                  onSelected: (_) => setState(() => _topic = null),
                ),
                for (final MapEntry<String, String> entry in recordingTopics.entries)
                  if (entry.key != 'other')
                    FilterChip(
                      label: Text(entry.value),
                      selected: _topic == entry.key,
                      onSelected: (bool selected) =>
                          setState(() => _topic = selected ? entry.key : null),
                    ),
              ],
            ),
            const Gap.xxl(),
            AsyncContent<List<Recording>>(
              key: ValueKey<String>('voices:$_topic'),
              load: () => repository.recordings(topic: _topic),
              loadingMessage: 'Opening the oral history archive…',
              isEmpty: (List<Recording> items) => items.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.record_voice_over_outlined,
                title: 'No recordings yet',
                message:
                    'The oral history project begins with a conversation, not a website. When '
                    'elders have been recorded and their consent noted, their voices will be '
                    'kept here — with a transcript in the language they were speaking, and an '
                    'English interpretation beside it.',
              ),
              builder: (BuildContext context, List<Recording> items) => ResponsiveCardGrid(
                children: items
                    .map((Recording recording) => _RecordingCard(recording: recording))
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.go(AppRoutes.voice(recording.slug)),
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
                Icon(
                  recording.hasFilm ? Icons.videocam_outlined : Icons.graphic_eq,
                  size: 17,
                  color: AppColors.gold,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  recording.hasFilm ? 'FILM' : 'AUDIO',
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
                ),
                if (recording.durationLabel != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    recording.durationLabel!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            const Gap.sm(),
            Text(
              recording.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((recording.speaker ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                (recording.speakerRole ?? '').isEmpty
                    ? recording.speaker!
                    : '${recording.speaker} · ${recording.speakerRole}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if ((recording.summary ?? '').isNotEmpty) ...<Widget>[
              const Gap.sm(),
              Text(
                recording.summary!,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Gap.md(),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (recording.topicLabel.isNotEmpty) _Chip(label: recording.topicLabel),
                if (recording.hasTranscript) const _Chip(label: 'Transcript'),
                if (recording.hasInterpretation) const _Chip(label: 'English'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

// ---------------------------------------------------------------------------
// One recording
// ---------------------------------------------------------------------------

class VoicePage extends StatelessWidget {
  const VoicePage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final DiscoverRepository repository = context.read<DiscoverRepository>();

    return AsyncContent<Recording>(
      load: () => repository.recording(slug),
      loadingMessage: 'Opening the recording…',
      builder: (BuildContext context, Recording recording) {
        final ThemeData theme = Theme.of(context);

        return AppScaffold(
          currentPath: AppRoutes.voices,
          seo: SeoMetadata(
            title: '${recording.title} — Voices of Ekori',
            description: recording.summary ??
                'An oral history recording from Ekori, kept in the words it was spoken in.',
            canonicalPath: AppRoutes.voice(recording.slug),
            type: 'article',
          ),
          child: PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(recording.title, style: theme.textTheme.displaySmall),
                const Gap.md(),
                _SpeakerHeader(recording: recording),
                const Gap.xl(),

                // The recording itself. Film where there is film, the audio
                // where there is audio, and both where both exist.
                if (recording.hasFilm) _FilmBlock(recording: recording),
                if (recording.hasFilm && recording.hasAudio) const Gap.lg(),
                if (recording.hasAudio) _AudioBlock(recording: recording),

                if ((recording.summary ?? '').isNotEmpty) ...<Widget>[
                  const Gap.xl(),
                  Text(recording.summary!, style: theme.textTheme.bodyLarge),
                ],

                const Gap.xl(),

                // The two panels that must never merge.
                if (recording.hasTranscript)
                  _WordsPanel(
                    label: 'What was said',
                    sublabel: 'In ${recording.languageLabel}, as recorded',
                    accent: AppColors.navy,
                    text: recording.transcript!,
                  ),
                if (recording.hasTranscript && recording.hasInterpretation) const Gap.lg(),
                if (recording.hasInterpretation)
                  _WordsPanel(
                    label: 'English interpretation',
                    sublabel: (recording.interpretedBy ?? '').isEmpty
                        ? 'An interpretation, not a translation of record'
                        : 'Interpreted by ${recording.interpretedBy}',
                    accent: AppColors.gold,
                    text: recording.englishInterpretation!,
                  ),

                if (!recording.hasTranscript && !recording.hasInterpretation) ...<Widget>[
                  const Gap.lg(),
                  _NoTranscriptNotice(recording: recording),
                ],

                const Gap.xxl(),
                _RecordingFacts(recording: recording),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpeakerHeader extends StatelessWidget {
  const _SpeakerHeader({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if ((recording.speaker ?? '').isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(color: AppColors.navy, borderRadius: AppRadius.lgAll),
      child: Row(
        children: <Widget>[
          const Icon(Icons.record_voice_over_outlined, color: AppColors.goldLight, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recording.speaker!,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                if ((recording.speakerRole ?? '').isNotEmpty)
                  Text(
                    recording.speakerRole!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.skyBlue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The film, behind a click so nothing loads from YouTube until asked.
class _FilmBlock extends StatefulWidget {
  const _FilmBlock({required this.recording});

  final Recording recording;

  @override
  State<_FilmBlock> createState() => _FilmBlockState();
}

class _FilmBlockState extends State<_FilmBlock> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_playing && YoutubeEmbed.isSupported) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubeEmbed.player(
          widget.recording.youtubeVideoId!,
          title: widget.recording.title,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InkWell(
        onTap: YoutubeEmbed.isSupported ? () => setState(() => _playing = true) : null,
        borderRadius: AppRadius.mdAll,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.navyDark,
            borderRadius: AppRadius.mdAll,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.play_circle_outline, size: 56, color: Colors.white),
              const Gap.sm(),
              Text(
                YoutubeEmbed.isSupported ? 'Play this recording' : 'Open on YouTube',
                style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioBlock extends StatefulWidget {
  const _AudioBlock({required this.recording});

  final Recording recording;

  @override
  State<_AudioBlock> createState() => _AudioBlockState();
}

class _AudioBlockState extends State<_AudioBlock> {
  bool _playing = false;

  void _toggle() {
    if (!ArchiveAudio.isSupported) return;
    if (_playing) {
      ArchiveAudio.stop();
      setState(() => _playing = false);
      return;
    }
    final bool started = ArchiveAudio.play(widget.recording.audioUrl!);
    if (started) setState(() => _playing = true);
  }

  @override
  void dispose() {
    if (_playing) ArchiveAudio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          IconButton.filled(
            onPressed: ArchiveAudio.isSupported ? _toggle : null,
            iconSize: 30,
            tooltip: _playing ? 'Stop' : 'Play this recording',
            icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Listen', style: theme.textTheme.titleSmall),
                Text(
                  widget.recording.durationLabel == null
                      ? 'Audio recording'
                      : 'Audio recording · ${widget.recording.durationLabel}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One block of words, labelled with whose they are.
class _WordsPanel extends StatelessWidget {
  const _WordsPanel({
    required this.label,
    required this.sublabel,
    required this.accent,
    required this.text,
  });

  final String label;
  final String sublabel;
  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTranscriptNotice extends StatelessWidget {
  const _NoTranscriptNotice({required this.recording});

  final Recording recording;

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
          Icon(Icons.edit_note_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'No transcript has been written for this recording yet. A transcript is what '
              'makes a recording searchable, quotable, and readable by somebody who cannot '
              'play audio — if you can follow ${recording.languageLabel} well enough to write '
              'it down, the archive would be glad of the help.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingFacts extends StatelessWidget {
  const _RecordingFacts({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<(String, String)> facts = <(String, String)>[
      if (recording.topicLabel.isNotEmpty) ('Subject', recording.topicLabel),
      if ((recording.recordedAt ?? '').isNotEmpty) ('Recorded', recording.recordedAt!),
      if ((recording.recordedLocation ?? '').isNotEmpty) ('Where', recording.recordedLocation!),
      if ((recording.recordedBy ?? '').isNotEmpty) ('Recorded by', recording.recordedBy!),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xxl,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        for (final (String label, String value) in facts)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
      ],
    );
  }
}
