
import 'package:supabase_flutter/supabase_flutter.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final MessageStatus status;
  final List<MessageRead> readBy;
  final List<MessageReaction> reactions;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.status = MessageStatus.sent,
    this.readBy = const [],
    this.reactions = const [],
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    final messageReads = map['message_reads'] as List<dynamic>? ?? [];
    final readBy = messageReads
        .map((read) => MessageRead.fromMap(read as Map<String, dynamic>))
        .toList();

    final messageReactions = map['message_reactions'] as List<dynamic>? ?? [];
    final reactions = messageReactions
        .map((reaction) => MessageReaction.fromMap(reaction as Map<String, dynamic>))
        .toList();

    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      isEdited: map['is_edited'] as bool? ?? false,
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${map['status']}',
        orElse: () => MessageStatus.sent,
      ),
      readBy: readBy,
      reactions: reactions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'type': type.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_edited': isEdited,
      'status': status.toString().split('.').last,
    };
  }

  bool get isReadByCurrentUser {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && readBy.any((read) => read.userId == currentUserId);
  }

  bool get isReadByAllRecipients {
    // This would need conversation participants info
    // For now, just check if read by anyone other than sender
    return readBy.isNotEmpty;
  }
  
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    MessageStatus? status,
    List<MessageRead>? readBy,
    List<MessageReaction>? reactions,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      reactions: reactions ?? this.reactions,
    );
  }
}

enum MessageType {
  text,
  image,
  file,
  audio,
  video,
  call,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum CallEventType {
  missed,
  answered,
  ended,
  declined,
  noAnswer,
}

class MessageRead {
  final String userId;
  final DateTime readAt;

  MessageRead({
    required this.userId,
    required this.readAt,
  });

  factory MessageRead.fromMap(Map<String, dynamic> map) {
    return MessageRead(
      userId: map['user_id'] as String,
      readAt: DateTime.parse(map['read_at'] as String),
    );
  }
}

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    return MessageReaction(
      id: map['id'] as String,
      messageId: map['message_id'] as String,
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}