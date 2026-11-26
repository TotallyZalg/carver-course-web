import 'package:flutter/material.dart';

import 'api_service.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// Opens the "Forgot password?" pop-up (used by the sign-in page).
Future<void> showForgotPasswordDialog(BuildContext context, {String email = ''}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(initialEmail: email),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  String? _error;
  String? _done; // the server's reply, shown after sending

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await PasswordResetApi.request(email);
      if (!mounted) return;
      setState(() => _done = message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text('Forgot password?',
          style: AppText.serif(size: 18, color: AppColors.title)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_done != null) ...[
              Text(_done!, style: AppText.sans(size: 11, color: Colors.black87)),
              const SizedBox(height: 8),
              Text('Your administrator will give you a temporary password in person.',
                  style: AppText.sans(size: 11, color: Colors.black87)),
            ] else ...[
              Text(
                'Enter your account email. Your administrator will be asked to reset your password.',
                style: AppText.sans(size: 11, color: Colors.black87),
              ),
              fieldLabel('EMAIL'),
              inputField(_email, 'Your email', onSubmitted: (_) => _send()),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_done == null ? 'Cancel' : 'Close',
              style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        if (_done == null)
          FilledButton(
            onPressed: _loading ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: AppColors.darkBrown),
            child: _loading
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('SEND REQUEST', style: AppText.sans(size: 11, color: Colors.white)),
          ),
      ],
    );
  }
}