import 'package:flutter/material.dart';

import 'api_service.dart';
import 'quiz_schedule.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// The CHATS part of the History tab: the saved AI tutor chats of the student.
class ChatHistorySection extends StatefulWidget {
  const ChatHistorySection({super.key});

  @override
  State<ChatHistorySection> createState() => _ChatHistorySectionState();
}

class _ChatHistorySectionState extends State<ChatHistorySection> {
  late Future<List<ChatSummary>> _future = AiApi.chatHistory();

  void _reload() => setState(() => _future = AiApi.chatHistory());

  Future<void> _delete(ChatSummary c) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete chat',
      message: 'Delete your chat "${c.title}"?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await AiApi.deleteChat(c.id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e));
    }
  }

  Widget _row(ChatSummary c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/ai-chat/${c.id}').then((_) {
            if (mounted) _reload();
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: AppText.sans(size: 13, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                        '${c.moduleTitle} · ${c.messageCount} messages'
                        '${c.updatedAt == null ? '' : ' · ${formatWhen(c.updatedAt!)}'}',
                        style: AppText.sans(size: 10.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(c),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fieldLabel('CHATS'),
        FutureBuilder<List<ChatSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Text('Loading...', style: AppText.sans(size: 11, color: Colors.black54));
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorText(snapshot.error!),
                      style: AppText.sans(size: 11, color: const Color(0xFFB3261E))),
                  TextButton(
                    onPressed: _reload,
                    child: Text('Try again', style: AppText.sans(size: 11, color: AppColors.label)),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Text(
                'No chats yet. Ask the tutor something and the chat will appear here.',
                style: AppText.sans(size: 11, color: Colors.black54),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final c in items) _row(c)],
            );
          },
        ),
      ],
    );
  }
}