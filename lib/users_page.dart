import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'reset_requests_section.dart';
import 'theme.dart';
import 'ui_kit.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _role = ''; // '' means all
  late Future<List<UserLite>> _future;

  bool get _isAdmin => Session.role == 'admin';

  @override
  void initState() {
    super.initState();
    _future = _isAdmin ? _fetch() : Future.value(<UserLite>[]);
  }

  Future<List<UserLite>> _fetch() =>
      ApiService.users(role: _role.isEmpty ? null : _role);

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  Future<void> _createUser() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );
    if (created != true) return;
    if (!mounted) return;
    showSnack(context, 'User created.');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const AppShell(
        selected: 'users',
        body: PageBody(child: CenteredMessage('Only admins can open this page.')),
      );
    }
    return AppShell(
      selected: 'users',
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                pageTitle('USERS'),
                SizedBox(
                  width: 170,
                  child: SelectBox<String>(
                    value: _role,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(value: 'student', child: Text('Students')),
                      DropdownMenuItem(value: 'instructor', child: Text('Instructors')),
                      DropdownMenuItem(value: 'admin', child: Text('Admins')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _role = v;
                        _future = _fetch();
                      });
                    },
                  ),
                ),
                primaryButton(label: 'CREATE USER', onPressed: _createUser),
              ],
            ),
            const SizedBox(height: 14),
            const ResetRequestsSection(),
            FutureBuilder<List<UserLite>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingBox();
                }
                if (snapshot.hasError) {
                  return CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) return const CenteredMessage('No users found.');
                return Column(
                  children: [for (final u in users) _userRow(u)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _userRow(UserLite u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name,
                      style: AppText.sans(
                          size: 13, color: Colors.black87, weight: FontWeight.w600)),
                  Text(u.email, style: AppText.sans(size: 11, color: Colors.black54)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _tag(u.role.toUpperCase(), filled: false),
                if (u.mustChangePassword) ...[
                  const SizedBox(height: 4),
                  _tag('TEMP PASSWORD', filled: true),
                ],
              ],
            ),
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
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'student';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fill in the name, email and temporary password.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'The temporary password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.createUser(
        name: name,
        email: email,
        password: password,
        role: _role,
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
      title: Text('Create user', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fieldLabel('NAME'),
              inputField(_name, 'Full name'),
              fieldLabel('EMAIL'),
              inputField(_email, 'name@example.com'),
              fieldLabel('TEMPORARY PASSWORD (MIN 6 CHARACTERS)'),
              inputField(_password, 'Temporary password', obscure: true),
              fieldLabel('ROLE'),
              SelectBox<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v),
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