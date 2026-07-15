import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/local_signal.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../providers/chat_providers.dart';
import '../../domain/chat_models.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationListProvider);
    final backendUp = ref.watch(backendReachabilityProvider);

    final visible = conversations.where((c) => !c.archived).where((c) {
      if (_query.isEmpty) return true;
      return c.title.toLowerCase().contains(_query.toLowerCase());
    }).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chats'),
            const SizedBox(width: 10),
            LocalSignalDot(size: 7, active: backendUp),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!backendUp)
            Container(
              width: double.infinity,
              color: AppColors.errorMuted,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                "Local backend unreachable — showing cached chats. New messages will sync once it's back.",
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search chats',
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(onNewChat: _createChat)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final convo = visible[index];
                      return _ConversationTile(conversation: convo);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createChat,
        backgroundColor: AppColors.signal,
        foregroundColor: AppColors.surfaceSunken,
        icon: const Icon(Icons.add),
        label: const Text('New chat'),
      ),
    );
  }

  Future<void> _createChat() async {
    final convo = await ref.read(conversationListProvider.notifier).createConversation();
    if (!mounted) return;
    context.push('/chats/${convo.id}');
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.errorMuted,
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => ref.read(conversationListProvider.notifier).delete(conversation.id),
      child: ListTile(
        onTap: () => context.push('/chats/${conversation.id}'),
        onLongPress: () => _showOptions(context, ref),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceElevated,
          child: Text(
            conversation.title.isNotEmpty ? conversation.title[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.signal, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            if (conversation.pinned) const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.push_pin, size: 13, color: AppColors.amber),
            ),
            Expanded(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
            if (conversation.favorite) const Icon(Icons.star, size: 15, color: AppColors.amber),
          ],
        ),
        subtitle: Text(
          '${conversation.modelName} · ${DateFormat.MMMd().add_jm().format(conversation.updatedAt)}',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(conversationListProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.push_pin_outlined, color: AppColors.textPrimary),
            title: Text(conversation.pinned ? 'Unpin' : 'Pin', style: const TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              notifier.togglePin(conversation.id);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_border, color: AppColors.textPrimary),
            title: Text(conversation.favorite ? 'Unfavorite' : 'Favorite', style: const TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              notifier.toggleFavorite(conversation.id);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined, color: AppColors.textPrimary),
            title: const Text('Archive', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              notifier.toggleArchive(conversation.id);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            title: const Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              _renameDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text('Delete', style: TextStyle(color: AppColors.error)),
            onTap: () {
              notifier.delete(conversation.id);
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  void _renameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Rename chat', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(conversationListProvider.notifier).rename(conversation.id, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewChat;
  const _EmptyState({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LocalSignalDot(size: 12),
            const SizedBox(height: 20),
            Text('No chats yet', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with your local model — nothing is sent anywhere else.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onNewChat, child: const Text('Start chatting')),
          ],
        ),
      ),
    );
  }
}
