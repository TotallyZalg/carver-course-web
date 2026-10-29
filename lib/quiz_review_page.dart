import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

class QuizReviewPage extends StatefulWidget {
  const QuizReviewPage({super.key, required this.quizId});

  final String quizId;

  @override
  State<QuizReviewPage> createState() => _QuizReviewPageState();
}

class _QuizReviewPageState extends State<QuizReviewPage> {
  Future<SubmissionsOverview>? _future;

  bool get _isStaff => Session.role == 'instructor' || Session.role == 'admin';

  @override
  void initState() {
    super.initState();
    if (_isStaff) _future = GradingApi.overview(widget.quizId);
  }

  void _reload() {
    setState(() {
      _future = GradingApi.overview(widget.quizId);
    });
  }

  Future<void> _open(AttemptRow attempt) async {
    await Navigator.pushNamed(context, '/grade/${widget.quizId}/${attempt.submissionId}');
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStaff) {
      return const AppShell(
        selected: 'courses',
        body: PageBody(
          child: CenteredMessage('Only instructors and admins can review submissions.'),
        ),
      );
    }
    return AppShell(
      selected: 'courses',
      body: PageBody(
        child: FutureBuilder<SubmissionsOverview>(
          future: _future,
          builder: (context, snapshot) {
            final done = snapshot.connectionState == ConnectionState.done;
            final overview = done && !snapshot.hasError ? snapshot.data : null;
            final fallback = overview != null && overview.courseId.isNotEmpty
                ? '/course/${overview.courseId}'
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

  Widget _content(SubmissionsOverview o) {
    final submitted = o.students.where((s) => s.attemptsUsed > 0).length;
    final waiting = o.students.fold<int>(0, (sum, s) => sum + s.needsGrading);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(o.title, style: AppText.serif(size: 22, color: AppColors.title)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.sidebar,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(kindLabel(o.kind).toUpperCase(),
                        style: AppText.sans(size: 8.5, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$submitted of ${o.students.length} student${o.students.length == 1 ? '' : 's'} submitted · ${o.totalPoints} points · ${o.maxAttempts} ${o.maxAttempts == 1 ? 'try' : 'tries'} allowed',
                style: AppText.sans(size: 11, color: AppColors.label),
              ),
              if (waiting > 0)
                Text(
                  '$waiting ${waiting == 1 ? 'try needs' : 'tries need'} grading',
                  style: AppText.sans(size: 11, color: AppColors.orange),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (o.students.isEmpty)
          const CenteredMessage('No students are enrolled in this course yet.')
        else
          for (final s in o.students)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _studentCard(o, s)),
      ],
    );
  }

  Widget _studentCard(SubmissionsOverview o, StudentSubmissions s) {
    String summary;
    if (s.attemptsUsed == 0) {
      summary = 'Not submitted';
    } else if (s.bestScore != null) {
      summary = 'Best ${s.bestScore}/${o.totalPoints}';
    } else {
      summary = 'Waiting for grading';
    }

    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: AppText.sans(
                            size: 13, color: Colors.black87, weight: FontWeight.w600)),
                    Text(s.email, style: AppText.sans(size: 10.5, color: Colors.black54)),
                  ],
                ),
              ),
              Text(
                summary,
                style: AppText.sans(
                  size: 11,
                  color: s.attemptsUsed == 0 ? Colors.black45 : AppColors.label,
                ),
              ),
            ],
          ),
          if (s.attempts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in s.attempts) _attemptButton(o, a)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _attemptButton(SubmissionsOverview o, AttemptRow a) {
    final graded = a.status == 'graded';
    final label = graded
        ? 'Try ${a.attempt} · ${a.score}/${o.totalPoints}'
        : 'Try ${a.attempt} · needs grading';

    if (graded) {
      return OutlinedButton(
        onPressed: () => _open(a),
        child: Text(label, style: AppText.sans(size: 11, color: AppColors.label)),
      );
    }
    return FilledButton(
      onPressed: () => _open(a),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkBrown,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: AppText.sans(size: 11, color: Colors.white)),
    );
  }
}