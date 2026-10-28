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
  AiReview({required this.keywords, required this.keyStatements});

  final List<String> keywords;
  final List<String> keyStatements;

  factory AiReview.fromJson(Map<String, dynamic> j) => AiReview(
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
  }) async {
    final data = await ApiService._request('POST', '/quizzes/course/$courseId', body: {
      'title': title,
      'kind': kind,
      'questions': questions,
      'published': published,
      'maxAttempts': maxAttempts,
      'opensAt': opensAt?.toUtc().toIso8601String(),
      'dueAt': dueAt?.toUtc().toIso8601String(),
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
  }) async {
    await ApiService._request('PATCH', '/quizzes/$quizId', body: {
      'opensAt': opensAt?.toUtc().toIso8601String(),
      'dueAt': dueAt?.toUtc().toIso8601String(),
      'maxAttempts': maxAttempts,
    });
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