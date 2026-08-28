/// VOICES OF EKORI — §8 of the proposal.
///
/// An oral history recording is not a video with extra fields. What makes it
/// hard is not the file: it is that somebody's words are being kept, and that
/// an interpretation of those words must never quietly become the words.
///
/// So [transcript] and [englishInterpretation] are separate all the way through
/// — separate columns, separate fields, separate blocks on the page — and the
/// interpretation is always labelled with who made it.
library;

import 'content_status.dart';

/// What the recording is about. The proposal's own list of topics.
const Map<String, String> recordingTopics = <String, String>{
  'life_in_old_ekori': 'Life in old Ekori',
  'history': 'History',
  'traditional_practices': 'Traditional practices',
  'leboku': 'Leboku',
  'marriage': 'Traditional marriage',
  'naming': 'Naming ceremonies',
  'farming': 'Farming',
  'food': 'Food',
  'songs': 'Songs',
  'folklore': 'Folklore',
  'proverbs': 'Proverbs',
  'community_development': 'Community development',
  'historical_events': 'Historical events',
  'people': 'People of Ekori',
  'other': 'Other',
};

const Map<String, String> transcriptLanguages = <String, String>{
  'ekoli': 'Ekoli',
  'english': 'English',
  'mixed': 'Ekoli and English',
  'other': 'Another language',
};

class Recording {
  const Recording({
    required this.id,
    required this.slug,
    required this.title,
    this.summary,
    this.speaker,
    this.speakerRole,
    this.youtubeVideoId,
    this.audioUrl,
    this.transcript,
    this.transcriptLanguage = 'ekoli',
    this.englishInterpretation,
    this.interpretedBy,
    this.topic,
    this.recordedAt,
    this.recordedLocation,
    this.recordedBy,
    this.durationSeconds,
    this.coverUrl,
    this.isFeatured = false,
    this.verificationStatus,
  });

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    summary: Json.strOrNull(json, 'summary'),
    speaker: Json.strOrNull(json, 'speaker'),
    speakerRole: Json.strOrNull(json, 'speaker_role'),
    youtubeVideoId: Json.strOrNull(json, 'youtube_video_id'),
    audioUrl: Json.strOrNull(json, 'audio_url') ?? Json.strOrNull(json, 'image_url'),
    transcript: Json.strOrNull(json, 'transcript'),
    transcriptLanguage: Json.str(json, 'transcript_language', fallback: 'ekoli'),
    englishInterpretation: Json.strOrNull(json, 'english_interpretation'),
    interpretedBy: Json.strOrNull(json, 'interpreted_by'),
    topic: Json.strOrNull(json, 'topic'),
    recordedAt: Json.strOrNull(json, 'recorded_at'),
    recordedLocation: Json.strOrNull(json, 'recorded_location'),
    recordedBy: Json.strOrNull(json, 'recorded_by'),
    durationSeconds: Json.intOrNull(json, 'duration_seconds'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
    isFeatured: Json.boolVal(json, 'is_featured'),
    verificationStatus: Json.strOrNull(json, 'verification_status'),
  );

  final String id;
  final String slug;
  final String title;
  final String? summary;

  final String? speaker;
  final String? speakerRole;

  /// A recording carries film, or audio, or both — never neither. The database
  /// enforces it and the Worker refuses a payload without one.
  final String? youtubeVideoId;
  final String? audioUrl;

  final String? transcript;
  final String transcriptLanguage;

  /// Somebody's reading of the words. Shown beside the transcript, never
  /// instead of it, and never without [interpretedBy] where that is known.
  final String? englishInterpretation;
  final String? interpretedBy;

  final String? topic;
  final String? recordedAt;
  final String? recordedLocation;
  final String? recordedBy;
  final int? durationSeconds;
  final String? coverUrl;
  final bool isFeatured;
  final String? verificationStatus;

  bool get hasFilm => (youtubeVideoId ?? '').isNotEmpty;
  bool get hasAudio => (audioUrl ?? '').isNotEmpty;
  bool get hasTranscript => (transcript ?? '').trim().isNotEmpty;
  bool get hasInterpretation => (englishInterpretation ?? '').trim().isNotEmpty;

  String get topicLabel => recordingTopics[topic] ?? '';
  String get languageLabel => transcriptLanguages[transcriptLanguage] ?? 'Ekoli';

  /// `1:04:22`, or `7:41`. Null when nobody recorded a duration.
  String? get durationLabel {
    final int? total = durationSeconds;
    if (total == null || total <= 0) return null;
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final int seconds = total % 60;
    final String mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}
