import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show GlobalKey, NavigatorState;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lets any code (not just widgets) change pages, e.g. go back to sign-in on a 401.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ApiException implements Exception {
  ApiException(this.message, {this.unauthorized = false});
  final String message;
  final bool unauthorized;

  @override
  String toString() => message;
}

/// Who is signed in. Kept in memory AND saved in the browser (localStorage on web),
/// so a page refresh does not sign the user out.
class Session {
  static String? token;
  static String? id;
  static String? name;
  static String? email;
  static String? role;
  static bool mustChangePassword = false;
  static bool aiTutorEnabled = true;

  static bool get isLoggedIn => token != null;

  /// Where this user starts after signing in.
  static String get homeRoute {
    if (mustChangePassword) return '/change-password';
    return role == 'owner' ? '/institutions' : '/dashboard';
  }

  /// Copies the user fields from a server reply into memory.
  static void applyUser(Map<String, dynamic> data) {
    id = data['id']?.toString();
    name = data['name'] as String?;
    email = data['email'] as String?;
    role = data['role'] as String?;
    mustChangePassword = data['mustChangePassword'] as bool? ?? false;
    aiTutorEnabled = data['aiTutorEnabled'] as bool? ?? true;
  }

  static Future<void> _put(SharedPreferences p, String key, String? value) async {
    if (value == null) {
      await p.remove(key);
    } else {
      await p.setString(key, value);
    }
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await _put(p, 'session_token', token);
    await _put(p, 'session_id', id);
    await _put(p, 'session_name', name);
    await _put(p, 'session_email', email);
    await _put(p, 'session_role', role);
    await p.setBool('session_mustChange', mustChangePassword);
    await p.setBool('session_ai', aiTutorEnabled);
  }

  /// Called once in main() before the app starts.
  static Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('session_token');
    if (token == null) return;
    id = p.getString('session_id');
    name = p.getString('session_name');
    email = p.getString('session_email');
    role = p.getString('session_role');
    mustChangePassword = p.getBool('session_mustChange') ?? false;
    aiTutorEnabled = p.getBool('session_ai') ?? true;
  }

  static Future<void> _removeSaved() async {
    final p = await SharedPreferences.getInstance();
    for (final key in [
      'session_token', 'session_id', 'session_name', 'session_email',
      'session_role', 'session_mustChange', 'session_ai',
    ]) {
      await p.remove(key);
    }
  }

  static void clear() {
    token = null;
    id = null;
    name = null;
    email = null;
    role = null;
    mustChangePassword = false;
    aiTutorEnabled = true;
    unawaited(_removeSaved());
  }
}

// ---------- Models (like small C#/Java classes that hold server data) ----------

class UserLite {
  UserLite({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool mustChangePassword;

  factory UserLite.fromJson(Map<String, dynamic> j) => UserLite(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
      );
}

class Course {
  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    required this.studentCount,
    required this.students,
  });

