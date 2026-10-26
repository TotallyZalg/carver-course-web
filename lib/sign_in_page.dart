import 'package:flutter/material.dart';

import 'api_service.dart';
import 'theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _pass.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.login(email, password);
      if (!mounted) return;
            Navigator.pushReplacementNamed(context, Session.homeRoute);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD9A021),
              Color(0xFFC98A12),
              Color(0xFFD2B070),
              Color(0xFFB57A3C),
              Color(0xFF8E5A33),
            ],
            stops: [0.0, 0.3, 0.55, 0.8, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CARVER - COURSE',
                    style: AppText.serif(size: 44, color: AppColors.title, spacing: 1)),
                const SizedBox(height: 2),
                Text('LEARN · GROW · SUCCEED',
                    style: AppText.serif(size: 15, color: AppColors.title, spacing: 2)),
                const SizedBox(height: 70),
                _formCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard() {
    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
      decoration: BoxDecoration(
        color: AppColors.formCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Text('SIGN IN', style: AppText.serif(size: 20, color: AppColors.title))),
          const SizedBox(height: 22),
          _label('EMAIL'),
          _field(_email, 'Enter your email'),
          const SizedBox(height: 14),
          _label('PASSWORD'),
          _field(_pass, 'Enter your password', obscure: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppText.sans(size: 10.5, color: const Color(0xFFB3261E))),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FilledButton(
              onPressed: _loading ? null : _signIn,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkBrown,
                shape: const RoundedRectangleBorder(),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('SIGN IN', style: AppText.sans(size: 11, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text("Accounts are created by your institution's admin.",
                style: AppText.sans(size: 11, color: AppColors.darkBrown)),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 3),
        child: Text(t, style: AppText.sans(size: 10.5, color: AppColors.label)),
      );

  Widget _field(TextEditingController c, String hint, {bool obscure = false}) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: AppText.sans(size: 11, color: AppColors.darkBrown),
        onSubmitted: (_) => _signIn(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.sans(size: 10, color: Colors.grey.shade500),
          filled: true,
          fillColor: AppColors.inputFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF6B5B4B)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF6B5B4B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.label, width: 1.5),
          ),
        ),
      ),
    );
  }
}