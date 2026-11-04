import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'pdf_actions.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// One question being typed in the builder.
class _QuestionDraft {
  String type = 'mcq'; // 'mcq' or 'text'
  final TextEditingController text = TextEditingController();
  final TextEditingController points = TextEditingController(text: '1');
  final List<TextEditingController> choices = [
    TextEditingController(),
    TextEditingController(),
  ];
  int correct = 0; // index of the correct choice
}

class QuizEditorPage extends StatefulWidget {
  const QuizEditorPage({super.key, required this.courseId, this.chapterId});

  final String courseId;
  final String? chapterId;

  @override
  State<QuizEditorPage> createState() => _QuizEditorPageState();
}

class _QuizEditorPageState extends State<QuizEditorPage> {
  final _title = TextEditingController();
  final List<_QuestionDraft> _questions = [_QuestionDraft()];
  final QuizSchedule _schedule = QuizSchedule();
  String _kind = 'quiz';
  PickedPdf? _pdf;
  // Controllers of removed questions/choices. They are disposed together at the end,
  // because disposing one while its text field is still on screen causes errors.
  final List<TextEditingController> _trash = [];
  bool _saving = false;
  String? _error;

  bool get _isStaff => Session.role == 'instructor' || Session.role == 'admin';

  @override
  void dispose() {
    _title.dispose();
    for (final q in _questions) {
      q.text.dispose();
      q.points.dispose();
      for (final c in q.choices) {
        c.dispose();
      }
    }
    for (final c in _trash) {
      c.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(_QuestionDraft()));

  void _removeQuestion(int i) {
    setState(() {
      final q = _questions.removeAt(i);
      _trash.add(q.text);
      _trash.add(q.points);
      _trash.addAll(q.choices);
    });
  }

  void _removeChoice(_QuestionDraft q, int j) {
    setState(() {
      _trash.add(q.choices.removeAt(j));
      if (q.correct == j) {
        q.correct = 0;
      } else if (q.correct > j) {
        q.correct -= 1;
      }
    });
  }

  Future<void> _choosePdf() async {
    final pdf = await pickPdf(context);
    if (pdf != null && mounted) setState(() => _pdf = pdf);
  }

  Future<void> _save({required bool publish}) async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }

    final questions = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final n = i + 1;

      final text = q.text.text.trim();
      if (text.isEmpty) {
        setState(() => _error = 'Question $n needs text.');
        return;
      }
      final points = int.tryParse(q.points.text.trim());
      if (points == null || points < 1 || points > 100) {
        setState(() => _error = 'Question $n: points must be a whole number from 1 to 100.');
        return;
      }

      if (q.type == 'text') {
        questions.add({'type': 'text', 'text': text, 'points': points});
        continue;
      }

