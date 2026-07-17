import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/local_signal.dart';
import '../../domain/chat_models.dart';
import '../../providers/chat_providers.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatSessionProvider(widget.conversationId));
    final notifier = ref.read(chatSessionProvider(widget.conversationId).notifier);
    final isGenerating = messages.isNotEmpty && messages.last.status == MessageStatus.streaming;

    ref.listen(chatSessionProvider(widget.conversationId), (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    final conversations = ref.watch(conversationListProvider);
    final conversation = conversations.where((c) => c.id == widget.conversationId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              conversation?.title ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (conversation != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: LocalSignalBadge(label: conversation.modelName),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Say something to your local model.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return MessageBubble(
                        message: message,
                        onRegenerate: notifier.regenerateLast,
                        onFavorite: () => notifier.toggleMessageFavorite(message.id, message.favorite),
                        onDelete: () => notifier.deleteMessage(message.id),
                      );
                    },
                  ),
          ),
          ChatInputBar(
            isGenerating: isGenerating,
            onSend: notifier.sendMessage,
            onStop: notifier.stopGeneration,
            onAttach: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File upload lands with the backend /files endpoint.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
