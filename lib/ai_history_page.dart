import 'package:flutter/material.dart';

import 'ai_chat_page.dart';
import 'api_service.dart';
import 'app_shell.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// The History tab (students): saved AI practice results.
class AiHistoryPage extends StatefulWidget {
  const AiHistoryPage({super.key});

  @override
  State<AiHistoryPage> createState() => _AiHistoryPageState();
}

class _AiHistoryPageState extends State<AiHistoryPage> {
  Future<List<PracticeSummary>>? _future;

  bool get _isStudent => Session.role == 'student';

  @override
  void initState() {
    super.initState();
    if (_isStudent) _future = AiApi.practiceHistory();
  }

  void _reload() => setState(() => _future = AiApi.practiceHistory());

  Future<void> _delete(PracticeSummary p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete result',
      message: 'Delete your practice result for "${p.moduleTitle}"?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await AiApi.deletePractice(p.id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  Widget _row(PracticeSummary p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/ai-practice/${p.id}').then((_) {
            if (mounted) _reload();
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.moduleTitle, style: AppText.sans(size: 13, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                        '${p.courseTitle}${p.finishedAt == null ? '' : ' · ${formatWhen(p.finishedAt!)}'}',
                        style: AppText.sans(size: 10.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text('${p.score}/${p.total}', style: AppText.serif(size: 16, color: AppColors.title)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(p),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.black45),
                ),
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
      selected: 'ai',
      body: PageBody(
        child: !_isStudent
            ? const CenteredMessage('The AI page is for students.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pageTitle('AI STUDY HELPER'),
                  const SizedBox(height: 8),
                  const AiTabs(current: 'history'),
                  const SizedBox(height: 10),
                  Text(
                    'Your practice results are saved here. Only you can see them. '
                    'The newest 60 are kept.',
                    style: AppText.sans(size: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<PracticeSummary>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LoadingBox();
                      }
                      if (snapshot.hasError) {
                        return CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return const CenteredMessage(
                          'No practice results yet. Finish a practice quiz and it will appear here.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final p in items) _row(p)],
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/// One saved practice result with every question and the student's picks.
class AiPracticeDetailPage extends StatefulWidget {
  const AiPracticeDetailPage({super.key, required this.id});

  final String id;

  @override
  State<AiPracticeDetailPage> createState() => _AiPracticeDetailPageState();
}

class _AiPracticeDetailPageState extends State<AiPracticeDetailPage> {
  late final Future<PracticeDetail> _future = AiApi.practiceDetail(widget.id);
  bool _wrongOnly = false;

  Widget _choiceTile(PracticeAnswerRow r, int j) {
    final picked = r.pickedIndex == j;
    var icon = picked ? Icons.radio_button_checked : Icons.radio_button_unchecked;
    var color = AppColors.sidebar;
    if (j == r.correctIndex) {
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF2E7D32);
    } else if (picked) {
      icon = Icons.cancel_rounded;
      color = const Color(0xFFB3261E);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r.choices[j], style: AppText.sans(size: 12, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(int number, PracticeAnswerRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION $number · ${r.isCorrect ? 'CORRECT' : (r.pickedIndex == null ? 'NOT ANSWERED' : 'WRONG')}',
              style: AppText.sans(
                size: 10.5,
                color: r.isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFB3261E),
              ),
            ),
            const SizedBox(height: 6),
            Text(r.text, style: AppText.sans(size: 13, color: Colors.black87)),
            const SizedBox(height: 8),
            for (var j = 0; j < r.choices.length; j++) _choiceTile(r, j),
            if (r.explanation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Why: ${r.explanation}',
                    style: AppText.sans(size: 11, color: Colors.black54)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'ai',
      body: PageBody(
        child: FutureBuilder<PracticeDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const LoadingBox();
            if (snapshot.hasError) return CenteredMessage(errorText(snapshot.error!));
            final d = snapshot.data!;
            final shown = <Widget>[];
            for (var i = 0; i < d.rows.length; i++) {
              if (_wrongOnly && d.rows[i].isCorrect) continue;
              shown.add(_questionCard(i + 1, d.rows[i]));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.label),
                    label: Text('HISTORY', style: AppText.sans(size: 11, color: AppColors.label)),
                  ),
                ),
                CardBox(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Practice: ${d.moduleTitle}',
                          style: AppText.serif(size: 20, color: AppColors.title)),
                      const SizedBox(height: 4),
                      Text(
                        '${d.courseTitle}${d.finishedAt == null ? '' : ' · ${formatWhen(d.finishedAt!)}'}',
                        style: AppText.sans(size: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Text('Score: ${d.score} of ${d.total}',
                          style: AppText.sans(size: 12, color: AppColors.orange)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _wrongOnly,
                        onChanged: (v) => setState(() => _wrongOnly = v),
                        title: Text('Show wrong answers only',
                            style: AppText.sans(size: 12, color: AppColors.darkBrown)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  const CenteredMessage('No wrong answers here. Great job!')
                else
                  ...shown,
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}