      final choices = q.choices.map((c) => c.text.trim()).toList();
      if (choices.any((c) => c.isEmpty)) {
        setState(() => _error = 'Question $n: fill in every choice or remove the empty ones.');
        return;
      }
      questions.add({
        'type': 'mcq',
        'text': text,
        'choices': choices,
        'correctIndex': q.correct,
        'points': points,
      });
    }

    final scheduleProblem = _schedule.check();
    if (scheduleProblem != null) {
      setState(() => _error = scheduleProblem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quizId = await ChapterApi.createQuiz(
        widget.courseId,
        chapterId: widget.chapterId,
        kind: _kind,
        title: title,
        questions: questions,
        published: publish,
        opensAt: _schedule.opensAt,
        dueAt: _schedule.dueAt,
        maxAttempts: _schedule.maxAttempts,
        lockAi: _schedule.lockAi,
        blockPaste: _schedule.blockPaste,
        shuffle: _schedule.shuffle,
        timeLimitMinutes: _schedule.timeLimitMinutes,
      );

      var message = publish
          ? '${kindLabel(_kind)} published.'
          : '${kindLabel(_kind)} saved as a draft.';

      // The PDF goes up after the item exists. If it fails, the item is still saved.
      if (_pdf != null) {
        try {
          await FileApi.upload('quiz', quizId, _pdf!.name, _pdf!.bytes);
        } catch (e) {
          message = '$message The PDF did not upload (${errorText(e)}). You can add it later from the menu.';
        }
      }

      if (!mounted) return;
      showSnack(context, message);
      goBack(context, '/course/${widget.courseId}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStaff) {
      return const AppShell(
        selected: 'courses',
        body: PageBody(
          child: CenteredMessage('Only instructors and admins can create quizzes.'),
        ),
      );
    }
    return AppShell(
      selected: 'courses',
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => goBack(context, '/course/${widget.courseId}'),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.label),
                label: Text('COURSE', style: AppText.sans(size: 11, color: AppColors.label)),
              ),
            ),
            pageTitle('NEW QUIZ / ACTIVITY'),
            const SizedBox(height: 10),
            CardBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fieldLabel('TYPE'),
                  SizedBox(
                    width: 260,
                    child: SelectBox<String>(
                      value: _kind,
                      items: [
                        for (final e in quizKinds.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _kind = v),
                    ),
                  ),
                  fieldLabel('TITLE'),
                  inputField(_title, 'e.g. Quiz 1 - Introduction'),
                  fieldLabel('INSTRUCTIONS PDF (OPTIONAL)'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _pdf?.name ?? 'No file attached',
                        style: AppText.sans(
                          size: 12,
                          color: _pdf == null ? Colors.black54 : AppColors.darkBrown,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _saving ? null : _choosePdf,
                        child: Text(_pdf == null ? 'Attach PDF' : 'Change',
                            style: AppText.sans(size: 11, color: AppColors.label)),
                      ),
                      if (_pdf != null)
                        TextButton(
                          onPressed: _saving ? null : () => setState(() => _pdf = null),
                          child: Text('Remove',
                              style: AppText.sans(size: 11, color: AppColors.label)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CardBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SCHEDULE', style: AppText.sans(size: 11, color: AppColors.title)),
                  ScheduleFields(schedule: _schedule, onChanged: () => setState(() {})),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _questions.length; i++) _questionCard(i, _questions[i]),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.label),
                label: Text('Add question',
                    style: AppText.sans(size: 11, color: AppColors.label)),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(publish: false),
                  child: Text('SAVE AS DRAFT',
                      style: AppText.sans(size: 11, color: AppColors.label)),
                ),
                primaryButton(
                  label: 'PUBLISH',
                  loading: _saving,
                  onPressed: () => _save(publish: true),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(int i, _QuestionDraft q) {
    return Padding(
      key: ObjectKey(q),
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('QUESTION ${i + 1}',
                    style: AppText.sans(size: 11, color: AppColors.title)),
                const Spacer(),
                if (_questions.length > 1)
                  IconButton(
                    tooltip: 'Remove question',
                    iconSize: 18,
                    onPressed: () => _removeQuestion(i),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.label),
                  ),
              ],
            ),
            fieldLabel('TYPE'),
            SelectBox<String>(
              value: q.type,
              items: const [
                DropdownMenuItem(value: 'mcq', child: Text('Multiple choice')),
                DropdownMenuItem(value: 'text', child: Text('Written answer')),
              ],
              onChanged: (v) => setState(() => q.type = v),
            ),
            const SizedBox(height: 4),
            Text(
              q.type == 'mcq'
                  ? 'Graded automatically.'
                  : 'Students type an answer. You grade it yourself.',
              style: AppText.sans(size: 10, color: Colors.black54),
            ),
            fieldLabel('QUESTION'),
            inputField(q.text, 'Type the question', minLines: 2, maxLines: 5),
            fieldLabel('POINTS'),
            SizedBox(width: 100, child: inputField(q.points, '1')),
            if (q.type == 'mcq') ..._choiceFields(q),
          ],
        ),
      ),
    );
  }

  List<Widget> _choiceFields(_QuestionDraft q) {
    return [
      fieldLabel('CHOICES (TAP THE CIRCLE NEXT TO THE CORRECT ONE)'),
      for (var j = 0; j < q.choices.length; j++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Mark as correct',
                onPressed: () => setState(() => q.correct = j),
                icon: Icon(
                  q.correct == j
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.sidebar,
                ),
              ),
              Expanded(child: inputField(q.choices[j], 'Choice ${j + 1}')),
              if (q.choices.length > 2)
                IconButton(
                  tooltip: 'Remove choice',
                  iconSize: 18,
                  onPressed: () => _removeChoice(q, j),
                  icon: const Icon(Icons.close_rounded, color: AppColors.label),
                ),
            ],
          ),
        ),
      if (q.choices.length < 6)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => q.choices.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.label),
            label: Text('Add choice', style: AppText.sans(size: 11, color: AppColors.label)),
          ),
        ),
    ];
  }
}