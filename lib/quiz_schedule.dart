import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui_kit.dart';

/// The settings of one quiz, edited by the builder and by the "Edit settings" dialog:
/// schedule (opens, due, tries) and the anti-cheating options.
class QuizSchedule {
  QuizSchedule({
    this.opensAt,
    this.dueAt,
    this.maxAttempts = 1,
    this.lockAi = false,
    this.blockPaste = false,
    this.shuffle = false,
    this.timeLimitMinutes = 0,
  });

  DateTime? opensAt; // null = open as soon as it is published
  DateTime? dueAt; // null = no deadline
  int maxAttempts;
  bool lockAi; // AI tutor locked while this is open
  bool blockPaste; // no copy/paste on the quiz page
  bool shuffle; // questions and choices shuffled per try
  int timeLimitMinutes; // 0 = no time limit

  QuizSchedule copy() => QuizSchedule(
        opensAt: opensAt,
        dueAt: dueAt,
        maxAttempts: maxAttempts,
        lockAi: lockAi,
        blockPaste: blockPaste,
        shuffle: shuffle,
        timeLimitMinutes: timeLimitMinutes,
      );

  /// An error message, or null when the schedule is fine.
  String? check() {
    if (opensAt != null && dueAt != null && !dueAt!.isAfter(opensAt!)) {
      return 'The due date must be after the opening date.';
    }
    return null;
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// e.g. "Oct 26, 2026 3:30 PM"
String formatWhen(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  return '${_months[d.month - 1]} ${d.day}, ${d.year} $hour12:$minute $suffix';
}

/// Asks for a date, then a time. Returns null if the person cancels either one.
Future<DateTime?> pickDateTime(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final start = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 3),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Time limit choices in minutes (0 = no limit).
const List<int> timeLimitChoices = [0, 10, 15, 20, 30, 45, 60, 90, 120];

String timeLimitLabel(int minutes) => minutes == 0 ? 'No time limit' : '$minutes minutes';

/// The Opens / Due / Tries / anti-cheating controls. It changes [schedule] and calls [onChanged].
class ScheduleFields extends StatelessWidget {
  const ScheduleFields({super.key, required this.schedule, required this.onChanged});

  final QuizSchedule schedule;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context, {required bool opens}) async {
    final picked = await pickDateTime(context, opens ? schedule.opensAt : schedule.dueAt);
    if (picked == null) return;
    if (opens) {
      schedule.opensAt = picked;
    } else {
      schedule.dueAt = picked;
    }
    onChanged();
  }

  void _clear({required bool opens}) {
    if (opens) {
      schedule.opensAt = null;
    } else {
      schedule.dueAt = null;
    }
    onChanged();
  }

  Widget _dateRow(
    BuildContext context, {
    required String label,
    required String hint,
    required DateTime? value,
    required bool opens,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldLabel(label),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              value == null ? hint : formatWhen(value),
              style: AppText.sans(
                size: 12,
                color: value == null ? Colors.black54 : AppColors.darkBrown,
              ),
            ),
            OutlinedButton(
              onPressed: () => _pick(context, opens: opens),
              child: Text(value == null ? 'Set' : 'Change',
                  style: AppText.sans(size: 11, color: AppColors.label)),
            ),
            if (value != null)
              TextButton(
                onPressed: () => _clear(opens: opens),
                child: Text('Clear', style: AppText.sans(size: 11, color: AppColors.label)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _switchRow({
    required String title,
    required String help,
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: (v) {
        onToggle(v);
        onChanged();
      },
      title: Text(title, style: AppText.sans(size: 12, color: AppColors.darkBrown)),
      subtitle: Text(help, style: AppText.sans(size: 11, color: Colors.black54)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = schedule.check();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateRow(
          context,
          label: 'OPENS',
          hint: 'Open as soon as it is published',
          value: schedule.opensAt,
          opens: true,
        ),
        _dateRow(
          context,
          label: 'DUE',
          hint: 'No deadline',
          value: schedule.dueAt,
          opens: false,
        ),
        fieldLabel('TRIES ALLOWED PER STUDENT'),
        SizedBox(
          width: 180,
          child: SelectBox<int>(
            value: schedule.maxAttempts,
            items: [
              for (var n = 1; n <= 10; n++)
                DropdownMenuItem(value: n, child: Text('$n ${n == 1 ? 'try' : 'tries'}')),
            ],
            onChanged: (v) {
              schedule.maxAttempts = v;
              onChanged();
            },
          ),
        ),
        fieldLabel('TIME LIMIT PER TRY'),
        SizedBox(
          width: 180,
          child: SelectBox<int>(
            value: schedule.timeLimitMinutes,
            items: [
              for (final m in timeLimitChoices)
                DropdownMenuItem(value: m, child: Text(timeLimitLabel(m))),
            ],
            onChanged: (v) {
              schedule.timeLimitMinutes = v;
              onChanged();
            },
          ),
        ),
        fieldLabel('ANTI-CHEATING'),
        _switchRow(
          title: 'Lock the AI tutor',
          help: 'Students cannot use the AI tutor for this course while this is open.',
          value: schedule.lockAi,
          onToggle: (v) => schedule.lockAi = v,
        ),
        _switchRow(
          title: 'Block copy and paste',
          help: 'Best effort on the web. It cannot stop another device.',
          value: schedule.blockPaste,
          onToggle: (v) => schedule.blockPaste = v,
        ),
        _switchRow(
          title: 'Shuffle questions and choices',
          help: 'Every try shows a different order.',
          value: schedule.shuffle,
          onToggle: (v) => schedule.shuffle = v,
        ),
        if (problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(problem, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
          ),
      ],
    );
  }
}

/// "Edit settings" for a quiz that already exists. Returns the new [QuizSchedule] on SAVE.
class ScheduleDialog extends StatefulWidget {
  const ScheduleDialog({super.key, required this.quizTitle, required this.initial});

  final String quizTitle;
  final QuizSchedule initial;

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late final QuizSchedule _schedule = widget.initial.copy();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text('Quiz settings', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.quizTitle, style: AppText.sans(size: 12, color: Colors.black87)),
              ScheduleFields(schedule: _schedule, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        primaryButton(
          label: 'SAVE',
          onPressed: _schedule.check() != null ? null : () => Navigator.pop(context, _schedule),
        ),
      ],
    );
  }
}

/// The four kinds of graded work: tag value -> label.
const Map<String, String> quizKinds = {
  'quiz': 'Quiz',
  'activity': 'Activity',
  'minitask': 'Minitask',
  'task_performance': 'Task performance',
};

String kindLabel(String kind) => quizKinds[kind] ?? 'Quiz';