import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

import 'quiz_schedule.dart';

import 'pdf_actions.dart';

class _CourseData {
  _CourseData(this.course, this.chapters);
  final Course course;
  final List<ChapterOutline> chapters;
}

class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.courseId});

  final String courseId;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  late Future<_CourseData> _future;
  final _emails = TextEditingController();
  bool _enrolling = false;
  String? _enrollMessage;

  bool get _isAdmin => Session.role == 'admin';
  bool get _isStaff => _isAdmin || Session.role == 'instructor';

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  Future<_CourseData> _fetch() async {
    final results = await Future.wait<Object>([
      ApiService.course(widget.courseId),
      ChapterApi.outline(widget.courseId),
    ]);
    return _CourseData(results[0] as Course, results[1] as List<ChapterOutline>);
  }

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  /// Runs an action. On success: optional message, then reload. On failure: show the error.
  Future<void> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      if (!mounted) return;
      if (done != null) showSnack(context, done);
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  // ----- chapters -----

  Future<void> _addChapter() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _ChapterTitleDialog(heading: 'Add chapter'),
    );
    if (title == null) return;
    await _run(() => ChapterApi.createChapter(widget.courseId, title), done: 'Chapter added.');
  }

  Future<void> _renameChapter(ChapterOutline chapter) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _ChapterTitleDialog(heading: 'Rename chapter', initial: chapter.title),
    );
    if (title == null || title == chapter.title) return;
    await _run(() => ChapterApi.renameChapter(chapter.id, title), done: 'Chapter renamed.');
  }

  Future<void> _deleteChapter(ChapterOutline chapter) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete chapter',
      message: 'Delete the empty chapter "${chapter.title}"?',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run(() => ChapterApi.deleteChapter(chapter.id), done: 'Chapter deleted.');
  }

  // ----- modules and quizzes -----

  Future<void> _addModule(ChapterOutline chapter) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _AddModuleDialog(courseId: widget.courseId, chapterId: chapter.id),
    );
    if (result == null || !mounted) return;
    showSnack(context, result.isEmpty ? 'Module added.' : result);
    _reload();
  }

  Future<void> _newQuiz(ChapterOutline chapter) async {
    await Navigator.pushNamed(context, '/quiz-new/${widget.courseId}/${chapter.id}');
    if (mounted) _reload();
  }

  Future<void> _deleteModule(ChapterItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete module',
      message: 'Delete "${item.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run(() => ApiService.deleteModule(item.id), done: 'Module deleted.');
  }

  Future<void> _toggleQuiz(ChapterItem item) async {
    await _run(() => ApiService.setQuizPublished(item.id, !item.published));
  }

  Future<void> _editSchedule(ChapterItem item) async {
    final result = await showDialog<QuizSchedule>(
      context: context,
      builder: (_) => ScheduleDialog(
        quizTitle: item.title,
        initial: QuizSchedule(
          opensAt: item.opensAt,
          dueAt: item.dueAt,
          maxAttempts: item.maxAttempts,
          lockAi: item.lockAi,
          blockPaste: item.blockPaste,
          shuffle: item.shuffle,
          timeLimitMinutes: item.timeLimitMinutes,
        ),
      ),
    );
    if (result == null) return;
    await _run(
      () => ChapterApi.updateQuizSchedule(
        item.id,
        opensAt: result.opensAt,
        dueAt: result.dueAt,
        maxAttempts: result.maxAttempts,
        lockAi: result.lockAi,
        blockPaste: result.blockPaste,
        shuffle: result.shuffle,
        timeLimitMinutes: result.timeLimitMinutes,
      ),
      done: 'Settings updated.',
    );
  }

    Future<void> _uploadPdf(ChapterItem item) async {
    final ok = await pickAndUploadPdf(
      context,
      kind: item.isModule ? 'module' : 'quiz',
      ownerId: item.id,
    );
    if (ok && mounted) _reload();
  }

  Future<void> _removePdf(ChapterItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove PDF',
      message: 'Remove "${item.fileName}" from "${item.title}"?',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await _run(
      () => FileApi.remove(item.isModule ? 'module' : 'quiz', item.id),
      done: 'PDF removed.',
    );
  }

  Future<void> _deleteQuiz(ChapterItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete quiz',
      message: 'Delete "${item.title}" and all student submissions for it? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run(() => ApiService.deleteQuiz(item.id), done: 'Quiz deleted.');
  }

  // ----- students -----

  Future<void> _enroll() async {
    final emails = _emails.text
        .split(RegExp(r'[\s,;]+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (emails.isEmpty) {
      setState(() => _enrollMessage = 'Type at least one student email.');
      return;
    }
    setState(() {
      _enrolling = true;
      _enrollMessage = null;
    });
    try {
      final result = await ApiService.addStudents(widget.courseId, emails);
      if (!mounted) return;
      _emails.clear();
      final notFound =
          result.notFound.isEmpty ? '' : ' Not found: ${result.notFound.join(', ')}';
      setState(() {
        _enrolling = false;
        _enrollMessage = 'Enrolled ${result.added}.$notFound';
      });
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enrolling = false;
        _enrollMessage = errorText(e);
      });
    }
  }

  Future<void> _removeStudent(UserLite student) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove student',
      message: 'Remove ${student.name} from this course?',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await _run(() => ApiService.removeStudent(widget.courseId, student.id));
  }

    Future<void> _changeInstructor(Course course) async {
    final currentId = course.instructor?.id ?? '';
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => _InstructorDialog(currentId: currentId),
    );
    if (chosen == null || chosen == currentId) return;
    await _run(() => CourseAdminApi.setInstructor(widget.courseId, chosen),
        done: 'Instructor updated.');
  }

  // ----- screen -----

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'courses',
      body: PageBody(
        child: FutureBuilder<_CourseData>(
          future: _future,
          builder: (context, snapshot) {
            Widget content;
            if (snapshot.connectionState != ConnectionState.done) {
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
                    onPressed: () => goBack(context, '/courses'),
                    icon: const Icon(Icons.arrow_back_rounded,
                        size: 16, color: AppColors.label),
                    label: Text('COURSES',
                        style: AppText.sans(size: 11, color: AppColors.label)),
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

  Widget _content(_CourseData data) {
    final course = data.course;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.title, style: AppText.serif(size: 22, color: AppColors.title)),
              if (course.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(course.description,
                    style: AppText.sans(size: 12, color: Colors.black87)),
              ],
              const SizedBox(height: 10),
                            Row(
                children: [
                  Flexible(
                    child: Text(
                      course.instructor == null
                          ? 'No instructor assigned yet'
                          : 'Instructor: ${course.instructor!.name}',
                      style: AppText.sans(size: 11, color: AppColors.label),
                    ),
                  ),
                  if (_isAdmin)
                    TextButton(
                      onPressed: () => _changeInstructor(course),
                      child: Text(
                        course.instructor == null ? 'Assign' : 'Change',
                        style: AppText.sans(size: 11, color: AppColors.sidebar),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('CHAPTERS', style: AppText.sans(size: 12, color: AppColors.title)),
            const Spacer(),
            if (_isAdmin) primaryButton(label: 'ADD CHAPTER', onPressed: _addChapter),
          ],
        ),
        const SizedBox(height: 8),
        if (data.chapters.isEmpty)
          const CenteredMessage('This course has no chapters yet.')
        else
          for (final chapter in data.chapters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _chapterCard(chapter, data.chapters.length),
            ),
        if (_isStaff) ..._studentsSection(course),
      ],
    );
  }

  Widget _chapterCard(ChapterOutline chapter, int chapterCount) {
    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chapter.title,
                  style: AppText.serif(
                      size: 16, color: AppColors.title, weight: FontWeight.w600),
                ),
              ),
              if (_isAdmin)
                IconButton(
                  tooltip: 'Rename chapter',
                  iconSize: 18,
                  onPressed: () => _renameChapter(chapter),
                  icon: const Icon(Icons.edit_outlined, color: AppColors.label),
                ),
              if (_isAdmin && chapter.items.isEmpty && chapterCount > 1)
                IconButton(
                  tooltip: 'Delete chapter',
                  iconSize: 18,
                  onPressed: () => _deleteChapter(chapter),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.label),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (chapter.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing in this chapter yet.',
                  style: AppText.sans(size: 11, color: Colors.black54)),
            )
          else
            for (var i = 0; i < chapter.items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
              chapter.items[i].isModule
                  ? _moduleRow(chapter.items[i])
                  : _quizRow(chapter.items[i]),
            ],
          if (_isStaff) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isAdmin)
                  OutlinedButton.icon(
                    onPressed: () => _addModule(chapter),
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.label),
                    label: Text('ADD MODULE',
                        style: AppText.sans(size: 10.5, color: AppColors.label)),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _newQuiz(chapter),
                  icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.label),
                  label: Text('NEW QUIZ / ACTIVITY',
                      style: AppText.sans(size: 10.5, color: AppColors.label)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _moduleRow(ChapterItem item) {
    final hasFile = item.fileId != null;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/module/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 18, color: AppColors.label),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppText.sans(size: 13, color: Colors.black87)),
                  if (hasFile)
                    Text('PDF: ${item.fileName}',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(size: 10, color: AppColors.orange)),
                ],
              ),
            ),
            if (hasFile)
              IconButton(
                tooltip: 'Open PDF',
                iconSize: 18,
                onPressed: () => openPdf(context, item.fileId!),
                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.label),
              ),
            if (_isAdmin)
              PopupMenuButton<String>(
                tooltip: 'Module options',
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.label),
                onSelected: (value) {
                  if (value == 'upload') _uploadPdf(item);
                  if (value == 'removePdf') _removePdf(item);
                  if (value == 'delete') _deleteModule(item);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'upload',
                    child: Text(hasFile ? 'Replace PDF' : 'Upload PDF'),
                  ),
                  if (hasFile) const PopupMenuItem(value: 'removePdf', child: Text('Remove PDF')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete module')),
                ],
              )
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.label),
          ],
        ),
      ),
    );
  }

    String _stateLabel(String state) {
    switch (state) {
      case 'upcoming':
        return 'SCHEDULED';
      case 'open':
        return 'OPEN';
      case 'closed':
        return 'CLOSED';
      default:
        return 'DRAFT';
    }
  }

  String _postedBy(ChapterItem item) {
    if (item.postedByRole == 'admin') return 'ADMIN';
    if (item.postedByRole == 'instructor') return 'INSTRUCTOR';
    return '';
  }

  Widget _kindTag(String kind) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        kindLabel(kind).toUpperCase(),
        style: AppText.sans(size: 8.5, color: Colors.white),
      ),
    );
  }

  Widget _quizRow(ChapterItem item) {
    final questions =
        '${item.questionCount} question${item.questionCount == 1 ? '' : 's'} · ${item.totalPoints} points';
    final tries = '${item.maxAttempts} ${item.maxAttempts == 1 ? 'try' : 'tries'}';
    final schedule = [
      if (item.opensAt != null) 'Opens ${formatWhen(item.opensAt!)}',
      if (item.dueAt != null) 'Due ${formatWhen(item.dueAt!)}',
      tries,
    ].join(' · ');

    String progress;
    if (_isStaff) {
      progress = '${item.submissionCount} student${item.submissionCount == 1 ? '' : 's'} submitted';
      if (item.needsGrading > 0) progress += ' · ${item.needsGrading} to grade';
    } else if (item.status == 'graded') {
      progress = 'Score ${item.score}/${item.totalPoints}';
    } else if (item.status == 'submitted') {
      progress = 'Submitted, waiting for grading';
    } else if (item.state == 'upcoming') {
      progress = 'Not open yet';
    } else if (item.state == 'closed') {
      progress = 'Closed';
    } else {
      progress = 'Not taken yet';
    }
    if (!_isStaff && item.attemptsUsed > 0) {
      progress += ' · ${item.attemptsUsed}/${item.maxAttempts} tries used';
    }

    // Students can only open the PDF once the quiz is open (the server enforces this too)
    final hasFile = item.fileId != null;
    final canOpenFile = hasFile && (_isStaff || item.state == 'open' || item.state == 'closed');
    final by = _postedBy(item);

    return InkWell(
      onTap: () async {
        // instructors and admins review submissions, students take the quiz
        await Navigator.pushNamed(
          context,
          _isStaff ? '/quiz-review/${item.id}' : '/quiz/${item.id}',
        );
        if (mounted) _reload();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.quiz_outlined, size: 18, color: AppColors.label),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.title, style: AppText.sans(size: 13, color: Colors.black87)),
                      _kindTag(item.kind),
                    ],
                  ),
                  Text('$questions · $progress',
                      style: AppText.sans(size: 10, color: AppColors.label)),
                  Text(schedule, style: AppText.sans(size: 10, color: AppColors.orange)),
                  if (canOpenFile)
                    Text('PDF: ${item.fileName}',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(size: 10, color: AppColors.orange)),
                ],
              ),
            ),
            if (canOpenFile)
              IconButton(
                tooltip: 'Open PDF',
                iconSize: 18,
                onPressed: () => openPdf(context, item.fileId!),
                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.label),
              ),
            if (by.isNotEmpty)
              Tooltip(
                message: item.postedByName ?? by,
                child: _tag('POSTED BY $by', filled: false),
              ),
            if (_isStaff) ...[
              const SizedBox(width: 6),
              _tag(_stateLabel(item.state),
                  filled: item.state == 'open' || item.state == 'upcoming'),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.label),
                onSelected: (value) {
                  if (value == 'toggle') _toggleQuiz(item);
                  if (value == 'schedule') _editSchedule(item);
                  if (value == 'upload') _uploadPdf(item);
                  if (value == 'removePdf') _removePdf(item);
                  if (value == 'delete') _deleteQuiz(item);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.published ? 'Unpublish' : 'Publish'),
                  ),
                  const PopupMenuItem(value: 'schedule', child: Text('Edit schedule')),
                  PopupMenuItem(
                    value: 'upload',
                    child: Text(hasFile ? 'Replace PDF' : 'Upload PDF'),
                  ),
                  if (hasFile) const PopupMenuItem(value: 'removePdf', child: Text('Remove PDF')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.orange : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: filled ? AppColors.orange : AppColors.cardBorder),
      ),
      child: Text(
        text,
        style: AppText.sans(size: 8.5, color: filled ? Colors.white : AppColors.label),
      ),
    );
  }

  List<Widget> _studentsSection(Course course) {
    return [
      const SizedBox(height: 18),
      Text('STUDENTS (${course.students.length})',
          style: AppText.sans(size: 12, color: AppColors.title)),
      const SizedBox(height: 8),
      if (course.students.isEmpty)
        Text('No students enrolled yet.',
            style: AppText.sans(size: 11, color: Colors.black54))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in course.students)
              Tooltip(
                message: s.email,
                child: Chip(
                  label: Text(s.name, style: AppText.sans(size: 11, color: Colors.black87)),
                  backgroundColor: AppColors.cardCream,
                  side: const BorderSide(color: AppColors.cardBorder),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: _isAdmin ? () => _removeStudent(s) : null,
                ),
              ),
          ],
        ),
      if (_isAdmin) ...[
        const SizedBox(height: 14),
        fieldLabel('ENROLL STUDENTS'),
        inputField(
          _emails,
          'Student emails, separated by commas, spaces or new lines',
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: primaryButton(label: 'ENROLL', onPressed: _enroll, loading: _enrolling),
        ),
        if (_enrollMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_enrollMessage!,
                style: AppText.sans(size: 11, color: AppColors.darkBrown)),
          ),
      ],
    ];
  }
}

