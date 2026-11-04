import 'package:flutter/material.dart';

import 'ai_chat_page.dart';
import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// The AI page (students): practice quizzes made from a module. Nothing is saved.
class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  late final Future<List<Course>> _coursesFuture;

  String? _courseId;
  List<ModuleItem> _modules = [];
  String? _moduleId;
  int _count = 5;
  bool _loadingModules = false;
  bool _generating = false;
  String? _error;

  PracticeQuiz? _quiz;
  final Map<int, int> _picked = {}; // question number -> chosen choice
  bool _checked = false;
  bool _saved = false; // the result reached the server
  String? _saveError;

  bool get _isStudent => Session.role == 'student';

  @override
  void initState() {
    super.initState();
    _coursesFuture = ApiService.courses();
    // pick the first course so the module list fills in
    _coursesFuture.then((list) {
      if (mounted && list.isNotEmpty) _pickCourse(list.first.id);
    }, onError: (_) {});
  }

  Future<void> _pickCourse(String id) async {
    setState(() {
      _courseId = id;
      _modules = [];
      _moduleId = null;
      _loadingModules = true;
      _error = null;
    });
    try {
      final modules = await ApiService.courseModules(id);
      if (!mounted || _courseId != id) return;
      setState(() {
        _modules = modules;
        _moduleId = modules.isEmpty ? null : modules.first.id;
        _loadingModules = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loadingModules = false;
      });
    }
  }

  Future<void> _generate() async {
    final id = _moduleId;
    if (id == null) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final quiz = await AiApi.practiceQuiz(id, count: _count);
      if (!mounted) return;
      setState(() {
        _quiz = quiz;
        _picked.clear();
        _checked = false;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _generating = false;
      });
    }
  }

  Future<void> _check(PracticeQuiz quiz) async {
    final unanswered = quiz.questions.length - _picked.length;
    if (unanswered > 0) {
      final ok = await confirmDialog(
        context,
        title: 'Check answers',
        message: 'You left $unanswered question${unanswered == 1 ? '' : 's'} unanswered. Check anyway?',
        confirmLabel: 'Check',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _checked = true;
      _saved = false;
      _saveError = null;
    });
    // save the picks; the server works out the score
    try {
      await AiApi.finishPractice(
        quiz.id,
        [for (var i = 0; i < quiz.questions.length; i++) _picked[i]],
      );
      if (!mounted) return;
      setState(() => _saved = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = errorText(e));
    }
  }

  int _score(PracticeQuiz quiz) {
    var n = 0;
    for (var i = 0; i < quiz.questions.length; i++) {
      if (_picked[i] == quiz.questions[i].correctIndex) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'ai',
      body: PageBody(
        child: !_isStudent
            ? const CenteredMessage('The AI page is for students.')
            : (_quiz == null ? _setupView() : _quizView(_quiz!)),
      ),
    );
  }

  // ----- choose what to practice -----

  Widget _setupView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pageTitle('AI STUDY HELPER'),
        const SizedBox(height: 8),
        const AiTabs(current: 'practice'),
        const SizedBox(height: 10),
        Text(
          'Practice questions made by AI from your module handouts. Nothing here is graded or '
          'saved, and AI can make mistakes, so check your handout.',
          style: AppText.sans(size: 11, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Course>>(
          future: _coursesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const LoadingBox();
            if (snapshot.hasError) return CenteredMessage(errorText(snapshot.error!));
            final courses = snapshot.data ?? [];
            if (courses.isEmpty) {
              return const CenteredMessage('You are not enrolled in any course yet.');
            }
            return _setupCard(courses);
          },
        ),
      ],
    );
  }

  Widget _setupCard(List<Course> courses) {
    return CardBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel('COURSE'),
          SelectBox<String>(
            value: _courseId ?? courses.first.id,
            items: [for (final c in courses) DropdownMenuItem(value: c.id, child: Text(c.title))],
            onChanged: _pickCourse,
          ),
          fieldLabel('MODULE'),
          if (_loadingModules)
            Text('Loading modules...', style: AppText.sans(size: 11, color: Colors.black54))
          else if (_modules.isEmpty)
            Text('This course has no modules yet.',
                style: AppText.sans(size: 11, color: Colors.black54))
          else
            SelectBox<String>(
              value: _moduleId ?? _modules.first.id,
              items: [
                for (final m in _modules) DropdownMenuItem(value: m.id, child: Text(m.title)),
              ],
              onChanged: (v) => setState(() => _moduleId = v),
            ),
          fieldLabel('NUMBER OF QUESTIONS'),
          SizedBox(
            width: 180,
            child: SelectBox<int>(
              value: _count,
              items: [for (final n in [3, 5, 8, 10]) DropdownMenuItem(value: n, child: Text('$n questions'))],
              onChanged: (v) => setState(() => _count = v),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
            ),
          if (_generating)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Generating... this can take up to a minute.',
                  style: AppText.sans(size: 11, color: Colors.black54)),
            ),
          const SizedBox(height: 14),
          primaryButton(
            label: 'GENERATE',
            loading: _generating,
            onPressed: _moduleId == null ? null : _generate,
          ),
        ],
      ),
    );
  }

  // ----- answering and checking -----

  Widget _quizView(PracticeQuiz quiz) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _quiz = null;
              _error = null;
            }),
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.label),
            label: Text('CHANGE MODULE', style: AppText.sans(size: 11, color: AppColors.label)),
          ),
        ),
        const SizedBox(height: 6),
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Practice: ${quiz.moduleTitle}',
                  style: AppText.serif(size: 20, color: AppColors.title)),
              const SizedBox(height: 6),
              Text('Made by AI · not graded · not saved · may contain mistakes',
                  style: AppText.sans(size: 11, color: AppColors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < quiz.questions.length; i++) _questionCard(i, quiz.questions[i]),
        if (_checked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardBox(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You got ${_score(quiz)} of ${quiz.questions.length} correct.',
                    style: AppText.serif(size: 16, color: AppColors.title),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _saveError != null
                        ? 'Could not save this result: $_saveError'
                        : (_saved ? 'Saved to your History tab.' : 'Saving...'),
                    style: AppText.sans(
                      size: 11,
                      color: _saveError != null ? const Color(0xFFB3261E) : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: _checked
              ? primaryButton(label: 'NEW QUIZ', loading: _generating, onPressed: _generate)
              : primaryButton(label: 'CHECK ANSWERS', onPressed: () => _check(quiz)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _questionCard(int i, PracticeQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QUESTION ${i + 1}', style: AppText.sans(size: 10.5, color: AppColors.label)),
            const SizedBox(height: 6),
            Text(q.text, style: AppText.sans(size: 13, color: Colors.black87)),
            const SizedBox(height: 10),
            for (var j = 0; j < q.choices.length; j++) _choiceTile(i, q, j),
            if (_checked && q.explanation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Why: ${q.explanation}',
                    style: AppText.sans(size: 11, color: Colors.black54)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceTile(int i, PracticeQuestion q, int j) {
    final picked = _picked[i] == j;
    var icon = picked ? Icons.radio_button_checked : Icons.radio_button_unchecked;
    var color = AppColors.sidebar;
    if (_checked) {
      if (j == q.correctIndex) {
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF2E7D32);
      } else if (picked) {
        icon = Icons.cancel_rounded;
        color = const Color(0xFFB3261E);
      }
    }
    return InkWell(
      onTap: _checked ? null : () => setState(() => _picked[i] = j),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(q.choices[j], style: AppText.sans(size: 12, color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }
}