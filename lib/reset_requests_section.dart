import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'api_service.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// "Password reset requests" card. Shows nothing when there are no requests.
class ResetRequestsSection extends StatefulWidget {
  const ResetRequestsSection({super.key});

  @override
  State<ResetRequestsSection> createState() => _ResetRequestsSectionState();
}

class _ResetRequestsSectionState extends State<ResetRequestsSection> {
  List<ResetRequest> _items = [];
  String? _error;
  String? _busyId; // the request being approved/denied right now

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await PasswordResetApi.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }
  }

  Future<void> _approve(ResetRequest r) async {
    final ok = await confirmDialog(
      context,
      title: 'Approve reset',
      message:
          'This replaces the password of ${r.name} right now with a temporary one. Continue?',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      final result = await PasswordResetApi.approve(r.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _TempPasswordDialog(result: result),
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    _load();
  }

  Future<void> _deny(ResetRequest r) async {
    setState(() => _busyId = r.id);
    try {
      await PasswordResetApi.deny(r.id);
      if (!mounted) return;
      showSnack(context, 'Request denied.');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    _load();
  }

  String _when(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text('Could not load reset requests: $_error',
            style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PASSWORD RESET REQUESTS (${_items.length})',
                style: AppText.sans(size: 12, color: AppColors.title)),
            for (final r in _items) _row(r),
          ],
        ),
      ),
    );
  }

  Widget _row(ResetRequest r) {
    final busy = _busyId == r.id;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(r.name,
                  style: AppText.sans(
                      size: 13, color: Colors.black87, weight: FontWeight.w600)),
              _tag(r.role.toUpperCase()),
            ],
          ),
          Text('${r.email} · requested ${_when(r.requestedAt)}',
              style: AppText.sans(size: 10, color: AppColors.label)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton(
                onPressed: busy ? null : () => _approve(r),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkBrown,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text('APPROVE', style: AppText.sans(size: 10, color: Colors.white)),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => _deny(r),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: Text('DENY', style: AppText.sans(size: 10, color: AppColors.label)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(text, style: AppText.sans(size: 8.5, color: AppColors.label)),
    );
  }
}

/// Shows the temporary password ONCE. The server never shows it again.
class _TempPasswordDialog extends StatelessWidget {
  const _TempPasswordDialog({required this.result});
  final ResetApproval result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardCream,
      title: Text('Temporary password',
          style: AppText.serif(size: 16, color: AppColors.title)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.name} (${result.email})',
                style: AppText.sans(size: 11, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                result.tempPassword,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  letterSpacing: 1.5,
                  color: AppColors.darkBrown,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Shown only once. Tell ${result.name} in person. They must choose a new password at their next sign-in.',
              style: AppText.sans(size: 11, color: Colors.black87),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: result.tempPassword));
            if (context.mounted) showSnack(context, 'Copied.');
          },
          child: Text('Copy', style: AppText.sans(size: 11, color: AppColors.label)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(backgroundColor: AppColors.darkBrown),
          child: Text('DONE', style: AppText.sans(size: 11, color: Colors.white)),
        ),
      ],
    );
  }
}