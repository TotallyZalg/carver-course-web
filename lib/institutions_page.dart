import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

class InstitutionsPage extends StatefulWidget {
  const InstitutionsPage({super.key});

  @override
  State<InstitutionsPage> createState() => _InstitutionsPageState();
}

class _InstitutionsPageState extends State<InstitutionsPage> {
  late Future<List<Institution>> _future;

  bool get _isOwner => Session.role == 'owner';

  @override
  void initState() {
    super.initState();
    _future = _isOwner ? ApiService.institutions() : Future.value(<Institution>[]);
  }

  void _reload() {
    setState(() {
      _future = ApiService.institutions();
    });
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewInstitutionDialog(),
    );
    if (created != true) return;
    if (!mounted) return;
    showSnack(context, 'Institution created. Give its admin the temporary password.');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner) {
      return const AppShell(
        selected: 'institutions',
        body: PageBody(child: CenteredMessage('Only the platform owner can open this page.')),
      );
    }
    return AppShell(
      selected: 'institutions',
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                pageTitle('INSTITUTIONS'),
                const Spacer(),
                primaryButton(label: 'NEW INSTITUTION', onPressed: _create),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Institution>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingBox();
                }
                if (snapshot.hasError) {
                  return CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const CenteredMessage(
                      'No institutions yet. Click NEW INSTITUTION to create one.');
                }
                return LayoutBuilder(builder: (context, c) {
                  final width = c.maxWidth < 320 ? c.maxWidth : 320.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final i in list) SizedBox(width: width, child: _card(i)),
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

  Widget _card(Institution i) {
    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i.name,
              style: AppText.serif(size: 15, color: AppColors.title, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${i.userCount} user${i.userCount == 1 ? '' : 's'}',
              style: AppText.sans(size: 11, color: AppColors.orange)),
          const SizedBox(height: 2),
          Text(
            i.adminEmail == null ? 'No admin yet' : 'Admin: ${i.adminEmail}',
            style: AppText.sans(size: 10.5, color: AppColors.label),
          ),
        ],
      ),
    );
  }
}

class _NewInstitutionDialog extends StatefulWidget {
  const _NewInstitutionDialog();

  @override
  State<_NewInstitutionDialog> createState() => _NewInstitutionDialogState();
}

class _NewInstitutionDialogState extends State<_NewInstitutionDialog> {
  final _name = TextEditingController();
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPassword = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _adminPassword.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final adminName = _adminName.text.trim();
    final adminEmail = _adminEmail.text.trim();
    final adminPassword = _adminPassword.text;
    if (name.isEmpty || adminName.isEmpty || adminEmail.isEmpty || adminPassword.isEmpty) {
      setState(() => _error = 'Fill in all four fields.');
      return;
    }
    if (adminPassword.length < 6) {
      setState(() => _error = 'The temporary password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.createInstitution(
        name: name,
        adminName: adminName,
        adminEmail: adminEmail,
        adminPassword: adminPassword,
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
      title: Text('New institution', style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fieldLabel('INSTITUTION NAME'),
              inputField(_name, 'e.g. Example College'),
              fieldLabel('FIRST ADMIN NAME'),
              inputField(_adminName, 'Full name'),
              fieldLabel('FIRST ADMIN EMAIL'),
              inputField(_adminEmail, 'admin@example.com'),
              fieldLabel('TEMPORARY PASSWORD (MIN 6 CHARACTERS)'),
              inputField(_adminPassword, 'The admin must change it at first sign-in',
                  obscure: true),
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