  final String id;
  final String title;
  final String description;
  final UserLite? instructor;
  final int studentCount;
  final List<UserLite> students;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        instructor: j['instructor'] == null
            ? null
            : UserLite.fromJson(j['instructor'] as Map<String, dynamic>),
        studentCount: j['studentCount'] as int? ?? 0,
        students: ((j['students'] as List?) ?? [])
            .map((s) => UserLite.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class ModuleItem {
  ModuleItem({
    required this.id,
    required this.title,
    required this.order,
    this.content = '',
    this.courseId = '',
    this.courseTitle = '',
    this.fileId,
    this.fileName,
  });

  final String id;
  final String title;
  final int order;
  final String content;
  final String courseId;
  final String courseTitle;
  final String? fileId; // attached PDF
  final String? fileName;

  factory ModuleItem.fromJson(Map<String, dynamic> j) => ModuleItem(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        content: (j['content'] ?? '').toString(),
        courseId: (j['courseId'] ?? '').toString(),
        courseTitle: (j['courseTitle'] ?? '').toString(),
        fileId: j['fileId'] as String?,
        fileName: j['fileName'] as String?,
      );
}

class AiReview {
  AiReview({required this.summary, required this.keywords, required this.keyStatements});

  final String summary;
  final List<String> keywords;
  final List<String> keyStatements;

  factory AiReview.fromJson(Map<String, dynamic> j) => AiReview(
        summary: (j['summary'] ?? '').toString(),
        keywords: ((j['keywords'] as List?) ?? []).map((e) => e.toString()).toList(),
        keyStatements: ((j['keyStatements'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

class EnrollResult {
  EnrollResult({required this.added, required this.notFound});
  final int added;
  final List<String> notFound;
}

class Institution {
  Institution({
    required this.id,
    required this.name,
    required this.userCount,
    this.adminEmail,
  });

  final String id;
  final String name;
  final int userCount;
  final String? adminEmail;

  factory Institution.fromJson(Map<String, dynamic> j) => Institution(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        userCount: (j['userCount'] as num?)?.toInt() ?? 0,
        adminEmail: j['adminEmail'] as String?,
      );
}

class QuizSummary {
  QuizSummary({
    required this.id,
    required this.title,
    required this.published,
    required this.questionCount,
    required this.totalPoints,
    required this.submissionCount,
  });

  final String id;
  final String title;
  final bool published;
  final int questionCount;
  final int totalPoints;
  final int submissionCount;

  factory QuizSummary.fromJson(Map<String, dynamic> j) => QuizSummary(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        published: j['published'] as bool? ?? false,
        questionCount: (j['questionCount'] as num?)?.toInt() ?? 0,
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        submissionCount: (j['submissionCount'] as num?)?.toInt() ?? 0,
      );
}

// ---------- The API calls ----------

class ApiService {
  // Web and desktop reach the backend at localhost.
  // The Android emulator reaches your computer through 10.0.2.2 instead.
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  /// One place that sends every request: adds the token, decodes the JSON,
  /// and turns errors into ApiException. A 401 on a signed-in call signs the user out.
  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration timeout = const Duration(seconds: 15),
    bool signOutOn401 = true,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (auth && Session.token != null) {
      request.headers['Authorization'] = 'Bearer ${Session.token}';
    }
    if (body != null) request.body = jsonEncode(body);

    http.Response res;
    try {
      final streamed = await request.send().timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException("Can't reach the server. Is the backend running?");
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        throw ApiException('Unexpected response from the server.');
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    var message = 'Request failed (${res.statusCode}).';
    if (data is Map && data['error'] is String) message = data['error'] as String;

    if (res.statusCode == 401 && auth) {
      if (signOutOn401) {
        Session.clear();
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
      }
      throw ApiException(message, unauthorized: true);
    }
    throw ApiException(message);
  }

  // ----- auth -----

  static Future<void> login(String email, String password) async {
    try {
      final data = await _request(
        'POST',
        '/auth/login',
        body: {'email': email, 'password': password},
        auth: false,
        timeout: const Duration(seconds: 10),
      ) as Map<String, dynamic>;
      Session.token = data['token'] as String;
      Session.applyUser(data);
      await Session.save();
    } on ApiException catch (e) {
      if (e.message == 'User not found' || e.message == 'Wrong password') {
        throw ApiException('Incorrect email or password.');
      }
      rethrow;
    }
  }

  /// Used on startup/refresh: is the saved token still good?
  /// A 401 is NOT handled here (the caller decides); a network failure keeps the session.
  static Future<void> refreshMe() async {
    final data = await _request('GET', '/auth/me', signOutOn401: false) as Map<String, dynamic>;
    Session.applyUser(data);
    await Session.save();
  }

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    await _request('POST', '/auth/change-password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword});
    Session.mustChangePassword = false;
    await Session.save();
  }

  static Future<void> setAiTutor(bool enabled) async {
    final data = await _request('PATCH', '/auth/settings', body: {'aiTutorEnabled': enabled})
        as Map<String, dynamic>;
    Session.applyUser(data);
    await Session.save();
  }

  // ----- courses -----

  static Future<List<Course>> courses() async {
    final data = await _request('GET', '/courses') as List;
    return data.map((c) => Course.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<Course> course(String id) async {
    final data = await _request('GET', '/courses/$id') as Map<String, dynamic>;
    return Course.fromJson(data);
  }

  static Future<List<ModuleItem>> courseModules(String courseId) async {
    final data = await _request('GET', '/courses/$courseId/modules') as List;
    return data.map((m) => ModuleItem.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<Course> createCourse({
    required String title,
    String description = '',
    String instructorId = '',
  }) async {
    final data = await _request('POST', '/courses', body: {
      'title': title,
      'description': description,
      'instructorId': instructorId,
    }) as Map<String, dynamic>;
    return Course.fromJson(data);
  }

  static Future<void> deleteCourse(String id) async {
    await _request('DELETE', '/courses/$id');
  }

  static Future<EnrollResult> addStudents(String courseId, List<String> emails) async {
    final data = await _request('POST', '/courses/$courseId/students', body: {'emails': emails})
        as Map<String, dynamic>;
    return EnrollResult(
      added: data['added'] as int? ?? 0,
      notFound: ((data['notFound'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }

  static Future<void> removeStudent(String courseId, String studentId) async {
    await _request('DELETE', '/courses/$courseId/students/$studentId');
  }

  // ----- modules -----

  static Future<ModuleItem> createModule(String courseId,
      {required String title, required String content}) async {
    final data = await _request('POST', '/courses/$courseId/modules',
        body: {'title': title, 'content': content}) as Map<String, dynamic>;
    return ModuleItem.fromJson(data);
  }

  static Future<void> deleteModule(String id) async {
    await _request('DELETE', '/modules/$id');
  }

  static Future<ModuleItem> module(String id) async {
    final data = await _request('GET', '/modules/$id') as Map<String, dynamic>;
    return ModuleItem.fromJson(data);
  }

  // ----- users (admin) -----

  static Future<List<UserLite>> users({String? role}) async {
    final query = role == null ? '' : '?role=${Uri.encodeQueryComponent(role)}';
    final data = await _request('GET', '/admin/users$query') as List;
    return data.map((u) => UserLite.fromJson(u as Map<String, dynamic>)).toList();
  }

  static Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await _request('POST', '/admin/create-user',
        body: {'name': name, 'email': email, 'password': password, 'role': role});
  }

  // ----- institutions (owner) -----

  static Future<List<Institution>> institutions() async {
    final data = await _request('GET', '/owner/institutions') as List;
    return data.map((i) => Institution.fromJson(i as Map<String, dynamic>)).toList();
  }

  static Future<void> createInstitution({
    required String name,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) async {
    await _request('POST', '/owner/institutions', body: {
      'name': name,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'adminPassword': adminPassword,
    });
  }

  // ----- quizzes (instructor/admin) -----

  static Future<List<QuizSummary>> courseQuizzes(String courseId) async {
    final data = await _request('GET', '/quizzes/course/$courseId') as List;
    return data.map((q) => QuizSummary.fromJson(q as Map<String, dynamic>)).toList();
  }

  static Future<void> createQuiz(
    String courseId, {
    required String title,
    required List<Map<String, dynamic>> questions,
    bool published = false,
  }) async {
    await _request('POST', '/quizzes/course/$courseId',
        body: {'title': title, 'questions': questions, 'published': published});
  }

  static Future<void> setQuizPublished(String id, bool published) async {
    await _request('PATCH', '/quizzes/$id', body: {'published': published});
  }

  static Future<void> deleteQuiz(String id) async {
    await _request('DELETE', '/quizzes/$id');
  }

  // ----- AI tutor -----

  static Future<AiReview> aiReview(String moduleId) async {
    final data = await _request('POST', '/ai/module-review',
        body: {'moduleId': moduleId}, timeout: const Duration(seconds: 90)) as Map<String, dynamic>;
    return AiReview.fromJson(data);
  }
}

// ---------- Chapters ----------

class ChapterItem {
  ChapterItem({
    required this.type,
    required this.id,
    required this.title,
    this.published = false,
    this.questionCount = 0,
    this.totalPoints = 0,
    this.submissionCount = 0,
    this.submitted = false,
    this.status,
    this.score,
    this.state = '',
    this.opensAt,
    this.dueAt,
    this.maxAttempts = 1,
    this.attemptsUsed = 0,
    this.attemptsLeft = 1,
    this.fileId,
    this.fileName,
    this.kind = 'quiz',
    this.postedByRole,
    this.postedByName,
    this.lockAi = false,
    this.blockPaste = false,
    this.shuffle = false,
    this.timeLimitMinutes = 0,
    this.needsGrading = 0,
  });

  final String type; // 'module' or 'quiz' (quizzes, activities, minitasks and task performances)
  final String id;
  final String title;
  final bool published; // quizzes, instructor/admin view
  final int questionCount;
  final int totalPoints;
  final int submissionCount; // quizzes: how many students submitted (instructor/admin view)
  final bool submitted; // quizzes, student view
  final String? status; // 'submitted' or 'graded'
  final int? score;
  final String state; // quizzes: 'draft', 'upcoming', 'open' or 'closed'
  final DateTime? opensAt; // already converted to the local time zone
  final DateTime? dueAt;
  final int maxAttempts;
  final int attemptsUsed; // student view
  final int attemptsLeft; // student view
  final String? fileId; // attached PDF (modules and quizzes)
  final String? fileName;
  final String kind; // 'quiz', 'activity', 'minitask' or 'task_performance'
  final String? postedByRole; // 'admin' or 'instructor'
  final String? postedByName;
  final bool lockAi; // quizzes: AI tutor locked while open
  final bool blockPaste; // quizzes: copy/paste blocked
  final bool shuffle; // quizzes: shuffled per try
  final int timeLimitMinutes; // quizzes: 0 = no limit
  final int needsGrading; // quizzes: tries waiting for hand grading (instructor/admin view)

  bool get isModule => type == 'module';

  factory ChapterItem.fromJson(Map<String, dynamic> j) => ChapterItem(
        type: (j['type'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        published: j['published'] as bool? ?? false,
        questionCount: (j['questionCount'] as num?)?.toInt() ?? 0,
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        submissionCount: (j['submissionCount'] as num?)?.toInt() ?? 0,
        submitted: j['submitted'] as bool? ?? false,
        status: j['status'] as String?,
        score: (j['score'] as num?)?.toInt(),
        state: (j['state'] ?? '').toString(),
        opensAt: DateTime.tryParse((j['opensAt'] ?? '').toString())?.toLocal(),
        dueAt: DateTime.tryParse((j['dueAt'] ?? '').toString())?.toLocal(),
        maxAttempts: (j['maxAttempts'] as num?)?.toInt() ?? 1,
        attemptsUsed: (j['attemptsUsed'] as num?)?.toInt() ?? 0,
        attemptsLeft: (j['attemptsLeft'] as num?)?.toInt() ?? 1,
        fileId: j['fileId'] as String?,
        fileName: j['fileName'] as String?,
        kind: (j['kind'] ?? 'quiz').toString(),
        postedByRole: j['postedByRole'] as String?,
        postedByName: j['postedByName'] as String?,
        lockAi: j['lockAi'] as bool? ?? false,
        blockPaste: j['blockPaste'] as bool? ?? false,
        shuffle: j['shuffle'] as bool? ?? false,
        timeLimitMinutes: (j['timeLimitMinutes'] as num?)?.toInt() ?? 0,
        needsGrading: (j['needsGrading'] as num?)?.toInt() ?? 0,
      );
}

class ChapterOutline {
  ChapterOutline({required this.id, required this.title, required this.items});

  final String id;
  final String title;
  final List<ChapterItem> items;

  factory ChapterOutline.fromJson(Map<String, dynamic> j) => ChapterOutline(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        items: ((j['items'] as List?) ?? [])
            .map((i) => ChapterItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

class ChapterApi {
  static Future<List<ChapterOutline>> outline(String courseId) async {
    final data = await ApiService._request('GET', '/chapters/course/$courseId') as List;
    return data.map((c) => ChapterOutline.fromJson(c as Map<String, dynamic>)).toList();
  }

  static Future<void> createChapter(String courseId, String title) async {
    await ApiService._request('POST', '/chapters/course/$courseId', body: {'title': title});
  }

  static Future<void> renameChapter(String id, String title) async {
    await ApiService._request('PATCH', '/chapters/$id', body: {'title': title});
  }

  static Future<void> deleteChapter(String id) async {
    await ApiService._request('DELETE', '/chapters/$id');
  }

  /// Returns the id of the new module.
  static Future<String> createModule(
    String courseId, {
    required String chapterId,
    required String title,
    required String content,
  }) async {
    final data = await ApiService._request('POST', '/courses/$courseId/modules',
        body: {'title': title, 'content': content, 'chapterId': chapterId}) as Map<String, dynamic>;
    return (data['id'] ?? '').toString();
  }

  /// Returns the id of the new quiz/activity/minitask/task performance.
  static Future<String> createQuiz(
    String courseId, {
    String? chapterId,
    String kind = 'quiz',
    required String title,
    required List<Map<String, dynamic>> questions,
    bool published = false,
    DateTime? opensAt,
    DateTime? dueAt,
    int maxAttempts = 1,
    bool lockAi = false,
    bool blockPaste = false,
    bool shuffle = false,
    int timeLimitMinutes = 0,
  }) async {
    final data = await ApiService._request('POST', '/quizzes/course/$courseId', body: {
      'title': title,
      'kind': kind,
      'questions': questions,
      'published': published,
      'maxAttempts': maxAttempts,
      'opensAt': opensAt?.toUtc().toIso8601String(),
      'dueAt': dueAt?.toUtc().toIso8601String(),
      'lockAi': lockAi,
      'blockPaste': blockPaste,
      'shuffle': shuffle,
      'timeLimitMinutes': timeLimitMinutes,
      'chapterId': ?chapterId,
    }) as Map<String, dynamic>;
    return (data['id'] ?? '').toString();
  }

  /// A null date clears it (open right away / no deadline).
  static Future<void> updateQuizSchedule(
    String quizId, {
    DateTime? opensAt,
    DateTime? dueAt,
    required int maxAttempts,
    required bool lockAi,
    required bool blockPaste,
    required bool shuffle,
    required int timeLimitMinutes,
  }) async {
    await ApiService._request('PATCH', '/quizzes/$quizId', body: {
      'opensAt': opensAt?.toUtc().toIso8601String(),
      'dueAt': dueAt?.toUtc().toIso8601String(),
      'maxAttempts': maxAttempts,
      'lockAi': lockAi,
      'blockPaste': blockPaste,
      'shuffle': shuffle,
      'timeLimitMinutes': timeLimitMinutes,
    });
  }
}

// ---------- Dashboard ----------

class DashboardTask {
  DashboardTask({
    required this.id,
    required this.title,
    required this.kind,
    required this.courseId,
    required this.courseTitle,
    required this.dueAt,
    required this.detail,
  });

  final String id;
  final String title;
  final String kind;
  final String courseId;
  final String courseTitle;
  final DateTime? dueAt; // already converted to the local time zone
  final String detail; // "Try 1 of 2" (student) or "3 to grade" (staff)

  factory DashboardTask.fromJson(Map<String, dynamic> j) => DashboardTask(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        kind: (j['kind'] ?? 'quiz').toString(),
        courseId: (j['courseId'] ?? '').toString(),
        courseTitle: (j['courseTitle'] ?? '').toString(),
        dueAt: DateTime.tryParse((j['dueAt'] ?? '').toString())?.toLocal(),
        detail: (j['detail'] ?? '').toString(),
      );
}

class DashboardOverview {
  DashboardOverview({
    required this.role,
    this.total = 0,
    this.done = 0,
    this.open = 0,
    this.waiting = 0,
    this.graded = 0,
    this.averagePercent,
    this.strongestCourse,
    this.focusCourse,
    this.courses = 0,
    this.quizzes = 0,
    this.toGrade = 0,
  });

  final String role;
  // student
  final int total; // published work so far
  final int done; // work with at least one try
  final int open; // open now with tries left
  final int waiting; // tries waiting for hand grading
  final int graded; // work with a graded try
  final int? averagePercent; // null until something is graded
  final String? strongestCourse;
  final String? focusCourse;
  // instructor / admin
  final int courses;
  final int quizzes;
  final int toGrade;

  factory DashboardOverview.fromJson(Map<String, dynamic> j) => DashboardOverview(
        role: (j['role'] ?? '').toString(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        open: (j['open'] as num?)?.toInt() ?? 0,
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
        graded: (j['graded'] as num?)?.toInt() ?? 0,
        averagePercent: (j['averagePercent'] as num?)?.toInt(),
        strongestCourse: j['strongestCourse'] as String?,
        focusCourse: j['focusCourse'] as String?,
        courses: (j['courses'] as num?)?.toInt() ?? 0,
        quizzes: (j['quizzes'] as num?)?.toInt() ?? 0,
        toGrade: (j['toGrade'] as num?)?.toInt() ?? 0,
      );
}

class DashboardApi {
  static Future<DashboardOverview> overview() async {
    final data = await ApiService._request('GET', '/dashboard/overview') as Map<String, dynamic>;
    return DashboardOverview.fromJson(data);
  }
  static Future<List<DashboardTask>> tasks() async {
    final data = await ApiService._request('GET', '/dashboard/tasks') as Map<String, dynamic>;
    return ((data['tasks'] as List?) ?? [])
        .map((t) => DashboardTask.fromJson(t as Map<String, dynamic>))
        .toList();
  }
}

// ---------- News ----------

class NewsItem {
  NewsItem({required this.id, required this.tag, required this.title, required this.createdAt});

  final String id;
  final String tag; // 'NEW', 'EVENT' or 'UPDATE'
  final String title;
  final DateTime? createdAt; // already converted to the local time zone

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: (j['id'] ?? '').toString(),
        tag: (j['tag'] ?? 'NEW').toString(),
        title: (j['title'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
      );
}

class NewsApi {
  static Future<List<NewsItem>> list() async {
    final data = await ApiService._request('GET', '/news') as List;
    return data.map((n) => NewsItem.fromJson(n as Map<String, dynamic>)).toList();
  }

  static Future<void> create({required String tag, required String title}) async {
    await ApiService._request('POST', '/news', body: {'tag': tag, 'title': title});
  }

  static Future<void> delete(String id) async {
    await ApiService._request('DELETE', '/news/$id');
  }
}

// ---------- AI practice ----------

class PracticeQuestion {
  PracticeQuestion({
    required this.text,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });

  final String text;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  factory PracticeQuestion.fromJson(Map<String, dynamic> j) => PracticeQuestion(
        text: (j['text'] ?? '').toString(),
        choices: ((j['choices'] as List?) ?? []).map((c) => c.toString()).toList(),
        correctIndex: (j['correctIndex'] as num?)?.toInt() ?? 0,
        explanation: (j['explanation'] ?? '').toString(),
      );
}

class PracticeQuiz {
  PracticeQuiz({required this.id, required this.moduleTitle, required this.questions});

  final String id; // the saved attempt
  final String moduleTitle;
  final List<PracticeQuestion> questions;

  factory PracticeQuiz.fromJson(Map<String, dynamic> j) => PracticeQuiz(
        id: (j['id'] ?? '').toString(),
        moduleTitle: (j['moduleTitle'] ?? '').toString(),
        questions: ((j['questions'] as List?) ?? [])
            .map((q) => PracticeQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

/// One line of the practice history list.
class PracticeSummary {
  PracticeSummary({
    required this.id,
    required this.courseTitle,
    required this.moduleTitle,
    required this.score,
    required this.total,
    required this.finishedAt,
  });

  final String id;
  final String courseTitle;
  final String moduleTitle;
  final int score;
  final int total;
  final DateTime? finishedAt;

  factory PracticeSummary.fromJson(Map<String, dynamic> j) => PracticeSummary(
        id: (j['id'] ?? '').toString(),
        courseTitle: (j['courseTitle'] ?? '').toString(),
        moduleTitle: (j['moduleTitle'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        finishedAt: DateTime.tryParse((j['finishedAt'] ?? '').toString())?.toLocal(),
      );
}

/// One question of a saved practice result, with the student's pick.
class PracticeAnswerRow {
  PracticeAnswerRow({
    required this.text,
    required this.choices,
    required this.correctIndex,
    required this.pickedIndex,
    required this.explanation,
  });

  final String text;
  final List<String> choices;
  final int correctIndex;
  final int? pickedIndex; // null = left unanswered
  final String explanation;

  bool get isCorrect => pickedIndex == correctIndex;

  factory PracticeAnswerRow.fromJson(Map<String, dynamic> j) => PracticeAnswerRow(
        text: (j['text'] ?? '').toString(),
        choices: ((j['choices'] as List?) ?? []).map((c) => c.toString()).toList(),
        correctIndex: (j['correctIndex'] as num?)?.toInt() ?? 0,
        pickedIndex: (j['pickedIndex'] as num?)?.toInt(),
        explanation: (j['explanation'] ?? '').toString(),
      );
}

class PracticeDetail {
  PracticeDetail({
    required this.id,
    required this.courseTitle,
    required this.moduleTitle,
    required this.score,
    required this.total,
    required this.finishedAt,
    required this.rows,
  });

  final String id;
  final String courseTitle;
  final String moduleTitle;
  final int score;
  final int total;
  final DateTime? finishedAt;
  final List<PracticeAnswerRow> rows;

  factory PracticeDetail.fromJson(Map<String, dynamic> j) => PracticeDetail(
        id: (j['id'] ?? '').toString(),
        courseTitle: (j['courseTitle'] ?? '').toString(),
        moduleTitle: (j['moduleTitle'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        finishedAt: DateTime.tryParse((j['finishedAt'] ?? '').toString())?.toLocal(),
        rows: ((j['questions'] as List?) ?? [])
            .map((q) => PracticeAnswerRow.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class AiApi {
  /// Saves the student's picks (null = unanswered) and the server works out the score.
  static Future<void> finishPractice(String id, List<int?> answers) async {
    await ApiService._request('POST', '/ai/practice/$id/finish', body: {'answers': answers});
  }

  static Future<List<PracticeSummary>> practiceHistory() async {
    final data = await ApiService._request('GET', '/ai/practice') as List;
    return data.map((p) => PracticeSummary.fromJson(p as Map<String, dynamic>)).toList();
  }

  static Future<PracticeDetail> practiceDetail(String id) async {
    final data = await ApiService._request('GET', '/ai/practice/$id') as Map<String, dynamic>;
    return PracticeDetail.fromJson(data);
  }

  static Future<void> deletePractice(String id) async {
    await ApiService._request('DELETE', '/ai/practice/$id');
  }
  /// [messages] is the chat so far: [{'role': 'student' | 'tutor', 'text': '...'}]. Returns the reply.
  static Future<String> chat(String moduleId, List<Map<String, String>> messages) async {
    final data = await ApiService._request(
      'POST',
      '/ai/chat',
      body: {'moduleId': moduleId, 'messages': messages},
      timeout: const Duration(seconds: 100),
    ) as Map<String, dynamic>;
    return (data['reply'] ?? '').toString();
  }
  static Future<PracticeQuiz> practiceQuiz(String moduleId, {int count = 5}) async {
    final data = await ApiService._request(
      'POST',
      '/ai/practice-quiz',
      body: {'moduleId': moduleId, 'count': count},
      timeout: const Duration(seconds: 100),
    ) as Map<String, dynamic>;
    return PracticeQuiz.fromJson(data);
  }
}

// ---------- Course admin ----------

class CourseAdminApi {
  /// instructorId '' removes the instructor.
  static Future<void> setInstructor(String courseId, String instructorId) async {
    await ApiService._request('PATCH', '/courses/$courseId/instructor',
        body: {'instructorId': instructorId});
  }
}

// ---------- PDF files ----------

class FileApi {
  /// kind is 'module' or 'quiz'. The PDF bytes are sent as they are (not as JSON).
  static Future<void> upload(String kind, String ownerId, String name, List<int> bytes) async {
    final uri = Uri.parse(
        '${ApiService.baseUrl}/files/$kind/$ownerId?name=${Uri.encodeQueryComponent(name)}');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/pdf';
    if (Session.token != null) request.headers['Authorization'] = 'Bearer ${Session.token}';
    request.bodyBytes = bytes;

    http.Response res;
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException("Can't reach the server. Is the backend running?");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    var message = 'Upload failed (${res.statusCode}).';
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['error'] is String) message = data['error'] as String;
    } catch (_) {}

    if (res.statusCode == 401) {
      Session.clear();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
      throw ApiException(message, unauthorized: true);
    }
    throw ApiException(message);
  }

  /// A link to the PDF that works for 2 minutes.
  static Future<String> link(String fileId) async {
    final data = await ApiService._request('POST', '/files/$fileId/link') as Map<String, dynamic>;
    return data['url'] as String;
  }

  static Future<void> remove(String kind, String ownerId) async {
    await ApiService._request('DELETE', '/files/$kind/$ownerId');
  }
}

// ---------- Taking quizzes (students) ----------

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.type,
    required this.text,
    required this.choices,
    required this.points,
  });

  final String id;
  final String type; // 'mcq' or 'text'
  final String text;
  final List<String> choices;
  final int points;

  bool get isChoice => type == 'mcq';

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? 'mcq').toString(),
        text: (j['text'] ?? '').toString(),
        choices: ((j['choices'] as List?) ?? []).map((c) => c.toString()).toList(),
        points: (j['points'] as num?)?.toInt() ?? 1,
      );
}

/// A quiz as a student sees it. The questions are only filled in when [canTake] is true.
class QuizTake {
  QuizTake({
    required this.id,
    required this.courseId,
    required this.title,
    required this.totalPoints,
    required this.state,
    required this.opensAt,
    required this.dueAt,
    required this.maxAttempts,
    required this.attemptsUsed,
    required this.attemptsLeft,
    required this.canTake,
    required this.status,
    required this.score,
    required this.questions,
    required this.fileId,
    required this.fileName,
    this.blockPaste = false,
    this.timeLimitMinutes = 0,
  });

  final String id;
  final String courseId;
  final String title;
  final int totalPoints;
  final String state; // 'upcoming', 'open' or 'closed'
  final DateTime? opensAt;
  final DateTime? dueAt;
  final int maxAttempts;
  final int attemptsUsed;
  final int attemptsLeft;
  final bool canTake;
  final String? status;
  final int? score;
  final List<QuizQuestion> questions;
  final String? fileId;
  final String? fileName;

  final bool blockPaste; // copy and paste blocked while answering
  final int timeLimitMinutes; // 0 = no time limit

  factory QuizTake.fromJson(Map<String, dynamic> j) => QuizTake(
        id: (j['id'] ?? '').toString(),
        courseId: (j['courseId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        state: (j['state'] ?? '').toString(),
        opensAt: DateTime.tryParse((j['opensAt'] ?? '').toString())?.toLocal(),
        dueAt: DateTime.tryParse((j['dueAt'] ?? '').toString())?.toLocal(),
        maxAttempts: (j['maxAttempts'] as num?)?.toInt() ?? 1,
        attemptsUsed: (j['attemptsUsed'] as num?)?.toInt() ?? 0,
        attemptsLeft: (j['attemptsLeft'] as num?)?.toInt() ?? 0,
        canTake: j['canTake'] as bool? ?? false,
        status: j['status'] as String?,
        score: (j['score'] as num?)?.toInt(),
        questions: ((j['questions'] as List?) ?? [])
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
        fileId: j['fileId'] as String?,
        fileName: j['fileName'] as String?,
        blockPaste: j['blockPaste'] as bool? ?? false,
        timeLimitMinutes: (j['timeLimitMinutes'] as num?)?.toInt() ?? 0,
      );
}

class AttemptInfo {
  AttemptInfo({required this.attempt, required this.status, required this.score});

  final int attempt;
  final String status; // 'submitted' or 'graded'
  final int score;

  factory AttemptInfo.fromJson(Map<String, dynamic> j) => AttemptInfo(
        attempt: (j['attempt'] as num?)?.toInt() ?? 1,
        status: (j['status'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
      );
}

/// One question of a submitted try, with the student's answer.
class AnswerReview {
  AnswerReview({
    required this.type,
    required this.text,
    required this.choices,
    required this.points,
    required this.yourChoiceIndex,
    required this.yourText,
    required this.correctIndex,
    required this.awarded,
    required this.feedback,
  });

  final String type;
  final String text;
  final List<String> choices;
  final int points;
  final int? yourChoiceIndex;
  final String yourText;
  final int? correctIndex; // empty until the correct answers are revealed
  final int? awarded; // empty until graded
  final String feedback;

  bool get isChoice => type == 'mcq';

  factory AnswerReview.fromJson(Map<String, dynamic> j) => AnswerReview(
        type: (j['type'] ?? 'mcq').toString(),
        text: (j['text'] ?? '').toString(),
        choices: ((j['choices'] as List?) ?? []).map((c) => c.toString()).toList(),
        points: (j['points'] as num?)?.toInt() ?? 1,
        yourChoiceIndex: (j['yourChoiceIndex'] as num?)?.toInt(),
        yourText: (j['yourText'] ?? '').toString(),
        correctIndex: (j['correctIndex'] as num?)?.toInt(),
        awarded: (j['awarded'] as num?)?.toInt(),
        feedback: (j['feedback'] ?? '').toString(),
      );
}

class QuizResult {
  QuizResult({
    required this.title,
    required this.attempt,
    required this.attemptsUsed,
    required this.attemptsAllowed,
    required this.revealed,
    required this.attempts,
    required this.status,
    required this.score,
    required this.totalPoints,
    required this.answers,
  });

  final String title;
  final int attempt; // which try is shown
  final int attemptsUsed;
  final int attemptsAllowed;
  final bool revealed; // are the correct answers shown?
  final List<AttemptInfo> attempts;
  final String status; // 'submitted' or 'graded'
  final int score;
  final int totalPoints;
  final List<AnswerReview> answers;

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        title: (j['title'] ?? '').toString(),
        attempt: (j['attempt'] as num?)?.toInt() ?? 1,
        attemptsUsed: (j['attemptsUsed'] as num?)?.toInt() ?? 1,
        attemptsAllowed: (j['attemptsAllowed'] as num?)?.toInt() ?? 1,
        revealed: j['revealed'] as bool? ?? false,
        attempts: ((j['attempts'] as List?) ?? [])
            .map((a) => AttemptInfo.fromJson(a as Map<String, dynamic>))
            .toList(),
        status: (j['status'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        answers: ((j['answers'] as List?) ?? [])
            .map((a) => AnswerReview.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

/// What the server returns when a timed try starts.
class QuizStart {
  QuizStart({required this.secondsLeft, required this.questions});

  final int secondsLeft;
  final List<QuizQuestion> questions;

  factory QuizStart.fromJson(Map<String, dynamic> j) => QuizStart(
        secondsLeft: (j['secondsLeft'] as num?)?.toInt() ?? 0,
        questions: ((j['questions'] as List?) ?? [])
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class QuizTakeApi {
  static Future<QuizTake> quiz(String id) async {
    final data = await ApiService._request('GET', '/quizzes/$id') as Map<String, dynamic>;
    return QuizTake.fromJson(data);
  }

  /// answers: [{ 'questionId': ..., 'choiceIndex': ... }, { 'questionId': ..., 'text': ... }]
  static Future<QuizResult> submit(String id, List<Map<String, dynamic>> answers) async {
    final data = await ApiService._request('POST', '/quizzes/$id/submit',
        body: {'answers': answers}, timeout: const Duration(seconds: 30)) as Map<String, dynamic>;
    return QuizResult.fromJson(data);
  }

  /// Starts (or resumes) a timed try. The server keeps the clock.
  static Future<QuizStart> start(String id) async {
    final data = await ApiService._request('POST', '/quizzes/$id/start') as Map<String, dynamic>;
    return QuizStart.fromJson(data);
  }

  /// The latest try, or a specific one.
  static Future<QuizResult> mySubmission(String id, {int? attempt}) async {
    final query = attempt == null ? '' : '?attempt=$attempt';
    final data = await ApiService._request('GET', '/quizzes/$id/my-submission$query')
        as Map<String, dynamic>;
    return QuizResult.fromJson(data);
  }
}

// ---------- Grading (instructors and admins) ----------

class AttemptRow {
  AttemptRow({
    required this.submissionId,
    required this.attempt,
    required this.status,
    required this.score,
  });

  final String submissionId;
  final int attempt;
  final String status; // 'submitted' (needs grading) or 'graded'
  final int score;

  factory AttemptRow.fromJson(Map<String, dynamic> j) => AttemptRow(
        submissionId: (j['submissionId'] ?? '').toString(),
        attempt: (j['attempt'] as num?)?.toInt() ?? 1,
        status: (j['status'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
      );
}

class StudentSubmissions {
  StudentSubmissions({
    required this.id,
    required this.name,
    required this.email,
    required this.attemptsUsed,
    required this.bestScore,
    required this.needsGrading,
    required this.attempts,
  });

  final String id;
  final String name;
  final String email;
  final int attemptsUsed;
  final int? bestScore; // highest graded try, if any
  final int needsGrading;
  final List<AttemptRow> attempts;

  factory StudentSubmissions.fromJson(Map<String, dynamic> j) => StudentSubmissions(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        attemptsUsed: (j['attemptsUsed'] as num?)?.toInt() ?? 0,
        bestScore: (j['bestScore'] as num?)?.toInt(),
        needsGrading: (j['needsGrading'] as num?)?.toInt() ?? 0,
        attempts: ((j['attempts'] as List?) ?? [])
            .map((a) => AttemptRow.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class SubmissionsOverview {
  SubmissionsOverview({
    required this.quizId,
    required this.courseId,
    required this.title,
    required this.kind,
    required this.totalPoints,
    required this.maxAttempts,
    required this.students,
  });

  final String quizId;
  final String courseId;
  final String title;
  final String kind;
  final int totalPoints;
  final int maxAttempts;
  final List<StudentSubmissions> students;

  factory SubmissionsOverview.fromJson(Map<String, dynamic> j) => SubmissionsOverview(
        quizId: (j['quizId'] ?? '').toString(),
        courseId: (j['courseId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        kind: (j['kind'] ?? 'quiz').toString(),
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        maxAttempts: (j['maxAttempts'] as num?)?.toInt() ?? 1,
        students: ((j['students'] as List?) ?? [])
            .map((s) => StudentSubmissions.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// One question of a try, as the grader sees it.
class GradeAnswer {
  GradeAnswer({
    required this.questionId,
    required this.type,
    required this.text,
    required this.choices,
    required this.points,
    required this.yourChoiceIndex,
    required this.yourText,
    required this.correctIndex,
    required this.awarded,
    required this.feedback,
  });

  final String questionId;
  final String type;
  final String text;
  final List<String> choices;
  final int points;
  final int? yourChoiceIndex;
  final String yourText;
  final int? correctIndex;
  final int? awarded; // empty until graded
  final String feedback;

  bool get isChoice => type == 'mcq';

  factory GradeAnswer.fromJson(Map<String, dynamic> j) => GradeAnswer(
        questionId: (j['questionId'] ?? '').toString(),
        type: (j['type'] ?? 'mcq').toString(),
        text: (j['text'] ?? '').toString(),
        choices: ((j['choices'] as List?) ?? []).map((c) => c.toString()).toList(),
        points: (j['points'] as num?)?.toInt() ?? 1,
        yourChoiceIndex: (j['yourChoiceIndex'] as num?)?.toInt(),
        yourText: (j['yourText'] ?? '').toString(),
        correctIndex: (j['correctIndex'] as num?)?.toInt(),
        awarded: (j['awarded'] as num?)?.toInt(),
        feedback: (j['feedback'] ?? '').toString(),
      );
}

class GradeDetail {
  GradeDetail({
    required this.submissionId,
    required this.title,
    required this.studentName,
    required this.studentEmail,
    required this.attempt,
    required this.status,
    required this.score,
    required this.totalPoints,
    required this.submittedAt,
    required this.answers,
  });

  final String submissionId;
  final String title;
  final String studentName;
  final String studentEmail;
  final int attempt;
  final String status;
  final int score;
  final int totalPoints;
  final DateTime? submittedAt;
  final List<GradeAnswer> answers;

  factory GradeDetail.fromJson(Map<String, dynamic> j) => GradeDetail(
        submissionId: (j['submissionId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        studentName: (j['studentName'] ?? '').toString(),
        studentEmail: (j['studentEmail'] ?? '').toString(),
        attempt: (j['attempt'] as num?)?.toInt() ?? 1,
        status: (j['status'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        submittedAt: DateTime.tryParse((j['submittedAt'] ?? '').toString())?.toLocal(),
        answers: ((j['answers'] as List?) ?? [])
            .map((a) => GradeAnswer.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class GradingApi {
  static Future<SubmissionsOverview> overview(String quizId) async {
    final data = await ApiService._request('GET', '/quizzes/$quizId/submissions')
        as Map<String, dynamic>;
    return SubmissionsOverview.fromJson(data);
  }

  static Future<GradeDetail> detail(String quizId, String submissionId) async {
    final data = await ApiService._request('GET', '/quizzes/$quizId/submissions/$submissionId')
        as Map<String, dynamic>;
    return GradeDetail.fromJson(data);
  }

  /// grades: [{ 'questionId': ..., 'points': int or null, 'feedback': '...' }]
  static Future<GradeDetail> save(
      String quizId, String submissionId, List<Map<String, dynamic>> grades) async {
    final data = await ApiService._request(
        'PUT', '/quizzes/$quizId/submissions/$submissionId/grade',
        body: {'grades': grades}) as Map<String, dynamic>;
    return GradeDetail.fromJson(data);
  }
}