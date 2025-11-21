import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/user.dart' as app_user;

class ConversationService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<Conversation>> getUserConversations() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      // First get conversation IDs from participants
      final participantResponse = await _client
          .from('participants')
          .select('conversation_id')
          .eq('user_id', userId);

      final conversationIds = (participantResponse as List)
          .map((p) => p['conversation_id'] as String)
          .toList();

      if (conversationIds.isEmpty) return [];

      // Get conversations with display info for current user
      final conversations = <Conversation>[];
      for (final conversationId in conversationIds) {
        final conversation = await getConversation(conversationId, currentUserId: userId);
        if (conversation != null) {
          conversations.add(conversation);
        }
      }

      // Sort by last message time
      conversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return conversations;
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return [];
    }
  }

  static Future<Conversation?> getConversation(String conversationId, {String? currentUserId}) async {
    try {
      final userId = currentUserId ?? _client.auth.currentUser?.id;
      if (userId == null) return null;

      // Get conversation with display info for current user
      final response = await _client
          .from('conversations')
          .select('''
            *,
            participants!inner(
              user_id,
              last_read_at
            )
          ''')
          .eq('id', conversationId)
          .single();

      final conversation = Conversation.fromMap(response);

      // Get display info for current user
      final displayInfo = await _client.rpc('get_conversation_display_info', params: {
        'p_conversation_id': conversationId,
        'p_current_user_id': userId,
      });

      if (displayInfo != null && displayInfo.isNotEmpty) {
        final info = displayInfo.first as Map<String, dynamic>;
        // Override the conversation name and avatar with user-specific display info
        return conversation.copyWith(
          name: info['display_name'] as String?,
          avatarUrl: info['display_avatar_url'] as String?,
        );
      }

      return conversation;
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return null;
    }
  }

  static Future<Conversation?> findOrCreateConversation(String otherUserId, String conversationName) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      debugPrint('Finding or creating conversation between $userId and $otherUserId');

      // Call the SQL function
      final response = await _client.rpc('find_or_create_conversation', params: {
        'p_user_id': userId,
        'p_other_user_id': otherUserId,
        'p_conversation_name': conversationName,
      });

      if (response == null || (response as List).isEmpty) {
        throw Exception('No response from find_or_create_conversation');
      }

      final result = response.first as Map<String, dynamic>;

      // Create conversation object from the result
      final conversation = Conversation(
        id: result['conversation_id'] as String,
        name: result['conversation_name'] as String?,
        avatarUrl: result['conversation_avatar_url'] as String?,
        isGroup: result['is_group'] as bool,
        createdAt: DateTime.now(), // We don't get this from the function
        participantIds: [], // We'll load this separately if needed
      );

      final wasCreated = result['created'] as bool;
      debugPrint('Conversation ${wasCreated ? 'created' : 'found'}: ${conversation.id}');

      return conversation;

    } catch (e) {
      debugPrint('Error in findOrCreateConversation: $e');
      return null;
    }
  }



  static Future<bool> updateLastMessage({
    required String conversationId,
    required String lastMessage,
  }) async {
    try {
      await _client
          .from('conversations')
          .update({
            'last_message': lastMessage,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      return true;
    } catch (e) {
      debugPrint('Error updating last message: $e');
      return false;
    }
  }

  static Future<List<app_user.User>> getConversationParticipants(String conversationId) async {
    try {
      final response = await _client
          .from('participants')
          .select('''
            user_id,
            users(
              id,
              email,
              username,
              display_name,
              avatar_url,
              is_online,
              last_seen
            )
          ''')
          .eq('conversation_id', conversationId);

      final participants = (response as List<dynamic>)
          .where((participant) => (participant as Map<String, dynamic>)['users'] != null)
          .map((participant) => app_user.User.fromMap((participant as Map<String, dynamic>)['users'] as Map<String, dynamic>))
          .toList();

      return participants;
    } catch (e) {
      debugPrint('Error getting conversation participants: $e');
      return [];
    }
  }

  static Future<bool> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _client
          .from('participants')
          .update({
            'last_read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error marking as read: $e');
      return false;
    }
  }
}