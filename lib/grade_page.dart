import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

class GradePage extends StatefulWidget {
  const GradePage({super.key, required this.quizId, required this.submissionId});

  final String quizId;
  final String submissionId;

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  GradeDetail? _detail;
  String? _loadError;
  bool _saving = false;
  String? _error;
  final Map<String, TextEditingController> _points = {}; // question id -> points box
  final Map<String, TextEditingController> _feedback = {}; // question id -> feedback box

  bool get _isStaff => Session.role == 'instructor' || Session.role == 'admin';

  @override
  void initState() {
    super.initState();
    if (_isStaff) _load();
  }

  @override
  void dispose() {
    for (final c in _points.values) {
      c.dispose();
    }
    for (final c in _feedback.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final detail = await GradingApi.detail(widget.quizId, widget.submissionId);
      if (!mounted) return;
      for (final a in detail.answers) {
        if (a.isChoice) continue;
        _points.putIfAbsent(
            a.questionId, () => TextEditingController(text: a.awarded?.toString() ?? ''));
        _feedback.putIfAbsent(a.questionId, () => TextEditingController(text: a.feedback));
      }
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = errorText(e));
    }
  }

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null) return;

    final grades = <Map<String, dynamic>>[];
    for (final a in detail.answers) {
      if (a.isChoice) continue;
      final raw = _points[a.questionId]!.text.trim();
      int? points;
      if (raw.isNotEmpty) {
        points = int.tryParse(raw);
        if (points == null || points < 0 || points > a.points) {
          setState(() => _error = 'Points must be a whole number from 0 to ${a.points}.');
          return;
        }
      }
      grades.add({
        'questionId': a.questionId,
        'points': points,
        'feedback': _feedback[a.questionId]!.text.trim(),
      });
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await GradingApi.save(widget.quizId, widget.submissionId, grades);
      if (!mounted) return;
      final left = saved.answers.where((a) => !a.isChoice && a.awarded == null).length;
      setState(() {
        _detail = saved;
        _saving = false;
      });
      showSnack(
        context,
        left == 0
            ? 'Saved. This try is fully graded.'
            : 'Saved. $left written answer${left == 1 ? '' : 's'} still need points.',
      );
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
          child: CenteredMessage('Only instructors and admins can grade submissions.'),
        ),
      );
    }

    Widget content;
    final detail = _detail;
    if (_loadError != null) {
      content = CenteredMessage(_loadError!, onRetry: _load);
    } else if (detail == null) {
      content = const LoadingBox();
    } else {
      content = _content(detail);
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
                onPressed: () => goBack(context, '/quiz-review/${widget.quizId}'),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.label),
                label: Text('SUBMISSIONS', style: AppText.sans(size: 11, color: AppColors.label)),
              ),
            ),
            const SizedBox(height: 6),
            content,
          ],
        ),
      ),
    );
  }

  Widget _content(GradeDetail d) {
    final graded = d.status == 'graded';
    final hasWritten = d.answers.any((a) => !a.isChoice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.studentName, style: AppText.serif(size: 20, color: AppColors.title)),
              Text(d.studentEmail, style: AppText.sans(size: 11, color: Colors.black54)),
              const SizedBox(height: 8),
              Text(
                '${d.title} · Try ${d.attempt}'
                '${d.submittedAt == null ? '' : ' · Submitted ${formatWhen(d.submittedAt!)}'}',
                style: AppText.sans(size: 11, color: AppColors.label),
              ),
              const SizedBox(height: 6),
              Text('${d.score} / ${d.totalPoints}',
                  style: AppText.serif(size: 26, color: AppColors.title)),
              Text(
                graded ? 'Fully graded' : 'Some written answers still need points',
                style: AppText.sans(size: 11, color: AppColors.orange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < d.answers.length; i++) _answerCard(i, d.answers[i]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
          ),
        if (hasWritten)
          Align(
            alignment: Alignment.centerLeft,
            child: primaryButton(label: 'SAVE GRADES', loading: _saving, onPressed: _save),
          )
        else
          Text('Everything here was multiple choice, so it was graded automatically.',
              style: AppText.sans(size: 11, color: Colors.black54)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _answerCard(int i, GradeAnswer a) {
    final children = <Widget>[
      Text(
        'QUESTION ${i + 1} · ${a.points} point${a.points == 1 ? '' : 's'}',
        style: AppText.sans(size: 10.5, color: AppColors.label),
      ),
      const SizedBox(height: 6),
      Text(a.text, style: AppText.sans(size: 13, color: Colors.black87)),
      const SizedBox(height: 10),
    ];

    if (a.isChoice) {
      final picked = a.yourChoiceIndex == null ? 'No answer' : a.choices[a.yourChoiceIndex!];
      final right = a.yourChoiceIndex != null && a.yourChoiceIndex == a.correctIndex;
      children.addAll([
        Text('Student answered: $picked', style: AppText.sans(size: 12, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(
          right ? 'Correct (automatic)' : 'Incorrect (automatic)',
          style: AppText.sans(
            size: 11.5,
            color: right ? const Color(0xFF2E7D32) : const Color(0xFFB3261E),
            weight: FontWeight.w600,
          ),
        ),
        if (!right && a.correctIndex != null)
          Text('Correct answer: ${a.choices[a.correctIndex!]}',
              style: AppText.sans(size: 12, color: Colors.black87)),
        Text('${a.awarded ?? 0}/${a.points} points',
            style: AppText.sans(size: 11, color: AppColors.orange)),
      ]);
    } else {
      children.addAll([
        Text("STUDENT'S ANSWER", style: AppText.sans(size: 10, color: AppColors.label)),
        const SizedBox(height: 4),
        SelectableText(
          a.yourText.trim().isEmpty ? 'No answer' : a.yourText,
          style: AppText.sans(size: 12.5, color: Colors.black87).copyWith(height: 1.4),
        ),
        fieldLabel('POINTS (0 TO ${a.points})'),
        SizedBox(width: 120, child: inputField(_points[a.questionId]!, '0 to ${a.points}')),
        fieldLabel('FEEDBACK FOR THE STUDENT (OPTIONAL)'),
        inputField(_feedback[a.questionId]!, 'Write a comment', minLines: 2, maxLines: 5),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}