/// Small dialog used for both "Add chapter" and "Rename chapter".
class _ChapterTitleDialog extends StatefulWidget {
  const _ChapterTitleDialog({required this.heading, this.initial = ''});

  final String heading;
  final String initial;

  @override
  State<_ChapterTitleDialog> createState() => _ChapterTitleDialogState();
}

class _ChapterTitleDialogState extends State<_ChapterTitleDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a chapter title.');
      return;
    }
    Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text(widget.heading, style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel('CHAPTER TITLE'),
            inputField(_title, 'e.g. Chapter 1 - Introduction', onSubmitted: (_) => _submit()),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        primaryButton(label: 'SAVE', onPressed: _submit),
      ],
    );
  }
}

class _AddModuleDialog extends StatefulWidget {
  const _AddModuleDialog({required this.courseId, required this.chapterId});

  final String courseId;
  final String chapterId;

  @override
  State<_AddModuleDialog> createState() => _AddModuleDialogState();
}

class _AddModuleDialogState extends State<_AddModuleDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  PickedPdf? _pdf;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _choosePdf() async {
    final pdf = await pickPdf(context);
    if (pdf != null && mounted) setState(() => _pdf = pdf);
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a module title.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final moduleId = await ChapterApi.createModule(
        widget.courseId,
        chapterId: widget.chapterId,
        title: title,
        content: _content.text,
      );

