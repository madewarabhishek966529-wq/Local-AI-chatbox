import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local_ai_chat/features/auth/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_storage.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

const _uuid = Uuid();

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(dioClientProvider)),
);

/// Conversation list: Hive cache first (instant, works offline), then a
/// background refresh from the backend. Every mutation writes through to
/// both the backend and the cache so a cold start always has something to
/// show.
class ConversationListNotifier extends StateNotifier<List<Conversation>> {
  final ChatRepository repository;
  final Ref ref;

  ConversationListNotifier(this.repository, this.ref)
    : super(_loadFromCache()) {
    refresh();
  }

  static List<Conversation> _loadFromCache() {
    final box = HiveStorage.conversations;
    return box.values
        .map(
          (raw) => Conversation.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw as String)),
          ),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> refresh({bool archived = false, String? search}) async {
    try {
      final conversations = await repository.listConversations(
        archived: archived,
        search: search,
      );
      state = conversations;
      ref.read(backendReachabilityProvider.notifier).markReachable();
      await _cacheAll(conversations);
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
      // keep whatever's already in state (cache or previous fetch)
    }
  }

  Future<void> _cacheAll(List<Conversation> conversations) async {
    final box = HiveStorage.conversations;
    await box.clear();
    for (final c in conversations) {
      await box.put(c.id, jsonEncode(c.toJson()));
    }
  }

  Future<void> _cacheOne(Conversation c) async {
    await HiveStorage.conversations.put(c.id, jsonEncode(c.toJson()));
  }

  Future<Conversation> createConversation({
    String title = 'New chat',
    String? modelName,
  }) async {
    try {
      final convo = await repository.createConversation(
        title: title,
        modelName: modelName,
      );
      state = [convo, ...state];
      await _cacheOne(convo);
      ref.read(backendReachabilityProvider.notifier).markReachable();
      return convo;
    } on DioException catch (e) {
      ref.read(backendReachabilityProvider.notifier).markUnreachable();
      // Fall back to a local-only conversation so the person can still type;
      // it'll be orphaned until proper offline sync lands (see backend README).
      final local = Conversation(
        id: _uuid.v4(),
        title: title,
        updatedAt: DateTime.now(),
        modelName: modelName ?? 'llama3.1:8b',
      );
      state = [local, ...state];
      await _cacheOne(local);
      if (e.error is! OfflineException) rethrow;
      return local;
    }
  }

  Future<void> rename(String id, String title) async {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(title: title) else c,
    ];
    try {
      final updated = await repository.rename(id, title);
      await _cacheOne(updated);
    } catch (_) {
      // optimistic update stands; will reconcile on next refresh()
    }
  }

  Future<void> togglePin(String id) async {
    final target = state.firstWhere((c) => c.id == id);
    final newValue = !target.pinned;
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(pinned: newValue) else c,
    ];
    try {
      await repository.setPinned(id, newValue);
    } catch (_) {}
  }

  Future<void> toggleFavorite(String id) async {
    final target = state.firstWhere((c) => c.id == id);
    final newValue = !target.favorite;
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(favorite: newValue) else c,
    ];
    try {
      await repository.setFavorite(id, newValue);
    } catch (_) {}
  }

  Future<void> toggleArchive(String id) async {
    final target = state.firstWhere((c) => c.id == id);
    final newValue = !target.archived;
    try {
      await repository.setArchived(id, newValue);
    } catch (_) {}
    state = state
        .where((c) => c.id != id)
        .toList(); // leave the active (non-archived) list either way
  }

  Future<void> delete(String id) async {
    state = state.where((c) => c.id != id).toList();
    await HiveStorage.conversations.delete(id);
    try {
      await repository.delete(id);
    } catch (_) {}
  }

  void touch(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(updatedAt: DateTime.now()) else c,
    ];
  }
}

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, List<Conversation>>(
      (ref) => ConversationListNotifier(ref.watch(chatRepositoryProvider), ref),
    );

/// Messages for a single conversation. Loads from Hive cache first, then
/// the backend. Sending a message streams the assistant reply token by
/// token via SSE; once the stream completes we refetch from the backend so
/// message IDs (needed for favorite/delete) are canonical, not local temp
/// IDs.
class ChatSessionNotifier extends StateNotifier<List<ChatMessage>> {
  final String conversationId;
  final ChatRepository repository;
  final Ref ref;
  StreamSubscription<String>? _subscription;

  ChatSessionNotifier(this.conversationId, this.repository, this.ref)
    : super(_loadFromCache(conversationId)) {
    _refreshFromBackend();
  }

  static List<ChatMessage> _loadFromCache(String conversationId) {
    final raw = HiveStorage.messages.get(conversationId) as String?;
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<void> _cache(List<ChatMessage> messages) async {
    final serializable = messages
        .where((m) => m.status != MessageStatus.streaming)
        .toList();
    await HiveStorage.messages.put(
      conversationId,
      jsonEncode(serializable.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _refreshFromBackend() async {
    try {
      final messages = await repository.listMessages(conversationId);
      state = messages;
      ref.read(backendReachabilityProvider.notifier).markReachable();
      await _cache(messages);
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final trimmed = content.trim();

    final optimisticUser = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    final replyId = _uuid.v4();
    final placeholder = ChatMessage(
      id: replyId,
      conversationId: conversationId,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    state = [...state, optimisticUser, placeholder];
    ref.read(conversationListProvider.notifier).touch(conversationId);

    final buffer = StringBuffer();
    _subscription?.cancel();
    _subscription = repository
        .streamReply(conversationId, trimmed)
        .listen(
          (delta) {
            buffer.write(delta);
            state = [
              for (final m in state)
                if (m.id == replyId)
                  m.copyWith(content: buffer.toString())
                else
                  m,
            ];
          },
          onDone: () {
            state = [
              for (final m in state)
                if (m.id == replyId)
                  m.copyWith(status: MessageStatus.sent)
                else
                  m,
            ];
            ref.read(backendReachabilityProvider.notifier).markReachable();
            _refreshFromBackend(); // pick up canonical IDs from the backend
          },
          onError: (err) {
            state = [
              for (final m in state)
                if (m.id == replyId)
                  m.copyWith(
                    status: MessageStatus.failed,
                    content: buffer.toString(),
                  )
                else
                  m,
            ];
            if (err is DioException && err.error is OfflineException) {
              ref.read(backendReachabilityProvider.notifier).markUnreachable();
            }
          },
        );
  }

  void stopGeneration() {
    _subscription?.cancel();
    state = [
      for (final m in state)
        if (m.status == MessageStatus.streaming)
          m.copyWith(status: MessageStatus.sent)
        else
          m,
    ];
  }

  /// Resends the last user message to produce a new reply. The current
  /// backend contract always appends a fresh user turn on `/stream`, so
  /// this creates a new user message rather than truly replacing the last
  /// assistant reply in place — a dedicated `/regenerate` endpoint that
  /// skips that would make this cleaner.
  void regenerateLast() {
    final lastUser = state.lastWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => throw StateError('No user message to regenerate from'),
    );
    sendMessage(lastUser.content);
  }
}

final chatSessionProvider =
    StateNotifierProvider.family<
      ChatSessionNotifier,
      List<ChatMessage>,
      String
    >(
      (ref, conversationId) => ChatSessionNotifier(
        conversationId,
        ref.watch(chatRepositoryProvider),
        ref,
      ),
    );
