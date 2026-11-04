import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// The QUIZ page: every quiz, activity, minitask and task performance the person can open.
class QuizzesPage extends StatefulWidget {
  const QuizzesPage({super.key});

  @override
  State<QuizzesPage> createState() => _QuizzesPageState();
}

class _QuizzesPageState extends State<QuizzesPage> {
  late Future<List<QuizListItem>> _future = DashboardApi.quizzes();

  bool get _staff => Session.role == 'instructor' || Session.role == 'admin';

  void _reload() => setState(() => _future = DashboardApi.quizzes());

  void _open(QuizListItem q) {
    final route = _staff ? '/quiz-review/${q.id}' : '/quiz/${q.id}';
    Navigator.pushNamed(context, route).then((_) {
      if (mounted) _reload();
    });
  }

  List<(String, List<QuizListItem>)> _groups(List<QuizListItem> items) {
    final far = DateTime(9999);
    final past = DateTime(1970);

    List<QuizListItem> pick(bool Function(QuizListItem) test, int Function(QuizListItem, QuizListItem) order) =>
        items.where(test).toList()..sort(order);

    int soonestDue(QuizListItem a, QuizListItem b) => (a.dueAt ?? far).compareTo(b.dueAt ?? far);
    int soonestOpen(QuizListItem a, QuizListItem b) => (a.opensAt ?? far).compareTo(b.opensAt ?? far);
    int latestDue(QuizListItem a, QuizListItem b) => (b.dueAt ?? past).compareTo(a.dueAt ?? past);

    if (_staff) {
      return [
        ('TO GRADE', pick((q) => q.needsGrading > 0, (a, b) => b.needsGrading.compareTo(a.needsGrading))),
        ('OPEN NOW', pick((q) => q.needsGrading == 0 && q.state == 'open', soonestDue)),
        ('UPCOMING', pick((q) => q.needsGrading == 0 && q.state == 'upcoming', soonestOpen)),
        ('DRAFTS', pick((q) => q.needsGrading == 0 && q.state == 'draft', soonestDue)),
        ('CLOSED', pick((q) => q.needsGrading == 0 && q.state == 'closed', latestDue)),
      ];
    }
    return [
      ('OPEN NOW', pick((q) => q.state == 'open', soonestDue)),
      ('UPCOMING', pick((q) => q.state == 'upcoming', soonestOpen)),
      ('CLOSED', pick((q) => q.state == 'closed', latestDue)),
    ];
  }

  String _statusLine(QuizListItem q) {
    if (_staff) {
      if (q.state == 'draft') return 'Draft (not published)';
      final count = '${q.submissionCount} ${q.submissionCount == 1 ? 'student' : 'students'} submitted';
      return q.needsGrading > 0 ? '$count · ${q.needsGrading} to grade' : count;
    }
    switch (q.state) {
      case 'upcoming':
        return q.opensAt == null ? 'Opens soon' : 'Opens ${formatWhen(q.opensAt!)}';
      case 'closed':
        final closed = q.dueAt == null ? 'Closed' : 'Closed ${formatWhen(q.dueAt!)}';
        return '$closed · Tries used: ${q.attemptsUsed} of ${q.maxAttempts}';
      default:
        final due = q.dueAt == null ? 'No deadline' : 'Due ${formatWhen(q.dueAt!)}';
        return '$due · Tries used: ${q.attemptsUsed} of ${q.maxAttempts}';
    }
  }

  String _badge(QuizListItem q) {
    if (_staff) return '';
    if (q.bestScore != null) return '${q.bestScore}/${q.totalPoints}';
    if (q.waiting > 0) return 'Waiting';
    return '';
  }

  Widget _row(QuizListItem q) {
    final badge = _badge(q);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _open(q),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.title, style: AppText.sans(size: 13, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                        '${q.courseTitle} · ${kindLabel(q.kind)}',
                        style: AppText.sans(size: 10.5, color: Colors.black54),
                      ),
                      Text(
                        _statusLine(q),
                        style: AppText.sans(size: 10.5, color: AppColors.orange),
                      ),
                    ],
                  ),
                ),
                if (badge.isNotEmpty)
                  Text(badge, style: AppText.serif(size: 16, color: AppColors.title)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'quizzes',
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pageTitle('QUIZZES'),
            const SizedBox(height: 6),
            Text(
              _staff
                  ? 'Everything in your courses. Create new work from the course page.'
                  : 'All the quizzes and activities of your courses.',
              style: AppText.sans(size: 11, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<QuizListItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const LoadingBox();
                if (snapshot.hasError) {
                  return CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Text(
                    _staff
                        ? 'No quizzes in your courses yet.'
                        : 'No quizzes or activities have been published in your courses yet.',
                    style: AppText.sans(size: 11, color: Colors.black54),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (label, list) in _groups(items))
                      if (list.isNotEmpty) ...[
                        fieldLabel(label),
                        for (final q in list) _row(q),
                        const SizedBox(height: 12),
                      ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}