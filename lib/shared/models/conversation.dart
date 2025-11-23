

class Conversation {
  final String id;
  final String? name;
  final String? avatarUrl;
  final bool isGroup;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final List<String> participantIds;
  final String? createdBy;

  Conversation({
    required this.id,
    this.name,
    this.avatarUrl,
    this.isGroup = false,
    required this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.lastMessage,
    this.participantIds = const [],
    this.createdBy,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isGroup: map['is_group'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
      lastMessageAt: map['last_message_at'] != null 
          ? DateTime.parse(map['last_message_at'] as String) 
          : null,
      lastMessage: map['last_message'] as String?,
      participantIds: List<String>.from(map['participant_ids'] as List? ?? []),
      createdBy: map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'is_group': isGroup,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message': lastMessage,
      'participant_ids': participantIds,
      'created_by': createdBy,
    };
  }

  Conversation copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isGroup,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    List<String>? participantIds,
    String? createdBy,
  }) {
    return Conversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      participantIds: participantIds ?? this.participantIds,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}