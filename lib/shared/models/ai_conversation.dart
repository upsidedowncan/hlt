import 'ai_message.dart';

class AiConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiMessage> messages;

  AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory AiConversation.fromMap(Map<String, dynamic> map) {
    return AiConversation(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      messages: (map['messages'] as List?)
          ?.map((message) => AiMessage.fromMap(message))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((message) => message.toMap()).toList(),
    };
  }

  AiConversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiMessage>? messages,
  }) {
    return AiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, String> getApiMessages() {
    return messages
        .where((msg) => !msg.isStreaming)
        .map((msg) => msg.toApiMessage())
        .fold({}, (map, msg) => map);
  }

  List<Map<String, String>> getApiMessagesList() {
    return messages
        .where((msg) => !msg.isStreaming)
        .map((msg) => msg.toApiMessage())
        .toList();
  }
}