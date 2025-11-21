class AiMessage {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;
  final bool isStreaming;
  final bool? isThinking;
  final String? reasoning_content;
  final String? visualizationCode;

  AiMessage({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
    this.isStreaming = false,
    this.isThinking = false,
    this.reasoning_content,
    this.visualizationCode,
  });

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'] as String,
      content: map['content'] as String,
      isFromUser: map['isFromUser'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isStreaming: map['isStreaming'] as bool? ?? false,
      isThinking: map['isThinking'] as bool?,
      reasoning_content: map['reasoning_content'] as String?,
      visualizationCode: map['visualizationCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isFromUser': isFromUser,
      'timestamp': timestamp.toIso8601String(),
      'isStreaming': isStreaming,
      'isThinking': isThinking ?? false,
      'reasoning_content': reasoning_content,
      'visualizationCode': visualizationCode,
    };
  }

  AiMessage copyWith({
    String? id,
    String? content,
    bool? isFromUser,
    DateTime? timestamp,
    bool? isStreaming,
    bool? isThinking,
    String? reasoning_content,
    String? visualizationCode,
  }) {
    return AiMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isFromUser: isFromUser ?? this.isFromUser,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      isThinking: isThinking ?? this.isThinking,
      reasoning_content: reasoning_content ?? this.reasoning_content,
      visualizationCode: visualizationCode ?? this.visualizationCode,
    );
  }

  Map<String, String> toApiMessage() {
    return {
      'role': isFromUser ? 'user' : 'assistant',
      'content': content,
    };
  }
}