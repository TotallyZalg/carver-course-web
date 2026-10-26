import 'package:flutter/material.dart';

import 'api_service.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// Asks "Are you sure?" and only then signs out.
Future<void> confirmSignOut(BuildContext context) async {
  final ok = await confirmDialog(
    context,
    title: 'Sign out',
    message: 'Are you sure you want to sign out?',
    confirmLabel: 'Sign Out',
  );
  if (!ok) return;
  Session.clear();
  navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
}

/// Top bar + sidebar around a page. Also the login guard for every page that uses it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.selected, required this.body});

  final String selected; // 'home', 'courses' or 'users'
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (!Session.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false));
      return const Scaffold(backgroundColor: AppColors.darkBrown);
    }
    if (Session.mustChangePassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) => navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/change-password', (_) => false));
      return const Scaffold(backgroundColor: AppColors.darkBrown);
    }

        // The owner only has the institutions page
    if (Session.role == 'owner' && selected != 'institutions') {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/institutions', (_) => false));
      return const Scaffold(backgroundColor: AppColors.darkBrown);
    }

    return Scaffold(
      backgroundColor: AppColors.darkBrown,
      body: Column(
        children: [
          _TopBar(onSignOut: () => confirmSignOut(context)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(selected: selected),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: AppColors.darkBrown,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text('CARVER - COURSE',
              style: AppText.serif(size: 20, color: AppColors.cream, spacing: 0.5)),
          const Spacer(),
          Text('${Session.name ?? ''} · ${(Session.role ?? '').toUpperCase()}',
              style: AppText.sans(size: 11, color: AppColors.cream)),
          const SizedBox(width: 12),
          SizedBox(
            height: 26,
            child: FilledButton(
              onPressed: onSignOut,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text('Sign Out', style: AppText.sans(size: 11, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected});
  final String selected;

  /// Opens a page, unless we are already on it.
  void _go(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current != route) Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final role = Session.role;
    final items = <Widget>[];

    if (role == 'owner') {
      items.add(_NavItem(
        icon: Icons.apartment_rounded,
        label: 'INSTITUTIONS',
        selected: selected == 'institutions',
        onTap: () => _go(context, '/institutions'),
      ));
    } else {
      items.addAll([
        _NavItem(
          icon: Icons.home_rounded,
          label: 'HOME',
          selected: selected == 'home',
          onTap: () => _go(context, '/dashboard'),
        ),
        _NavItem(
          icon: Icons.menu_book_rounded,
          label: 'COURSES',
          selected: selected == 'courses',
          onTap: () => _go(context, '/courses'),
        ),
        if (role == 'admin')
          _NavItem(
            icon: Icons.people_alt_rounded,
            label: 'USERS',
            selected: selected == 'users',
            onTap: () => _go(context, '/users'),
          ),
        if (role == 'student')
          _NavItem(
            icon: Icons.smart_toy_rounded,
            label: 'AI',
            onTap: () => showSnack(context, 'Coming in the next update'),
          ),
        _NavItem(
          icon: Icons.help_outline_rounded,
          label: 'QUIZ',
          iconColor: const Color(0xFFE53935),
          onTap: () => showSnack(context, 'Coming in the next update'),
        ),
      ]);
    }

    return Container(
      width: 90,
      color: AppColors.sidebar,
      padding: const EdgeInsets.only(top: 16),
      child: SingleChildScrollView(child: Column(children: items)),
    );
  }
}

  class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18, top: 2),
          child: Column(
            children: [
              Icon(icon, size: 34, color: iconColor ?? const Color(0xFFE8C9A0)),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppText.sans(
                  size: 9.5,
                  color: selected ? const Color(0xFFFFD58A) : AppColors.cream,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}