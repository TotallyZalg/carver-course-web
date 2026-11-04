import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// The tabs at the top of the AI pages. [current] is 'practice', 'chat' or 'history'.
class AiTabs extends StatelessWidget {
  const AiTabs({super.key, required this.current});

  final String current;

  Widget _tab(BuildContext context, String label, String name, String route) {
    final selected = current == name;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.darkBrown : null,
        disabledBackgroundColor: selected ? AppColors.darkBrown : null,
        side: const BorderSide(color: AppColors.darkBrown),
      ),
      onPressed: selected ? null : () => Navigator.pushReplacementNamed(context, route),
      child: Text(
        label,
        style: AppText.sans(size: 11, color: selected ? AppColors.cream : AppColors.darkBrown),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _tab(context, 'PRACTICE QUIZ', 'practice', '/ai'),
        _tab(context, 'ASK THE TUTOR', 'chat', '/ai-chat'),
        _tab(context, 'HISTORY', 'history', '/ai-history'),
      ],
    );
  }
}

class _Msg {
  _Msg(this.fromStudent, this.text);

  final bool fromStudent;
  final String text;
}

const int _maxChatMessages = 40; // the same limit as the server

/// Chat with the AI tutor about one module (students). Chats are saved on the server.
/// With a [conversationId] it opens a saved chat so it can be continued.
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key, this.conversationId});

  final String? conversationId;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  Future<List<Course>>? _coursesFuture; // new chat only
  final _input = TextEditingController();
  final _endKey = GlobalKey();

  String? _courseId;
  List<ModuleItem> _modules = [];
  String? _moduleId;
  bool _loadingModules = false;

  String? _conversationId; // null until the first answer is saved
  String _heading = ''; // saved chat: "Course · Module"
  bool _loadingChat = false;
  bool _readOnly = false; // the module was deleted

  final List<_Msg> _messages = [];
  bool _sending = false;
  String? _error;

  bool get _isStudent => Session.role == 'student';
  bool get _existing => widget.conversationId != null;
  bool get _full => _messages.length + 2 > _maxChatMessages;

  @override
  void initState() {
    super.initState();
    if (!_isStudent) return;
    _conversationId = widget.conversationId;
    if (_existing) {
      _loadingChat = true;
      _loadExisting(widget.conversationId!);
    } else {
      _coursesFuture = ApiService.courses();
      // pick the first course so the module list fills in
      _coursesFuture!.then((list) {
        if (mounted && list.isNotEmpty) _pickCourse(list.first.id);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadExisting(String id) async {
    try {
      final d = await AiApi.chatDetail(id);
      if (!mounted) return;
      setState(() {
        _heading = '${d.courseTitle} · ${d.moduleTitle}';
        _moduleId = d.moduleId;
        _readOnly = d.moduleId == null;
        _messages
          ..clear()
          ..addAll([for (final m in d.messages) _Msg(m.role == 'student', m.text)]);
        _loadingChat = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loadingChat = false;
      });
    }
  }

  Future<void> _pickCourse(String id) async {
    setState(() {
      _courseId = id;
      _modules = [];
      _moduleId = null;
      _loadingModules = true;
      _conversationId = null;
      _messages.clear();
      _error = null;
    });
    try {
      final modules = await ApiService.courseModules(id);
      if (!mounted || _courseId != id) return;
      setState(() {
        _modules = modules;
        _moduleId = modules.isEmpty ? null : modules.first.id;
        _loadingModules = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loadingModules = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _endKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200));
      }
    });
  }

  void _newChat() {
    if (_existing) {
      Navigator.pushReplacementNamed(context, '/ai-chat');
    } else {
      setState(() {
        _conversationId = null;
        _messages.clear();
        _error = null;
      });
    }
  }

  Future<void> _send() async {
    final id = _moduleId;
    final text = _input.text.trim();
    if (id == null || text.isEmpty || _sending || _full) return;

    setState(() {
      _messages.add(_Msg(true, text));
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final reply = await AiApi.chat(id, text, conversationId: _conversationId);
      if (!mounted || _moduleId != id) return;
      setState(() {
        _conversationId = reply.conversationId;
        _messages.add(_Msg(false, reply.reply));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      // put the question back in the box so the student can send it again
      setState(() {
        if (_messages.isNotEmpty && _messages.last.fromStudent) _messages.removeLast();
        _input.text = text;
        _error = errorText(e);
        _sending = false;
      });
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'ai',
      body: PageBody(
        child: !_isStudent
            ? const CenteredMessage('The AI page is for students.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pageTitle('AI STUDY HELPER'),
                  const SizedBox(height: 8),
                  const AiTabs(current: 'chat'),
                  const SizedBox(height: 10),
                  Text(
                    'Ask the AI tutor about a module. It answers from your handout only, and AI can '
                    'make mistakes. Your chats are saved in the History tab (the newest 20 are kept) '
                    'and only you can see them.',
                    style: AppText.sans(size: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  if (_existing) _existingBody() else _newChatBody(),
                ],
              ),
      ),
    );
  }

  // ----- a saved chat -----

  Widget _existingBody() {
    if (_loadingChat) return const LoadingBox();
    if (_error != null && _messages.isEmpty) return CenteredMessage(_error!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardBox(
          padding: const EdgeInsets.all(16),
          child: Text(_heading, style: AppText.serif(size: 16, color: AppColors.title)),
        ),
        const SizedBox(height: 12),
        _conversation(),
      ],
    );
  }

  // ----- a new chat -----

  Widget _newChatBody() {
    return FutureBuilder<List<Course>>(
      future: _coursesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingBox();
        if (snapshot.hasError) return CenteredMessage(errorText(snapshot.error!));
        final courses = snapshot.data ?? [];
        if (courses.isEmpty) {
          return const CenteredMessage('You are not enrolled in any course yet.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fieldLabel('COURSE'),
                  SelectBox<String>(
                    value: _courseId ?? courses.first.id,
                    items: [
                      for (final c in courses) DropdownMenuItem(value: c.id, child: Text(c.title)),
                    ],
                    onChanged: _pickCourse,
                  ),
                  fieldLabel('MODULE'),
                  if (_loadingModules)
                    Text('Loading modules...',
                        style: AppText.sans(size: 11, color: Colors.black54))
                  else if (_modules.isEmpty)
                    Text('This course has no modules yet.',
                        style: AppText.sans(size: 11, color: Colors.black54))
                  else
                    SelectBox<String>(
                      value: _moduleId ?? _modules.first.id,
                      items: [
                        for (final m in _modules)
                          DropdownMenuItem(value: m.id, child: Text(m.title)),
                      ],
                      onChanged: (v) => setState(() {
                        _moduleId = v;
                        _conversationId = null; // a new module starts a new chat
                        _messages.clear();
                        _error = null;
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _conversation(),
          ],
        );
      },
    );
  }

  // ----- the messages and the box to write in (both modes) -----

  Widget _conversation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_messages.isEmpty && !_sending && !_existing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Ask anything about this module, for example: "Explain the main idea in simple words."',
              style: AppText.sans(size: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        for (final m in _messages) _bubble(m),
        if (_sending)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Tutor is thinking...', style: AppText.sans(size: 11, color: Colors.black54)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
          ),
        if (_readOnly)
          Text(
            'This module no longer exists, so this chat is read only.',
            style: AppText.sans(size: 11, color: Colors.black54),
          )
        else if (_full)
          Text(
            'This chat is full ($_maxChatMessages messages). Press NEW CHAT to keep asking.',
            style: AppText.sans(size: 11, color: Colors.black54),
          )
        else ...[
          inputField(_input, 'Ask a question about this module', minLines: 1, maxLines: 4),
          const SizedBox(height: 8),
          Row(
            children: [
              primaryButton(
                label: 'SEND',
                loading: _sending,
                onPressed: _moduleId == null ? null : _send,
              ),
              const SizedBox(width: 8),
              if (_messages.isNotEmpty)
                TextButton(
                  onPressed: _sending ? null : _newChat,
                  child: Text('NEW CHAT', style: AppText.sans(size: 11, color: AppColors.label)),
                ),
            ],
          ),
        ],
        if ((_readOnly || _full) && _messages.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _newChat,
              child: Text('NEW CHAT', style: AppText.sans(size: 11, color: AppColors.label)),
            ),
          ),
        SizedBox(key: _endKey, height: 20),
      ],
    );
  }

  Widget _bubble(_Msg m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: m.fromStudent ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: m.fromStudent ? AppColors.darkBrown : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              m.text,
              style: AppText.sans(
                size: 12,
                color: m.fromStudent ? AppColors.cream : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}