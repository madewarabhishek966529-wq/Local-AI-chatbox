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

/// Backend conversation ids are Mongo ObjectIds (24 hex chars, no dashes).
/// Local-only ids are UUID v4 (36 chars, dash-separated). This lets us tell
/// "created while offline, not yet synced" apart from "created online"
/// without needing an extra flag threaded through Hive/state.
bool _isLocalOnlyId(String id) => id.contains('-');

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

  /// Replaces a local-only conversation's temp UUID with its canonical
  /// backend id once it's been synced, in both state and the Hive cache.
  Future<void> remapId(String localId, Conversation synced) async {
    state = [
      for (final c in state)
        if (c.id == localId) synced else c,
    ];
    await HiveStorage.conversations.delete(localId);
    await _cacheOne(synced);
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
  /// The conversation id this session currently talks to. Starts as
  /// whatever id the widget was built with; if that id is a local-only
  /// UUID (created while offline), `sendMessage` remaps it to the
  /// canonical backend id the first time it manages to sync, so
  /// subsequent calls in this session use the real id.
  String conversationId;
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

  /// If this session is still on a local-only id (created while offline)
  /// and the backend is reachable, creates the real conversation on the
  /// backend now and remaps everything — session id, conversation list
  /// state, and the Hive caches for both conversations and messages — onto
  /// the new canonical id. No-ops if already synced or still offline.
  Future<void> _syncOfflineConversationIfNeeded() async {
    if (!_isLocalOnlyId(conversationId)) return;

    final localId = conversationId;
    final listNotifier = ref.read(conversationListProvider.notifier);
    final localMatches = ref
        .read(conversationListProvider)
        .where((c) => c.id == localId);
    final local = localMatches.isEmpty ? null : localMatches.first;

    try {
      final synced = await repository.createConversation(
        title: local?.title,
        modelName: local?.modelName,
      );

      // 1. Conversation list: swap the local entry for the synced one.
      await listNotifier.remapId(localId, synced);

      // 2. Migrate this session's message cache to the new key and update
      //    every already-sent message's conversationId in local state.
      conversationId = synced.id;
      state = [for (final m in state) m.copyWith(conversationId: synced.id)];
      await HiveStorage.messages.delete(localId);
      await _cache(state);

      ref.read(backendReachabilityProvider.notifier).markReachable();
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
      // Stay on the local id; sendMessage will fall back to the normal
      // offline-failure handling below.
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final trimmed = content.trim();

    await _syncOfflineConversationIfNeeded();

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

  Future<void> toggleMessageFavorite(
    String messageId,
    bool currentValue,
  ) async {
    final newValue = !currentValue;
    state = [
      for (final m in state)
        if (m.id == messageId) m.copyWith(favorite: newValue) else m,
    ];
    await _cache(state);
    try {
      await repository.setMessageFavorite(messageId, newValue);
      ref.read(backendReachabilityProvider.notifier).markReachable();
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
      // optimistic update stands; will reconcile on next _refreshFromBackend()
    }
  }

  Future<void> deleteMessage(String messageId) async {
    state = state.where((m) => m.id != messageId).toList();
    await _cache(state);
    try {
      await repository.deleteMessage(messageId);
      ref.read(backendReachabilityProvider.notifier).markReachable();
    } on DioException catch (e) {
      if (e.error is OfflineException) {
        ref.read(backendReachabilityProvider.notifier).markUnreachable();
      }
    }
  }

  /// Regenerates the last assistant reply in place: removes both the last
  /// assistant message and the user prompt that produced it (from the
  /// backend and local state), then re-submits that same prompt via
  /// `sendMessage`. This avoids the duplicate user/assistant turn that
  /// resulted from simply calling `sendMessage` again on top of the
  /// existing history.
  Future<void> regenerateLast() async {
    ChatMessage? lastAssistant;
    ChatMessage? lastUser;
    for (final m in state.reversed) {
      if (lastAssistant == null && m.role == MessageRole.assistant) {
        lastAssistant = m;
        continue;
      }
      if (lastUser == null && m.role == MessageRole.user) {
        lastUser = m;
        break;
      }
    }
    if (lastUser == null) return; // nothing to regenerate from

    final toDelete = [lastUser, if (lastAssistant != null) lastAssistant];
    for (final m in toDelete) {
      try {
        await repository.deleteMessage(m.id);
      } catch (_) {
        // If deletion fails (e.g. offline, or the message was only ever
        // local), still drop it from local state below so we don't end up
        // with a stale duplicate once sendMessage appends the new turn.
      }
    }

    final deleteIds = toDelete.map((m) => m.id).toSet();
    state = state.where((m) => !deleteIds.contains(m.id)).toList();
    await _cache(state);

    await sendMessage(lastUser.content);
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
