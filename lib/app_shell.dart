import 'package:flutter/material.dart';

import 'api_service.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// Below this width (phones) the sidebar becomes a slide-out menu.
const double kCompactWidth = 700;

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

/// One button of the menu (used by the desktop sidebar and the phone drawer).
class _NavEntry {
  const _NavEntry(this.key, this.route, this.icon, this.label, {this.iconColor});
  final String key; // matches AppShell.selected
  final String route;
  final IconData icon;
  final String label;
  final Color? iconColor;
}

List<_NavEntry> _navEntries() {
  final role = Session.role;
  if (role == 'owner') {
    return [
      _NavEntry('institutions', '/institutions', Icons.apartment_rounded, 'INSTITUTIONS'),
    ];
  }
  return [
    _NavEntry('home', '/dashboard', Icons.home_rounded, 'HOME'),
    _NavEntry('courses', '/courses', Icons.menu_book_rounded, 'COURSES'),
    if (role == 'admin')
      _NavEntry('users', '/users', Icons.people_alt_rounded, 'USERS'),
    if (role == 'student')
      _NavEntry('ai', '/ai', Icons.smart_toy_rounded, 'AI'),
    _NavEntry('quizzes', '/quizzes', Icons.help_outline_rounded, 'QUIZ',
        iconColor: const Color(0xFFE53935)),
  ];
}

/// Top bar + sidebar around a page. Also the login guard for every page that uses it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.selected, required this.body});

  final String selected; // 'home', 'courses', 'users', ...
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

    final compact = MediaQuery.of(context).size.width < kCompactWidth;

    // Phone: slide-out menu (drawer), Sign Out lives inside it
    if (compact) {
      return Scaffold(
        backgroundColor: AppColors.darkBrown,
        drawer: _NavDrawer(
          selected: selected,
          pageContext: context,
          pageRoute: ModalRoute.of(context)?.settings.name,
        ),
        body: Column(
          children: [
            const _CompactTopBar(),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Desktop: top bar + fixed sidebar (as before)
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

/// Phone top bar: menu button + title.
class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => Container(
        height: 52,
        color: AppColors.darkBrown,
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded, color: AppColors.cream),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
            Expanded(
              child: Text(
                'CARVER - COURSE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.serif(size: 18, color: AppColors.cream, spacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone menu: name, the same buttons as the sidebar, and Sign Out.
class _NavDrawer extends StatelessWidget {
  const _NavDrawer({
    required this.selected,
    required this.pageContext,
    required this.pageRoute,
  });

  final String selected;
  final BuildContext pageContext; // the page behind the drawer
  final String? pageRoute;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Session.name ?? '',
                      style: AppText.serif(size: 18, color: AppColors.cream)),
                  const SizedBox(height: 4),
                  Text((Session.role ?? '').toUpperCase(),
                      style: AppText.sans(size: 11, color: const Color(0xFFE8C9A0))),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final e in _navEntries())
                    ListTile(
                      leading: Icon(e.icon,
                          size: 28, color: e.iconColor ?? const Color(0xFFE8C9A0)),
                      title: Text(
                        e.label,
                        style: AppText.sans(
                          size: 13,
                          color: selected == e.key
                              ? const Color(0xFFFFD58A)
                              : AppColors.cream,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop(); // close the drawer first
                        if (pageRoute != e.route) {
                          Navigator.of(pageContext).pushReplacementNamed(e.route);
                        }
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  size: 28, color: Color(0xFFE8C9A0)),
              title: Text('SIGN OUT',
                  style: AppText.sans(size: 13, color: AppColors.cream)),
              onTap: () {
                Navigator.of(context).pop();
                confirmSignOut(pageContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    final items = <Widget>[
      for (final e in _navEntries())
        _NavItem(
          icon: e.icon,
          label: e.label,
          iconColor: e.iconColor,
          selected: selected == e.key,
          onTap: () => _go(context, e.route),
        ),
    ];

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