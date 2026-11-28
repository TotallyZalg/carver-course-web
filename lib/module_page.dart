import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

import 'pdf_actions.dart';

class ModulePage extends StatefulWidget {
  const ModulePage({super.key, required this.moduleId});

  final String moduleId;

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  late Future<ModuleItem> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.module(widget.moduleId);
  }

  void _reload() {
    setState(() {
      _future = ApiService.module(widget.moduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'courses',
      body: PageBody(
        child: FutureBuilder<ModuleItem>(
          future: _future,
          builder: (context, snapshot) {
            final loaded = snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError;
            final fallback = loaded && snapshot.data!.courseId.isNotEmpty
                ? '/course/${snapshot.data!.courseId}'
                : '/courses';

            Widget content;
            if (snapshot.connectionState != ConnectionState.done) {
              content = const LoadingBox();
            } else if (snapshot.hasError) {
              content = CenteredMessage(errorText(snapshot.error!), onRetry: _reload);
            } else {
              content = _content(snapshot.data!);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => goBack(context, fallback),
                    icon: const Icon(Icons.arrow_back_rounded,
                        size: 16, color: AppColors.label),
                    label: Text('BACK', style: AppText.sans(size: 11, color: AppColors.label)),
                  ),
                ),
                const SizedBox(height: 6),
                content,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(ModuleItem module) {
    final handout = CardBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(module.courseTitle.toUpperCase(),
              style: AppText.sans(size: 10, color: AppColors.orange)),
          const SizedBox(height: 4),
          Text(module.title, style: AppText.serif(size: 22, color: AppColors.title)),
          if (module.fileId != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => openPdf(context, module.fileId!),
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    size: 18, color: AppColors.label),
                label: Text(module.fileName ?? 'Open PDF',
                    style: AppText.sans(size: 11, color: AppColors.label)),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/pdf/${module.fileId}'),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text('READ IN APP (TEST)',
                    style: AppText.sans(size: 11, color: Colors.white)),
                style: FilledButton.styleFrom(backgroundColor: AppColors.darkBrown),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (module.content.trim().isEmpty)
            Text(module.fileId != null
                ? 'The handout for this module is the attached PDF.'
                : 'This module has no handout text yet.',
                style: AppText.sans(size: 12, color: Colors.black54))
          else
            SelectableText(
              module.content,
              style: AppText.sans(size: 13, color: Colors.black87).copyWith(height: 1.5),
            ),
        ],
      ),
    );

    // Only students get the AI tutor panel.
    if (Session.role != 'student') return handout;

    final panel = _AiPanel(
      key: ValueKey(module.id),
      moduleId: module.id,
      hasText: module.content.trim().length >= 20 || module.fileId != null,
    );

    final wide = MediaQuery.of(context).size.width >= 900;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: handout),
          const SizedBox(width: 14),
          SizedBox(width: 330, child: panel),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [handout, const SizedBox(height: 14), panel],
    );
  }
}

class _AiPanel extends StatefulWidget {
  const _AiPanel({super.key, required this.moduleId, required this.hasText});

  final String moduleId;
  final bool hasText; // true when the module has handout text or a PDF

  @override
  State<_AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<_AiPanel> {
  // Remembers results while the app is open, so reopening a module is instant.
  static final Map<String, AiReview> _cache = {};

  bool _enabled = Session.aiTutorEnabled;
  bool _switching = false;
  bool _loading = false;
  String? _error;
  AiReview? _review;

  @override
  void initState() {
    super.initState();
    if (_enabled && widget.hasText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await ApiService.aiReview(widget.moduleId);
      _cache[widget.moduleId] = review;
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _switching = true);
    try {
      await ApiService.setAiTutor(value);
      if (!mounted) return;
      setState(() {
        _enabled = value;
        _switching = false;
      });
      if (value && widget.hasText && _review == null) _generate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _switching = false);
      showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('AI TUTOR',
                    style: AppText.serif(size: 14, color: AppColors.title)),
              ),
              Switch(
                value: _enabled,
                onChanged: _switching ? null : _toggle,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.sidebar,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _body(),
          if (_enabled && widget.hasText) ...[
            const SizedBox(height: 14),
            Text(
              'AI notes can contain mistakes. Check them against the handout.',
              style: AppText.sans(size: 9.5, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    if (!_enabled) {
      return Text(
        'The AI tutor is off. Turn it on to see a summary, keywords and key statements for this module.',
        style: AppText.sans(size: 11, color: Colors.black87),
      );
    }
    if (!widget.hasText) {
      return Text(
        'Nothing to review yet. This module has no handout text or PDF.',
        style: AppText.sans(size: 11, color: Colors.black87),
      );
    }
    if (_loading) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sidebar),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reading the handout… The first time can take up to a minute when there is a PDF.',
              style: AppText.sans(size: 11, color: Colors.black87),
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _generate,
            child: Text('Try again', style: AppText.sans(size: 11, color: AppColors.label)),
          ),
        ],
      );
    }
    final review = _review;
    if (review == null) return const SizedBox.shrink();
    if (review.summary.isEmpty && review.keywords.isEmpty && review.keyStatements.isEmpty) {
      return Text('The AI returned no notes for this module.',
          style: AppText.sans(size: 11, color: Colors.black87));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.summary.isNotEmpty) ...[
          Text('SUMMARY', style: AppText.sans(size: 10.5, color: AppColors.label)),
          const SizedBox(height: 6),
          Text(review.summary, style: AppText.sans(size: 11.5, color: Colors.black87)),
          const SizedBox(height: 14),
        ],
        if (review.keywords.isNotEmpty) ...[
          Text('KEYWORDS', style: AppText.sans(size: 10.5, color: AppColors.label)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in review.keywords)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(k,
                      style: AppText.sans(
                          size: 10, color: Colors.white, weight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (review.keyStatements.isNotEmpty) ...[
          Text('KEY STATEMENTS', style: AppText.sans(size: 10.5, color: AppColors.label)),
          const SizedBox(height: 6),
          for (final s in review.keyStatements)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: AppText.sans(size: 11, color: AppColors.orange)),
                  Expanded(
                    child: Text(s, style: AppText.sans(size: 11, color: Colors.black87)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}