import 'package:flutter/material.dart';
import 'theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBrown,
      body: Column(
        children: [
          _TopBar(onSignOut: () => Navigator.pushReplacementNamed(context, '/')),
          Expanded(
            child: Row(
              children: [
                const _Sidebar(),
                Expanded(child: _MainArea()),
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
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      color: AppColors.sidebar,
      padding: const EdgeInsets.only(top: 16),
      child: const Column(
        children: [
          _NavItem(icon: Icons.menu_book_rounded, label: 'COURSES', selected: true),
          _NavItem(icon: Icons.smart_toy_rounded, label: 'AI'),
          _NavItem(icon: Icons.help_outline_rounded, label: 'QUIZ', iconColor: Color(0xFFE53935)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.selected = false, this.iconColor});
  final IconData icon;
  final String label;
  final bool selected;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Icon(icon, size: 34, color: iconColor ?? const Color(0xFFE8C9A0)),
          const SizedBox(height: 4),
          Text(label,
              style: AppText.sans(
                  size: 9.5, color: selected ? const Color(0xFFFFD58A) : AppColors.cream)),
        ],
      ),
    );
  }
}

class _MainArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF3E2), Color(0xFFF1E3CC), Color(0xFFE6D2C4)],
        ),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, c) {
                  final narrow = c.maxWidth < 700;
                  final cards = [
                    const _NewsCard(),
                    const _TasksCard(),
                    const _MasteryCard(),
                  ];
                  if (narrow) {
                    return Column(
                      children: [
                        for (final w in cards)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: w)
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[2]),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                const _AiOverview(),
              ],
            ),
          ),
          const Positioned(
            right: 14,
            bottom: 14,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFF2B2B2B),
              child: Text('?', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEWS', style: AppText.sans(size: 11, color: Colors.black87)),
          const SizedBox(height: 8),
          const _NewsRow(tag: 'NEW', title: 'New AI Ethics Course Launched', date: 'Sept. 16, 2026'),
          const _NewsRow(tag: 'EVENT', title: 'STI Carver-Course Fair', date: 'Sept. 22, 2026'),
          const _NewsRow(tag: 'UPDATE', title: 'Quiz in Programming Language', date: 'Sept. 25, 2026'),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.tag, required this.title, required this.date});
  final String tag, title, date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.orange, borderRadius: BorderRadius.circular(5)),
            child: Text(tag, style: AppText.sans(size: 8, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sans(size: 9.5, color: Colors.black87)),
                Text(date, style: AppText.sans(size: 7.5, color: AppColors.orange)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard();

  @override
  Widget build(BuildContext context) {
    const tasks = [
      'Complete Module 3 – Machine Learning\nSept. 19, 2026',
      'Read Handout 1 – AI Ethics Course\nSept. 23, 2026',
      'Quiz in Programming Language\nSept. 25, 2026',
    ];
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TASKS', style: AppText.sans(size: 11, color: Colors.black87)),
          const SizedBox(height: 8),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                        color: AppColors.taskSquare, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.split('\n').first,
                            style: AppText.sans(size: 9.5, color: Colors.black87)),
                        Text(t.split('\n').last,
                            style: AppText.sans(size: 7.5, color: AppColors.orange)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Center(
        child: Text(
          '',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 11, color: Colors.black87),
        ),
      ),
    );
  }
}

class _AiOverview extends StatelessWidget {
  const _AiOverview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.darkBrown,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI OVERVIEW', style: AppText.serif(size: 14, color: AppColors.cream)),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text.rich(
                TextSpan(
                  style: AppText.sans(size: 10.5, color: AppColors.cream),
                  children: [
                    const TextSpan(text: "You're on track this week. You've completed "),
                    TextSpan(text: '2 of 4', style: TextStyle(color: AppColors.orange)),
                    const TextSpan(text: ' tasks and scored an average of '),
                    TextSpan(text: '72%', style: TextStyle(color: AppColors.orange)),
                    const TextSpan(
                        text:
                            ' across all active modules. Your strongest area is Computer Ethics. Focus on Advance SIA this week to improve your overall mastery.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _Chip('Blank - - -'),
              _Chip('Next Goal : Science kename'),
              _Chip('AI Streak : 100 days'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AppText.sans(size: 8, color: Colors.white, weight: FontWeight.w600)),
    ); 
  }
}