      // The PDF goes up after the module exists. If it fails, the module is still saved.
      var message = '';
      if (_pdf != null) {
        try {
          await FileApi.upload('module', moduleId, _pdf!.name, _pdf!.bytes);
        } catch (e) {
          message =
              'Module added, but the PDF did not upload (${errorText(e)}). You can add it from the module menu.';
        }
      }

      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text('Add module', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fieldLabel('TITLE'),
              inputField(_title, 'Module title'),
              fieldLabel('HANDOUT PDF (OPTIONAL)'),
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
                    onPressed: _busy ? null : _choosePdf,
                    child: Text(_pdf == null ? 'Attach PDF' : 'Change',
                        style: AppText.sans(size: 11, color: AppColors.label)),
                  ),
                  if (_pdf != null)
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _pdf = null),
                      child: Text('Remove', style: AppText.sans(size: 11, color: AppColors.label)),
                    ),
                ],
              ),
              fieldLabel('HANDOUT TEXT / DESCRIPTION (OPTIONAL)'),
              inputField(_content, 'Paste the handout text here', minLines: 6, maxLines: 12),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        primaryButton(label: 'ADD', onPressed: _create, loading: _busy),
      ],
    );
  }
}

class _InstructorDialog extends StatefulWidget {
  const _InstructorDialog({required this.currentId});

