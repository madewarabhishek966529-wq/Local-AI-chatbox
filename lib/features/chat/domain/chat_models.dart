enum MessageRole { user, assistant, system }

enum MessageStatus { sending, sent, streaming, failed }

class ChatMessage {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final MessageStatus status;
  final bool favorite;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.favorite = false,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? content,
    MessageStatus? status,
    bool? favorite,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      status: status ?? this.status,
      favorite: favorite ?? this.favorite,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        role: MessageRole.values.byName((json['role'] as String).toLowerCase()),
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: MessageStatus.sent,
        favorite: json['favorite'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'favorite': favorite,
      };
}

class Conversation {
  final String id;
  final String title;
  final DateTime updatedAt;
  final bool pinned;
  final bool archived;
  final bool favorite;
  final String modelName;

  const Conversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.modelName,
    this.pinned = false,
    this.archived = false,
    this.favorite = false,
  });

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? updatedAt,
    bool? pinned,
    bool? archived,
    bool? favorite,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      modelName: modelName,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      favorite: favorite ?? this.favorite,
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        title: json['title'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        modelName: json['modelName'] as String? ?? 'llama3.1:8b',
        pinned: json['pinned'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        favorite: json['favorite'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'modelName': modelName,
        'pinned': pinned,
        'archived': archived,
        'favorite': favorite,
      };
}
