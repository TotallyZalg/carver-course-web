import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'sign_in_page.dart';

void main() => runApp(const CarverCourseApp());

class CarverCourseApp extends StatelessWidget {
  const CarverCourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carver - Course',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF8B3A10)),
      initialRoute: '/',
      routes: {
        '/': (_) => const SignInPage(),
        '/dashboard': (_) => const DashboardPage(),
      },
    );
  }
}