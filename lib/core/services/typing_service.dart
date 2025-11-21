import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class TypingService {
  static final SupabaseClient _client = Supabase.instance.client;
  static Timer? _typingTimer;
  static const Duration _typingTimeout = Duration(seconds: 3);

  static Stream<bool> getTypingStatus(String conversationId, String userId) {
    return _client
        .from('typing_status')
        .stream(primaryKey: ['conversation_id'])
        .eq('conversation_id', conversationId)
        .map((event) {
          if (event.isEmpty) return false;

          // Filter out current user and check if anyone else is typing
          final otherUsersTyping = event.where((user) => user['user_id'] != userId).toList();

          if (otherUsersTyping.isEmpty) return false;

          // Check if any other user has typed within the last 5 seconds
          final now = DateTime.now();
          return otherUsersTyping.any((user) {
            final lastTyped = DateTime.parse(user['last_typed']);
            return now.difference(lastTyped).inSeconds < 5;
          });
        });
  }

  static Future<void> startTyping(String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('typing_status').upsert({
      'conversation_id': conversationId,
      'user_id': userId,
      'last_typed': DateTime.now().toIso8601String(),
    });

    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, () => stopTyping(conversationId));
  }

  static Future<void> stopTyping(String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('typing_status')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);

    _typingTimer?.cancel();
    _typingTimer = null;
  }
}