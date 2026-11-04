import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(selected: 'home', body: _MainArea());
  }
}

class _MainArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF3E2), Color(0xFFF1E3CC), Color(0xFFE6D2C4)],
        ),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, c) {
                  final narrow = c.maxWidth < 700;
                  final cards = [
                    const _NewsCard(),
                    const _TasksCard(),
                    const _MasteryCard(),
                  ];
                  if (narrow) {
                    return Column(
                      children: [
                        for (final w in cards)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: w)
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[2]),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                const _AiOverview(),
              ],
            ),
          ),
          const Positioned(
            right: 14,
            bottom: 14,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFF2B2B2B),
              child: Text('?', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

const _newsTags = ['NEW', 'EVENT', 'UPDATE'];

const _newsMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _newsDay(DateTime d) => '${_newsMonths[d.month - 1]} ${d.day}, ${d.year}';

class _NewsCard extends StatefulWidget {
  const _NewsCard();

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  late Future<List<NewsItem>> _future = NewsApi.list();

  bool get _isAdmin => Session.role == 'admin';

  void _reload() => setState(() => _future = NewsApi.list());

  Future<void> _post() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _PostNewsDialog(),
    );
    if (result == null) return;
    try {
      await NewsApi.create(tag: result['tag']!, title: result['title']!);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  Future<void> _delete(NewsItem n) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete news',
      message: 'Delete "${n.title}"?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await NewsApi.delete(n.id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  Widget _row(NewsItem n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(5)),
            child: Text(n.tag, style: AppText.sans(size: 8, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: AppText.sans(size: 9.5, color: Colors.black87)),
                if (n.createdAt != null)
                  Text(_newsDay(n.createdAt!),
                      style: AppText.sans(size: 7.5, color: AppColors.orange)),
              ],
            ),
          ),
          if (_isAdmin)
            InkWell(
              onTap: () => _delete(n),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('NEWS', style: AppText.sans(size: 11, color: Colors.black87)),
              const Spacer(),
              if (_isAdmin)
                TextButton(
                  onPressed: _post,
                  child: Text('+ POST', style: AppText.sans(size: 9.5, color: AppColors.label)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: FutureBuilder<List<NewsItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Text('Loading...',
                        style: AppText.sans(size: 9.5, color: Colors.black54));
                  }
                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(errorText(snapshot.error!),
                            style: AppText.sans(size: 9.5, color: const Color(0xFFB3261E))),
                        TextButton(
                          onPressed: _reload,
                          child: Text('Try again',
                              style: AppText.sans(size: 9.5, color: AppColors.label)),
                        ),
                      ],
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Text(
                      _isAdmin ? 'No news yet. Press + POST to add one.' : 'No news yet.',
                      style: AppText.sans(size: 9.5, color: Colors.black54),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final n in items) _row(n)],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin dialog: pick a type and write a title. Returns {'tag': ..., 'title': ...} on POST.
class _PostNewsDialog extends StatefulWidget {
  const _PostNewsDialog();

  @override
  State<_PostNewsDialog> createState() => _PostNewsDialogState();
}

class _PostNewsDialogState extends State<_PostNewsDialog> {
  final _title = TextEditingController();
  String _tag = 'NEW';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text('Post news', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel('TYPE'),
            SelectBox<String>(
              value: _tag,
              items: [for (final t in _newsTags) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _tag = v),
            ),
            fieldLabel('TITLE'),
            inputField(_title, 'e.g. Midterm schedule posted'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        primaryButton(
          label: 'POST',
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, {'tag': _tag, 'title': title});
          },
        ),
      ],
    );
  }
}

class _TasksCard extends StatefulWidget {
  const _TasksCard();

