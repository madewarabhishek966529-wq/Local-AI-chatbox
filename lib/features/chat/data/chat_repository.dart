import '../../../core/network/dio_client.dart';
import '../../../core/network/sse_client.dart';
import '../domain/chat_models.dart';

class ChatRepository {
  final DioClient _client;
  late final SseClient _sse = SseClient(_client.dio);

  ChatRepository(this._client);

  Future<List<Conversation>> listConversations({bool archived = false, String? search}) async {
    final response = await _client.dio.get('/chat/conversations', queryParameters: {
      'archived': archived,
      if (search != null && search.isNotEmpty) 'search': search,
      'size': 100,
    });
    final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Conversation.fromJson).toList();
  }

  Future<Conversation> createConversation({String? title, String? modelName}) async {
    final response = await _client.dio.post('/chat/conversations', data: {
      if (title != null) 'title': title,
      if (modelName != null) 'modelName': modelName,
    });
    return Conversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Conversation> rename(String id, String title) async {
    final response = await _client.dio.patch('/chat/conversations/$id', data: {'title': title});
    return Conversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Conversation> setPinned(String id, bool value) async {
    final response = await _client.dio.post('/chat/conversations/$id/pin', queryParameters: {'value': value});
    return Conversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Conversation> setArchived(String id, bool value) async {
    final response = await _client.dio.post('/chat/conversations/$id/archive', queryParameters: {'value': value});
    return Conversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Conversation> setFavorite(String id, bool value) async {
    final response = await _client.dio.post('/chat/conversations/$id/favorite', queryParameters: {'value': value});
    return Conversation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _client.dio.delete('/chat/conversations/$id');
  }

  Future<List<ChatMessage>> listMessages(String conversationId, {int page = 0, int size = 50}) async {
    final response = await _client.dio.get(
      '/chat/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'size': size},
    );
    final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ChatMessage.fromJson).toList();
  }

  Future<void> setMessageFavorite(String messageId, bool value) async {
    await _client.dio.post('/messages/$messageId/favorite', queryParameters: {'value': value});
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.dio.delete('/messages/$messageId');
  }

  /// Streams the assistant's reply for a new user message. Emits content
  /// deltas as they arrive; the caller accumulates them for display. The
  /// backend persists both the user message and the completed assistant
  /// reply, so no separate "save" call is needed here.
  Stream<String> streamReply(String conversationId, String content, {List<String>? attachmentIds}) {
    return _sse
        .post(
          '/chat/conversations/$conversationId/stream',
          data: {
            'content': content,
            if (attachmentIds != null) 'attachmentIds': attachmentIds,
          },
        )
        .where((event) => event.event == 'token' || event.event == 'error')
        .map((event) {
      if (event.event == 'error') {
        throw Exception(event.data.isEmpty ? 'Generation failed' : event.data);
      }
      return event.data;
    });
  }

  Future<List<String>> listModels() async {
    final response = await _client.dio.get('/models');
    return (response.data['models'] as List).cast<String>();
  }
}
