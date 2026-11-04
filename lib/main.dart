import 'package:flutter/material.dart';

import 'api_service.dart';
import 'change_password_page.dart';
import 'course_page.dart';
import 'courses_page.dart';
import 'dashboard_page.dart';
import 'ai_chat_page.dart';
import 'ai_history_page.dart';
import 'quizzes_page.dart';
import 'ai_page.dart';
import 'grade_page.dart';
import 'institutions_page.dart';
import 'module_page.dart';
import 'quiz_editor_page.dart';
import 'quiz_page.dart';
import 'quiz_review_page.dart';
import 'sign_in_page.dart';
import 'theme.dart';
import 'users_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.restore(); // load the saved sign-in (this is what survives a refresh)
  runApp(const CarverCourseApp());
}

class CarverCourseApp extends StatelessWidget {
  const CarverCourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carver - Course',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF8B3A10)),
      initialRoute: '/',
      onGenerateRoute: _route,
      // Without this, a refreshed deep link builds a stack of prefix pages.
      onGenerateInitialRoutes: (name) => [_route(RouteSettings(name: name))],
    );
  }
}

/// Turns a page address like /course/123 into the right page.
/// An address that matches nothing goes to AuthGate (which sends you home).
Route<dynamic> _route(RouteSettings settings) {
  final segments = Uri.parse(settings.name ?? '/')
      .pathSegments
      .where((s) => s.isNotEmpty)
      .toList();

  Widget page = const AuthGate();

  if (segments.length == 1) {
    switch (segments[0]) {
      case 'dashboard':
        page = const DashboardPage();
      case 'courses':
        page = const CoursesPage();
      case 'users':
        page = const UsersPage();
      case 'institutions':
        page = const InstitutionsPage();
      case 'ai':
        page = const AiPage();
      case 'ai-chat':
        page = const AiChatPage();
      case 'ai-history':
        page = const AiHistoryPage();
      case 'quizzes':
        page = const QuizzesPage();
      case 'change-password':
        page = const ChangePasswordPage();
    }
  } else if (segments.length == 2) {
    switch (segments[0]) {
      case 'course':
        page = CoursePage(courseId: segments[1]);
      case 'module':
        page = ModulePage(moduleId: segments[1]);
      case 'quiz':
        page = QuizPage(quizId: segments[1]);
      case 'quiz-review':
        page = QuizReviewPage(quizId: segments[1]);
      case 'ai-practice':
        page = AiPracticeDetailPage(id: segments[1]);
      case 'ai-chat':
        page = AiChatPage(conversationId: segments[1]);
      case 'quiz-new':
        page = QuizEditorPage(courseId: segments[1]);
    }
  } else if (segments.length == 3) {
    switch (segments[0]) {
      case 'quiz-new':
        page = QuizEditorPage(courseId: segments[1], chapterId: segments[2]);
      case 'grade':
        page = GradePage(quizId: segments[1], submissionId: segments[2]);
    }
  }

  return MaterialPageRoute(settings: settings, builder: (_) => page);
}

/// The "/" page: decides where to go.
/// Saved session -> check it with the server -> the person's home page.
/// No session -> sign-in page.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = Session.isLoggedIn;

  @override
  void initState() {
    super.initState();
    if (_checking) _verify();
  }

  Future<void> _verify() async {
    try {
      await ApiService.refreshMe();
    } on ApiException catch (e) {
      // 401 = the saved token is no longer good. Anything else (e.g. server
      // unreachable) keeps the session so a refresh never signs you out by accident.
      if (e.unauthorized) Session.clear();
    } catch (_) {}

    if (!mounted) return;
    if (Session.isLoggedIn) {
      Navigator.pushReplacementNamed(context, Session.homeRoute);
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.darkBrown,
        body: Center(child: CircularProgressIndicator(color: AppColors.cream)),
      );
    }
    return const SignInPage();
  }
}