  final String currentId;

  @override
  State<_InstructorDialog> createState() => _InstructorDialogState();
}

class _InstructorDialogState extends State<_InstructorDialog> {
  List<UserLite>? _list;
  String? _loadError;
  late String _selected = widget.currentId; // '' means no instructor

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.users(role: 'instructor');
      if (!mounted) return;
      setState(() {
        _list = list;
        // if the current instructor no longer exists, fall back to "none"
        if (_selected.isNotEmpty && !list.any((u) => u.id == _selected)) _selected = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    Widget body;
    if (_loadError != null) {
      body = Text(_loadError!,
          style: AppText.sans(size: 11, color: const Color(0xFFB3261E)));
    } else if (list == null) {
      body = Text('Loading instructors…',
          style: AppText.sans(size: 11, color: Colors.black54));
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectBox<String>(
            value: _selected,
            items: [
              const DropdownMenuItem(value: '', child: Text('No instructor')),
              for (final u in list)
                DropdownMenuItem(
                  value: u.id,
                  child: Text('${u.name} (${u.email})', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _selected = v),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'No instructors in your institution yet. Create one on the USERS page first.',
                style: AppText.sans(size: 11, color: Colors.black54),
              ),
            ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text('Course instructor', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(width: 380, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        primaryButton(
          label: 'SAVE',
          onPressed: list == null ? null : () => Navigator.pop(context, _selected),
        ),
      ],
    );
  }
}