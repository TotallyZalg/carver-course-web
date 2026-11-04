import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'pdf_actions.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// Rejects any single change that adds many characters at once (a paste).
class NoPasteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final sel = oldValue.selection;
    final removed = sel.isValid && !sel.isCollapsed ? sel.end - sel.start : 0;
    final inserted = newValue.text.length - (oldValue.text.length - removed);
    if (inserted > 12) return oldValue;
    return newValue;
  }
}

class _Loaded {
  _Loaded(this.quiz, this.result);
  final QuizTake quiz;
  final QuizResult? result; // the student's latest try, if they have one
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.quizId});

  final String quizId;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late Future<_Loaded> _future;
  QuizResult? _shown; // the result on screen (after submitting, or when looking back at a try)
  bool _taking = false; // true after pressing TRY AGAIN
  final Map<String, int> _choices = {}; // question id -> chosen choice
  final Map<String, TextEditingController> _texts = {}; // question id -> written answer
  bool _submitting = false;
  String? _error;
  List<QuizQuestion>? _timedQuestions; // questions given by START (timed quizzes only)
  DateTime? _endsAt; // when the timer ends (this device's clock)
  Timer? _ticker;
  int _secondsLeft = 0;
  bool _starting = false;

  bool get _isStudent => Session.role == 'student';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<_Loaded> _load() async {
    final quiz = await QuizTakeApi.quiz(widget.quizId);
    QuizResult? result;
    if (quiz.attemptsUsed > 0) {
      result = await QuizTakeApi.mySubmission(widget.quizId);
    }
    return _Loaded(quiz, result);
  }

  void _clearAnswers() {
    _ticker?.cancel();
    _timedQuestions = null;
    _endsAt = null;
    for (final c in _texts.values) {
      c.dispose();
    }
    _texts.clear();
    _choices.clear();
  }

  /// Loads everything again (used by "Try again" on a failed load).
  void _reload() {
    _clearAnswers();
    setState(() {
      _shown = null;
      _taking = false;
      _error = null;
      _future = _load();
    });
  }

  /// TRY AGAIN: load the quiz fresh (new try number, questions) and show the questions.
  void _retry() {
    _clearAnswers();
    setState(() {
      _shown = null;
      _taking = true;
      _error = null;
      _future = _load();
    });
  }

  TextEditingController _textFor(String questionId) =>
      _texts.putIfAbsent(questionId, () => TextEditingController());

  /// The questions on screen: the ones START gave (timed quiz) or the quiz's own.
  List<QuizQuestion> _questionsOf(QuizTake quiz) => _timedQuestions ?? quiz.questions;

  /// Timed quiz: asks the server to start the clock, then shows the questions.
  Future<void> _start(QuizTake quiz) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final s = await QuizTakeApi.start(widget.quizId);
      if (!mounted) return;
      _clearAnswers();
      setState(() {
        _timedQuestions = s.questions;
        _endsAt = DateTime.now().add(Duration(seconds: s.secondsLeft));
        _secondsLeft = s.secondsLeft;
        _starting = false;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick(quiz));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _starting = false;
      });
    }
  }

  /// Runs every second. At 0:00 it submits by itself.
  void _tick(QuizTake quiz) {
    if (!mounted || _endsAt == null) {
      _ticker?.cancel();
      return;
    }
    final left = _endsAt!.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _ticker?.cancel();
      setState(() => _secondsLeft = 0);
      if (!_submitting) _submit(quiz, auto: true);
      return;
    }
    setState(() => _secondsLeft = left);
  }

  Future<void> _submit(QuizTake quiz, {bool auto = false}) async {
    final unanswered = _questionsOf(quiz).where((q) {
      if (q.isChoice) return !_choices.containsKey(q.id);
      return (_texts[q.id]?.text.trim() ?? '').isEmpty;
    }).length;

    final warning = unanswered > 0
        ? 'You left $unanswered question${unanswered == 1 ? '' : 's'} unanswered. '
        : '';
    final ok = auto ||
        await confirmDialog(
      context,
      title: 'Submit quiz',
      message:
          '${warning}This uses try ${quiz.attemptsUsed + 1} of ${quiz.maxAttempts}. You cannot change your answers afterwards.',
      confirmLabel: 'Submit',
    );
    if (!ok || !mounted) return;

    final answers = <Map<String, dynamic>>[];
    for (final q in _questionsOf(quiz)) {
      if (q.isChoice) {
        answers.add({'questionId': q.id, 'choiceIndex': _choices[q.id]});
      } else {
        answers.add({'questionId': q.id, 'text': _texts[q.id]?.text ?? ''});
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await QuizTakeApi.submit(widget.quizId, answers);
      _ticker?.cancel();
      if (!mounted) return;
      _timedQuestions = null;
      _endsAt = null;
      setState(() {
        _shown = result;
        _taking = false;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _submitting = false;
      });
    }
  }

  Future<void> _viewAttempt(int attempt) async {
    try {
      final result = await QuizTakeApi.mySubmission(widget.quizId, attempt: attempt);
      if (!mounted) return;
      setState(() {
        _shown = result;
        _taking = false;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStudent) {
      return const AppShell(
        selected: 'courses',
        body: PageBody(child: CenteredMessage('Only students take quizzes.')),
      );
    }
    return AppShell(
      selected: 'courses',
      body: PageBody(
        child: FutureBuilder<_Loaded>(
          future: _future,
          builder: (context, snapshot) {
            final done = snapshot.connectionState == ConnectionState.done;
            final loaded = done && !snapshot.hasError ? snapshot.data : null;
            final fallback = loaded != null && loaded.quiz.courseId.isNotEmpty
                ? '/course/${loaded.quiz.courseId}'
                : '/courses';

            Widget content;
            if (!done) {
              content = const LoadingBox();
            } else if (snapshot.hasError) {
              content = CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
            } else {
              content = _content(snapshot.data!);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => goBack(context, fallback),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.label),
                    label: Text('COURSE', style: AppText.sans(size: 11, color: AppColors.label)),
                  ),
                ),
                const SizedBox(height: 6),
                content,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(_Loaded loaded) {
    final quiz = loaded.quiz;
    final result = _shown ?? loaded.result;

    if (_taking && quiz.canTake) return _takeView(quiz);
    if (result != null) return _resultView(quiz, result);
    if (quiz.canTake) return _takeView(quiz);
    return _infoView(quiz);
  }

  // ----- shared header -----

  Widget _header(QuizTake quiz) {
    final schedule = [
      if (quiz.opensAt != null) 'Opens ${formatWhen(quiz.opensAt!)}',
      if (quiz.dueAt != null) 'Due ${formatWhen(quiz.dueAt!)}',
      '${quiz.maxAttempts} ${quiz.maxAttempts == 1 ? 'try' : 'tries'} allowed',
    ].join(' · ');

    return CardBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quiz.title, style: AppText.serif(size: 22, color: AppColors.title)),
          const SizedBox(height: 6),
          Text('${quiz.totalPoints} points', style: AppText.sans(size: 11, color: AppColors.label)),
          Text(schedule, style: AppText.sans(size: 11, color: AppColors.orange)),
          if (quiz.fileId != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => openPdf(context, quiz.fileId!),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.label),
                label: Text(quiz.fileName ?? 'Instructions (PDF)',
                    style: AppText.sans(size: 11, color: AppColors.label)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ----- the quiz cannot be taken right now -----

  Widget _infoView(QuizTake quiz) {
    String message;
    if (quiz.state == 'upcoming' && quiz.opensAt != null) {
      message = 'This quiz opens on ${formatWhen(quiz.opensAt!)}.';
    } else if (quiz.state == 'closed') {
      message = 'This quiz is closed. The deadline has passed.';
    } else {
      message = 'This quiz is not available right now.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(quiz),
        CenteredMessage(message),
      ],
    );
  }

  // ----- answering -----

  Widget _takeView(QuizTake quiz) {
    if (quiz.timeLimitMinutes > 0 && _timedQuestions == null) return _startView(quiz);
    final questions = _questionsOf(quiz);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(quiz),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Try ${quiz.attemptsUsed + 1} of ${quiz.maxAttempts}',
            style: AppText.sans(size: 12, color: AppColors.title),
          ),
        ),
        if (_endsAt != null) _timerBar(),
        for (var i = 0; i < questions.length; i++)
          _questionCard(i, questions[i], blockPaste: quiz.blockPaste),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: primaryButton(
            label: 'SUBMIT',
            loading: _submitting,
            onPressed: () => _submit(quiz),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Shown before a timed quiz starts: the clock only begins when START is pressed.
  Widget _startView(QuizTake quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(quiz),
        const SizedBox(height: 10),
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timed: ${quiz.timeLimitMinutes} minutes',
                style: AppText.serif(size: 16, color: AppColors.title),
              ),
              const SizedBox(height: 6),
              Text(
                'The timer starts when you press START and cannot be paused. '
                'When time runs out, your answers are submitted automatically.',
                style: AppText.sans(size: 12, color: Colors.black87),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
                ),
              const SizedBox(height: 12),
              primaryButton(
                label: 'START',
                loading: _starting,
                onPressed: () => _start(quiz),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timerBar() {
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final low = _secondsLeft <= 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Time left: $minutes:$seconds',
          style: AppText.sans(
            size: 13,
            color: low ? const Color(0xFFB3261E) : AppColors.darkBrown,
          ),
        ),
      ),
    );
  }

  Widget _questionCard(int i, QuizQuestion q, {bool blockPaste = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION ${i + 1} · ${q.points} point${q.points == 1 ? '' : 's'}',
              style: AppText.sans(size: 10.5, color: AppColors.label),
            ),
            const SizedBox(height: 6),
            Text(q.text, style: AppText.sans(size: 13, color: Colors.black87)),
            const SizedBox(height: 10),
            if (q.isChoice)
              for (var j = 0; j < q.choices.length; j++) _choiceTile(q, j)
            else
              _writtenField(q, blockPaste),
          ],
        ),
      ),
    );
  }

  /// The box for a written answer. With [blockPaste] it refuses pasting (best effort).
  Widget _writtenField(QuizQuestion q, bool blockPaste) {
    if (!blockPaste) {
      return inputField(_textFor(q.id), 'Type your answer', minLines: 3, maxLines: 8);
    }
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        final keys = HardwareKeyboard.instance;
        final paste = (keys.isControlPressed || keys.isMetaPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyV;
        final shiftInsert = keys.isShiftPressed && event.logicalKey == LogicalKeyboardKey.insert;
        return (paste || shiftInsert) ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: TextField(
        controller: _textFor(q.id),
        minLines: 3,
        maxLines: 8,
        style: AppText.sans(size: 12, color: AppColors.darkBrown),
        decoration: fieldDecoration('Type your answer'),
        contextMenuBuilder: (context, state) => const SizedBox.shrink(),
        inputFormatters: [NoPasteFormatter()],
      ),
    );
  }

  Widget _choiceTile(QuizQuestion q, int j) {
    final selected = _choices[q.id] == j;
    return InkWell(
      onTap: () => setState(() => _choices[q.id] = j),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: AppColors.sidebar,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(q.choices[j], style: AppText.sans(size: 12, color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  // ----- result -----

  Widget _resultView(QuizTake quiz, QuizResult r) {
    final graded = r.status == 'graded';
    final left = r.attemptsAllowed - r.attemptsUsed;
    final canRetry = left > 0 && quiz.state == 'open';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(quiz),
        const SizedBox(height: 10),
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRY ${r.attempt} OF ${r.attemptsAllowed}',
                style: AppText.sans(size: 10.5, color: AppColors.label),
              ),
              const SizedBox(height: 6),
              if (graded)
                Text('${r.score} / ${r.totalPoints}',
                    style: AppText.serif(size: 28, color: AppColors.title))
              else ...[
                Text('Submitted', style: AppText.serif(size: 22, color: AppColors.title)),
                const SizedBox(height: 4),
                Text(
                  'Your instructor still has to grade the written answers. Points so far: ${r.score}.',
                  style: AppText.sans(size: 11.5, color: Colors.black87),
                ),
              ],
              if (r.attemptsAllowed > 1) ...[
                const SizedBox(height: 6),
                Text('Your score for this quiz is your highest graded try.',
                    style: AppText.sans(size: 10.5, color: Colors.black54)),
              ],
              if (r.attempts.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in r.attempts)
                      ChoiceChip(
                        label: Text(
                          'Try ${a.attempt}: ${a.status == 'graded' ? '${a.score}/${r.totalPoints}' : 'pending'}',
                          style: AppText.sans(size: 11, color: Colors.black87),
                        ),
                        selected: a.attempt == r.attempt,
                        backgroundColor: AppColors.cardCream,
                        selectedColor: AppColors.cardBorder,
                        onSelected: (_) => _viewAttempt(a.attempt),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (!r.revealed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'The correct answers are shown after your last try.',
              style: AppText.sans(size: 11, color: Colors.black54),
            ),
          ),
        for (var i = 0; i < r.answers.length; i++) _reviewCard(i, r.answers[i], r.revealed),
        const SizedBox(height: 4),
        if (canRetry)
          Align(
            alignment: Alignment.centerLeft,
            child: primaryButton(
              label: 'TRY AGAIN ($left LEFT)',
              onPressed: _retry,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _reviewCard(int i, AnswerReview a, bool revealed) {
    final lines = <Widget>[];

    if (a.isChoice) {
      final picked = a.yourChoiceIndex == null ? 'No answer' : a.choices[a.yourChoiceIndex!];
      lines.add(Text('Your answer: $picked', style: AppText.sans(size: 12, color: Colors.black87)));
      if (revealed) {
        final right = a.yourChoiceIndex != null && a.yourChoiceIndex == a.correctIndex;
        lines.add(Text(
          right ? 'Correct' : 'Incorrect',
          style: AppText.sans(
            size: 11.5,
            color: right ? const Color(0xFF2E7D32) : const Color(0xFFB3261E),
            weight: FontWeight.w600,
          ),
        ));
        if (!right && a.correctIndex != null) {
          lines.add(Text('Correct answer: ${a.choices[a.correctIndex!]}',
              style: AppText.sans(size: 12, color: Colors.black87)));
        }
        lines.add(Text('${a.awarded ?? 0}/${a.points} points',
            style: AppText.sans(size: 11, color: AppColors.orange)));
      }
    } else {
      lines.add(Text('Your answer:', style: AppText.sans(size: 11, color: AppColors.label)));
      lines.add(Text(a.yourText.isEmpty ? 'No answer' : a.yourText,
          style: AppText.sans(size: 12, color: Colors.black87)));
      lines.add(Text(
        a.awarded == null ? 'Waiting for grading' : '${a.awarded}/${a.points} points',
        style: AppText.sans(size: 11, color: AppColors.orange),
      ));
      if (a.feedback.isNotEmpty) {
        lines.add(Text('Instructor feedback: ${a.feedback}',
            style: AppText.sans(size: 11.5, color: Colors.black87)));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION ${i + 1} · ${a.points} point${a.points == 1 ? '' : 's'}',
              style: AppText.sans(size: 10.5, color: AppColors.label),
            ),
            const SizedBox(height: 6),
            Text(a.text, style: AppText.sans(size: 13, color: Colors.black87)),
            for (final line in lines) Padding(padding: const EdgeInsets.only(top: 6), child: line),
          ],
        ),
      ),
    );
  }
}