  @override
  State<_TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<_TasksCard> {
  late Future<List<DashboardTask>> _future = DashboardApi.tasks();

  bool get _staff => Session.role == 'instructor' || Session.role == 'admin';

  void _reload() => setState(() => _future = DashboardApi.tasks());

  void _open(DashboardTask t) {
    final route = _staff ? '/quiz-review/${t.id}' : '/quiz/${t.id}';
    Navigator.pushNamed(context, route).then((_) {
      if (mounted) _reload();
    });
  }

  Widget _row(DashboardTask t) {
    final due = t.dueAt == null ? 'No deadline' : 'Due ${formatWhen(t.dueAt!)}';
    return InkWell(
      onTap: () => _open(t),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 11,
              height: 11,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                  color: AppColors.taskSquare, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: AppText.sans(size: 9.5, color: Colors.black87)),
                  Text(
                    '${t.courseTitle} · ${kindLabel(t.kind)} · ${t.detail}',
                    style: AppText.sans(size: 7.5, color: Colors.black54),
                  ),
                  Text(due, style: AppText.sans(size: 7.5, color: AppColors.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_staff ? 'TO GRADE' : 'TASKS', style: AppText.sans(size: 11, color: Colors.black87)),
          const SizedBox(height: 8),
          FutureBuilder<List<DashboardTask>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Text('Loading...', style: AppText.sans(size: 9.5, color: Colors.black54));
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(errorText(snapshot.error!),
                        style: AppText.sans(size: 9.5, color: const Color(0xFFB3261E))),
                    TextButton(
                      onPressed: _reload,
                      child: Text('Try again', style: AppText.sans(size: 9.5, color: AppColors.label)),
                    ),
                  ],
                );
              }
              final tasks = snapshot.data ?? [];
              if (tasks.isEmpty) {
                return Text(
                  _staff ? 'Nothing is waiting to be graded.' : 'No open work right now.',
                  style: AppText.sans(size: 9.5, color: Colors.black54),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final t in tasks) _row(t)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Center(
        child: Text(
          '',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 11, color: Colors.black87),
        ),
      ),
    );
  }
}

class _AiOverview extends StatefulWidget {
  const _AiOverview();

  @override
  State<_AiOverview> createState() => _AiOverviewState();
}

class _AiOverviewState extends State<_AiOverview> {
  late final Future<DashboardOverview> _future = DashboardApi.overview();

  TextStyle get _highlight => TextStyle(color: AppColors.orange);

  List<InlineSpan> _spans(DashboardOverview o) {
    if (o.role == 'student') {
      if (o.total == 0) {
        return const [TextSpan(text: 'No quizzes or activities are published in your courses yet.')];
      }
      final spans = <InlineSpan>[
        const TextSpan(text: "You've completed "),
        TextSpan(text: '${o.done} of ${o.total}', style: _highlight),
        const TextSpan(text: ' quizzes and activities'),
      ];
      if (o.averagePercent != null) {
        spans.addAll([
          const TextSpan(text: ' and scored an average of '),
          TextSpan(text: '${o.averagePercent}%', style: _highlight),
          const TextSpan(text: ' on graded work'),
        ]);
      }
      spans.add(const TextSpan(text: '.'));
      if (o.strongestCourse != null) {
        spans.addAll([
          const TextSpan(text: ' Your strongest course is '),
          TextSpan(text: o.strongestCourse!, style: _highlight),
          const TextSpan(text: '.'),
        ]);
      }
      if (o.focusCourse != null) {
        spans.addAll([
          const TextSpan(text: ' Focus on '),
          TextSpan(text: o.focusCourse!, style: _highlight),
          const TextSpan(text: ' next to improve your overall average.'),
        ]);
      }
      if (o.averagePercent == null && o.done > 0) {
        spans.add(const TextSpan(text: ' Your scores appear here once your work is graded.'));
      }
      return spans;
    }

    if (o.role == 'instructor' || o.role == 'admin') {
      return [
        const TextSpan(text: 'You have '),
        TextSpan(text: '${o.toGrade}', style: _highlight),
        TextSpan(text: ' written ${o.toGrade == 1 ? 'try' : 'tries'} waiting to be graded in your '),
        TextSpan(text: '${o.courses}', style: _highlight),
        TextSpan(text: ' ${o.courses == 1 ? 'course' : 'courses'}.'),
      ];
    }
    return const [TextSpan(text: 'Nothing to show here yet.')];
  }

  List<String> _chips(DashboardOverview o) {
    if (o.role == 'student') {
      return ['Open now: ${o.open}', 'Waiting for grading: ${o.waiting}', 'Graded: ${o.graded}'];
    }
    if (o.role == 'instructor' || o.role == 'admin') {
      return ['Courses: ${o.courses}', 'Quizzes: ${o.quizzes}', 'To grade: ${o.toGrade}'];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.darkBrown,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OVERVIEW', style: AppText.serif(size: 14, color: AppColors.cream)),
          const SizedBox(height: 8),
          FutureBuilder<DashboardOverview>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Text('Loading...', style: AppText.sans(size: 10.5, color: AppColors.cream));
              }
              if (snapshot.hasError) {
                return Text(errorText(snapshot.error!),
                    style: AppText.sans(size: 10.5, color: AppColors.cream));
              }
              final o = snapshot.data!;
              final chips = _chips(o);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text.rich(
                        TextSpan(
                          style: AppText.sans(size: 10.5, color: AppColors.cream),
                          children: _spans(o),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [for (final c in chips) _Chip(c)],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AppText.sans(size: 8, color: Colors.white, weight: FontWeight.w600)),
    );
  }
}