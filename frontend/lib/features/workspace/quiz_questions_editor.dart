import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../models/content_status.dart';
import '../../services/api/api_client.dart';
import 'media_selection_field.dart';

/// Owns controllers for the full question set. No learner answers are stored.
class QuizQuestionsEditor extends StatefulWidget {
  const QuizQuestionsEditor({this.quizId, super.key});
  final String? quizId;

  @override
  State<QuizQuestionsEditor> createState() => QuizQuestionsEditorState();
}

class QuizQuestionsEditorState extends State<QuizQuestionsEditor> {
  final List<_Question> _questions = <_Question>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.quizId != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().get(
        '/api/editorial/quizzes/${widget.quizId}/questions',
      );
      if (!mounted) return;
      for (final question in _questions) {
        question.dispose();
      }
      _questions
        ..clear()
        ..addAll(Json.objectList(data, 'items').map(_Question.fromJson));
    } on AppException catch (error) {
      if (mounted) _error = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool validate() {
    if (_loading || _error != null) return false;
    String? error;
    if (_questions.isEmpty) {
      error = 'Add at least one question before saving the quiz.';
    }
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.prompt.text.trim().isEmpty ||
          q.options.any((o) => o.text.trim().isEmpty)) {
        error = 'Complete the question and every answer on question ${i + 1}.';
        break;
      }
      if (q.correct < 0 || q.correct >= q.options.length) {
        error = 'Choose the correct answer on question ${i + 1}.';
        break;
      }
    }
    setState(() => _validation = error);
    return error == null;
  }

  String? _validation;

  List<Map<String, dynamic>> collect() => _questions
      .map(
        (q) => <String, dynamic>{
          'prompt': q.prompt.text.trim(),
          'explanation': q.explanation.text.trim(),
          'ekoli_text': q.ekoli.text.trim(),
          'audio_media_id': q.audio.text.trim().isEmpty
              ? null
              : q.audio.text.trim(),
          'options': q.options
              .asMap()
              .entries
              .map(
                (e) => <String, dynamic>{
                  'label': e.value.text.trim(),
                  'is_correct': q.correct == e.key,
                },
              )
              .toList(),
        },
      )
      .toList();

  @override
  void dispose() {
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _move(int from, int to) => setState(() {
    final q = _questions.removeAt(from);
    _questions.insert(to, q);
  });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_error != null) {
      return Column(
        children: <Widget>[
          Text(_error!),
          TextButton(
            onPressed: _load,
            child: const Text('Retry loading questions'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Questions', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Choose one correct answer per question. Use the arrows to change the order.',
        ),
        if (_validation != null)
          Text(
            _validation!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (var i = 0; i < _questions.length; i++) _questionCard(i),
        OutlinedButton.icon(
          onPressed: _questions.length >= 50
              ? null
              : () => setState(() => _questions.add(_Question())),
          icon: const Icon(Icons.add),
          label: const Text('Add question'),
        ),
      ],
    );
  }

  Widget _questionCard(int index) {
    final q = _questions[index];
    return Card(
      key: ObjectKey(q),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('Question ${index + 1}'),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: index == 0 ? null : () => _move(index, index - 1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: index == _questions.length - 1
                      ? null
                      : () => _move(index, index + 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: () => setState(() {
                    _questions.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              controller: q.prompt,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            TextFormField(
              controller: q.ekoli,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Ekoli word or phrase (optional)',
              ),
            ),
            MediaSelectionField(
              label: 'Question audio (optional)',
              kind: 'audio',
              controller: q.audio,
            ),
            for (var n = 0; n < q.options.length; n++)
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Mark answer ${n + 1} correct',
                    onPressed: () => setState(() => q.correct = n),
                    icon: Icon(
                      q.correct == n
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: q.options[n],
                      maxLength: 300,
                      decoration: InputDecoration(labelText: 'Answer ${n + 1}'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove answer',
                    onPressed: q.options.length <= 2
                        ? null
                        : () => setState(() {
                            q.options.removeAt(n).dispose();
                            if (q.correct == n) {
                              q.correct = -1;
                            } else if (q.correct > n) {
                              q.correct--;
                            }
                          }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            TextButton(
              onPressed: q.options.length >= 6
                  ? null
                  : () =>
                        setState(() => q.options.add(TextEditingController())),
              child: const Text('Add answer'),
            ),
            TextFormField(
              controller: q.explanation,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Explanation after answering',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question {
  _Question();
  factory _Question.fromJson(Map<String, dynamic> data) {
    final q = _Question();
    q.prompt.text = Json.str(data, 'prompt');
    q.explanation.text = Json.str(data, 'explanation');
    q.ekoli.text = Json.str(data, 'ekoli_text');
    q.audio.text = Json.str(data, 'audio_media_id');
    for (final option in q.options) {
      option.dispose();
    }
    q.options.clear();
    for (final option in Json.objectList(data, 'options')) {
      if (Json.boolVal(option, 'is_correct')) q.correct = q.options.length;
      q.options.add(TextEditingController(text: Json.str(option, 'label')));
    }
    return q;
  }
  final prompt = TextEditingController();
  final explanation = TextEditingController();
  final ekoli = TextEditingController();
  final audio = TextEditingController();
  final options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  int correct = -1;
  void dispose() {
    prompt.dispose();
    explanation.dispose();
    ekoli.dispose();
    audio.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
