/// LEARN ABOUT EKORI — §17 of the proposal.
///
/// ---------------------------------------------------------------------------
/// NOTHING A CHILD ANSWERS LEAVES THE BROWSER
/// ---------------------------------------------------------------------------
///
/// There is no submit, no score endpoint, and no repository method that sends
/// an answer anywhere. [QuizAttempt] below holds the state of a quiz in
/// progress in memory only; closing the tab is the end of it.
///
/// That is why [QuizOption.isCorrect] arrives from the server: the marking
/// happens here. A child with the developer tools open can read the answers,
/// and that is a fair trade for not keeping a record of what a named child got
/// wrong about their own heritage.
library;

import 'content_status.dart';

const Map<String, String> quizSubjects = <String, String>{
  'language': 'The Ekori language',
  'greetings': 'Greetings',
  'numbers': 'Numbers',
  'proverbs': 'Proverbs',
  'history': 'Our history',
  'culture': 'Culture',
  'leboku': 'Leboku',
  'people': 'People of Ekori',
  'places': 'Places',
  'values': 'Traditional values',
  'general': 'A bit of everything',
};

const Map<String, String> quizLevels = <String, String>{
  'starter': 'Starter',
  'growing': 'Growing',
  'confident': 'Confident',
};

class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.subject = 'general',
    this.level = 'starter',
    this.coverUrl,
  });

  factory QuizSummary.fromJson(Map<String, dynamic> json) => QuizSummary(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    description: Json.strOrNull(json, 'description'),
    subject: Json.str(json, 'subject', fallback: 'general'),
    level: Json.str(json, 'level', fallback: 'starter'),
    coverUrl: Json.strOrNull(json, 'cover_url') ?? Json.strOrNull(json, 'image_url'),
  );

  final String id;
  final String slug;
  final String title;
  final String? description;
  final String subject;
  final String level;
  final String? coverUrl;

  String get subjectLabel => quizSubjects[subject] ?? 'A bit of everything';
  String get levelLabel => quizLevels[level] ?? 'Starter';
}

class QuizOption {
  const QuizOption({required this.id, required this.label, required this.isCorrect});

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    id: Json.str(json, 'id'),
    label: Json.str(json, 'label'),
    isCorrect: Json.boolVal(json, 'is_correct'),
  );

  final String id;
  final String label;
  final bool isCorrect;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.explanation,
    this.ekoliText,
    this.audioUrl,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: Json.str(json, 'id'),
    prompt: Json.str(json, 'prompt'),
    explanation: Json.strOrNull(json, 'explanation'),
    ekoliText: Json.strOrNull(json, 'ekoli_text'),
    audioUrl: Json.strOrNull(json, 'audio_url'),
    options: Json.objectList(json, 'options')
        .map(QuizOption.fromJson)
        .toList(growable: false),
  );

  final String id;
  final String prompt;
  final String? explanation;
  final String? ekoliText;
  final String? audioUrl;
  final List<QuizOption> options;

  QuizOption? get correctOption {
    for (final QuizOption option in options) {
      if (option.isCorrect) return option;
    }
    return null;
  }
}

class Quiz {
  const Quiz({
    required this.id,
    required this.slug,
    required this.title,
    required this.questions,
    this.description,
    this.subject = 'general',
    this.level = 'starter',
    this.intro,
    this.closing,
    this.coverUrl,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    description: Json.strOrNull(json, 'description'),
    subject: Json.str(json, 'subject', fallback: 'general'),
    level: Json.str(json, 'level', fallback: 'starter'),
    intro: Json.strOrNull(json, 'intro'),
    closing: Json.strOrNull(json, 'closing'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
    questions: Json.objectList(json, 'questions')
        .map(QuizQuestion.fromJson)
        .toList(growable: false),
  );

  final String id;
  final String slug;
  final String title;
  final String? description;
  final String subject;
  final String level;
  final String? intro;
  final String? closing;
  final String? coverUrl;
  final List<QuizQuestion> questions;

  String get subjectLabel => quizSubjects[subject] ?? 'A bit of everything';
  String get levelLabel => quizLevels[level] ?? 'Starter';
}

/// One run through a quiz, held in memory and nowhere else.
///
/// Not persisted to the device either: `shared_preferences` would leave a
/// record of a child's answers on a shared family computer, which is the same
/// problem as a server record with a smaller radius.
class QuizAttempt {
  QuizAttempt(this.quiz);

  final Quiz quiz;

  /// question id → the option they chose.
  final Map<String, String> chosen = <String, String>{};

  int index = 0;

  QuizQuestion get current => quiz.questions[index];
  bool get isLast => index >= quiz.questions.length - 1;
  bool get isAnswered => chosen.containsKey(current.id);
  int get total => quiz.questions.length;

  String? chosenFor(QuizQuestion question) => chosen[question.id];

  bool wasCorrect(QuizQuestion question) {
    final String? picked = chosen[question.id];
    if (picked == null) return false;
    return question.correctOption?.id == picked;
  }

  int get score {
    int right = 0;
    for (final QuizQuestion question in quiz.questions) {
      if (wasCorrect(question)) right++;
    }
    return right;
  }

  void choose(String optionId) {
    // Answers are final once given — a child should read the explanation
    // rather than hunt for the green tick.
    chosen.putIfAbsent(current.id, () => optionId);
  }

  void next() {
    if (!isLast) index++;
  }

  void restart() {
    chosen.clear();
    index = 0;
  }
}
