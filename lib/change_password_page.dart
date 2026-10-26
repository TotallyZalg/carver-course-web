import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _current.text;
    final next = _new.text;
    final confirm = _confirm.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Fill in all three fields.');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'The new password must be at least 8 characters.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'The new passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.changePassword(current, next);
      if (!mounted) return;
            Navigator.pushReplacementNamed(context, Session.homeRoute);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false));
      return const Scaffold(backgroundColor: AppColors.darkBrown);
    }
    return Scaffold(
      body: PageBody(
        scroll: false,
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: CardBox(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pageTitle('CHANGE PASSWORD'),
                    const SizedBox(height: 6),
                    Text(
                      Session.mustChangePassword
                          ? 'Your account uses a temporary password. Choose a new one to continue.'
                          : 'Choose a new password.',
                      style: AppText.sans(size: 11, color: Colors.black87),
                    ),
                    fieldLabel('CURRENT OR TEMPORARY PASSWORD'),
                    inputField(_current, 'Current password', obscure: true),
                    fieldLabel('NEW PASSWORD (MIN 8 CHARACTERS)'),
                    inputField(_new, 'New password', obscure: true),
                    fieldLabel('CONFIRM NEW PASSWORD'),
                    inputField(_confirm, 'Repeat the new password',
                        obscure: true, onSubmitted: (_) => _submit()),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
                    ],
                    const SizedBox(height: 18),
                    primaryButton(label: 'SAVE PASSWORD', onPressed: _submit, loading: _loading),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => confirmSignOut(context),
                        child: Text('Sign Out',
                            style: AppText.sans(size: 11, color: AppColors.label)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}