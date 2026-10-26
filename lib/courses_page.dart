import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  late Future<List<Course>> _future;

  bool get _isAdmin => Session.role == 'admin';

  @override
  void initState() {
    super.initState();
    _future = ApiService.courses();
  }

  void _reload() {
    setState(() {
      _future = ApiService.courses();
    });
  }

  String _emptyText() {
    switch (Session.role) {
      case 'admin':
        return 'No courses yet. Click NEW COURSE to create one.';
      case 'instructor':
        return 'No courses are assigned to you yet.';
      default:
        return 'You are not enrolled in any course yet.';
    }
  }

  Future<void> _newCourse() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewCourseDialog(),
    );
    if (created != true) return;
    if (!mounted) return;
    showSnack(context, 'Course created.');
    _reload();
  }

  Future<void> _delete(Course course) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete course',
      message: 'Delete "${course.title}" and all of its modules? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await ApiService.deleteCourse(course.id);
      if (!mounted) return;
      showSnack(context, 'Course deleted.');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'courses',
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                pageTitle('COURSES'),
                const Spacer(),
                if (_isAdmin) primaryButton(label: 'NEW COURSE', onPressed: _newCourse),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Course>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingBox();
                }
                if (snapshot.hasError) {
                  return CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
                }
                final courses = snapshot.data ?? [];
                if (courses.isEmpty) return CenteredMessage(_emptyText());
                return LayoutBuilder(builder: (context, c) {
                  final width = c.maxWidth < 320 ? c.maxWidth : 320.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final course in courses)
                        SizedBox(width: width, child: _courseCard(course)),
                    ],
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseCard(Course course) {
    return CardBox(
      onTap: () async {
        await Navigator.pushNamed(context, '/course/${course.id}');
        if (mounted) _reload();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: AppText.serif(
                      size: 15, color: AppColors.title, weight: FontWeight.w600),
                ),
              ),
              if (_isAdmin)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: 'Delete course',
                    onPressed: () => _delete(course),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.label),
                  ),
                ),
            ],
          ),
          if (course.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              course.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 11, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            course.instructor == null
                ? 'No instructor yet'
                : 'Instructor: ${course.instructor!.name}',
            style: AppText.sans(size: 10, color: AppColors.label),
          ),
          Text(
            '${course.studentCount} student${course.studentCount == 1 ? '' : 's'}',
            style: AppText.sans(size: 10, color: AppColors.orange),
          ),
        ],
      ),
    );
  }
}

class _NewCourseDialog extends StatefulWidget {
  const _NewCourseDialog();

  @override
  State<_NewCourseDialog> createState() => _NewCourseDialogState();
}

class _NewCourseDialogState extends State<_NewCourseDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late Future<List<UserLite>> _instructors;
  String _instructorId = ''; // '' means no instructor yet
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _instructors = ApiService.users(role: 'instructor');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a course title.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.createCourse(
        title: title,
        description: _description.text.trim(),
        instructorId: _instructorId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
      title: Text('New course', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fieldLabel('TITLE'),
              inputField(_title, 'Course title'),
              fieldLabel('DESCRIPTION'),
              inputField(_description, 'Short description (optional)',
                  minLines: 2, maxLines: 4),
              fieldLabel('INSTRUCTOR'),
              FutureBuilder<List<UserLite>>(
                future: _instructors,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Text('Loading instructors…',
                        style: AppText.sans(size: 11, color: Colors.black54));
                  }
                  final list = snapshot.hasError ? <UserLite>[] : (snapshot.data ?? []);
                  return SelectBox<String>(
                    value: _instructorId,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('No instructor yet')),
                      for (final u in list)
                        DropdownMenuItem(value: u.id, child: Text(u.name)),
                    ],
                    onChanged: (v) => setState(() => _instructorId = v),
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        primaryButton(label: 'CREATE', onPressed: _create, loading: _busy),
      ],
    );
  }
}