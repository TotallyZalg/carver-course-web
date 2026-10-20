import 'package:flutter/material.dart';
import 'theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _signIn() {
    Navigator.pushReplacementNamed(context, '/dashboard');
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
          _label('USERNAME'),
          _field(_user, 'Enter your username'),
          const SizedBox(height: 14),
          _label('PASSWORD'),
          _field(_pass, 'Enter your password', obscure: true),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FilledButton(
              onPressed: _signIn,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkBrown,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text('SIGN IN', style: AppText.sans(size: 11, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Don't have an account? ",
                    style: AppText.sans(size: 11, color: AppColors.darkBrown)),
                InkWell(
                  onTap: () {},
                  child: Text('Register',
                      style: AppText.sans(size: 11, color: AppColors.darkBrown)
                          .copyWith(decoration: TextDecoration.underline)),
                ),
              ],
            ),
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