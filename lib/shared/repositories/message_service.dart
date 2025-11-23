import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/message.dart';
import 'conversation_service.dart';

class MessageService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch messages for a conversation with manual read-receipt merging
  static Future<List<Message>> getMessages(String conversationId, {int limit = 50}) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      developer.log('=== GETTING MESSAGES FOR CONVERSATION: $conversationId ===');

      // 1. Get the messages
      final messagesResponse = await _client
          .from('messages')
          .select('''
            *,
            sender:sender_id (
              id,
              display_name,
              username,
              email,
              avatar_url
            ),
            message_reactions (
              id,
              message_id,
              user_id,
              emoji,
              created_at
            )
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      final messageIds = (messagesResponse as List<dynamic>)
          .map((m) => m['id'] as String)
          .toList();
      
      developer.log('Found ${messagesResponse.length} messages');

      if (messageIds.isEmpty) {
        return [];
      }

      // 2. Get read receipts ONLY for these messages (Optimized)
      final allReadReceiptsResponse = await _client
          .from('message_reads')
          .select('message_id, user_id, read_at')
          .inFilter('message_id', messageIds);

      // 3. Group read receipts by message_id
      final readReceiptsMap = <String, List<Map<String, dynamic>>>{};
      for (final receipt in allReadReceiptsResponse) {
        final messageId = receipt['message_id'] as String;
        readReceiptsMap.putIfAbsent(messageId, () => []).add(receipt);
      }

      // 4. Parse messages and merge read receipts
      final messages = (messagesResponse).map((messageMap) {
        final message = messageMap as Map<String, dynamic>;
        final messageId = message['id'] as String;

        // Inject read receipts for this message
        final messageReadReceipts = readReceiptsMap[messageId] ?? [];
        message['message_reads'] = messageReadReceipts;

        return Message.fromMap(message);
      }).toList();

      developer.log('=== FINISHED LOADING ${messages.length} MESSAGES ===');

      return messages;
    } catch (e) {
      developer.log('Error getting messages: $e');
      return [];
    }
  }

  static Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'type': type.toString().split('.').last,
            'status': MessageStatus.sent.toString().split('.').last,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final message = Message.fromMap(response);

      // Update conversation's last message
      await ConversationService.updateLastMessage(
        conversationId: conversationId,
        lastMessage: content,
      );

      return message;
    } catch (e) {
      developer.log('Error sending message: $e');
      return null;
    }
  }

  static Future<Message?> sendCallEventMessage({
    required String conversationId,
    required String callId,
    required String callerId,
    required String receiverId,
    required CallEventType eventType,
    required int duration, // in seconds, 0 for missed/unanswered calls
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      // Create call event content
      final content = _getCallEventDisplayText(eventType, duration);

      final response = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'type': MessageType.call.toString().split('.').last,
            'status': MessageStatus.sent.toString().split('.').last,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final message = Message.fromMap(response);

      // Update conversation's last message
      await ConversationService.updateLastMessage(
        conversationId: conversationId,
        lastMessage: content,
      );

      return message;

    } catch (e) {
      developer.log('Error sending call event message: $e');
      return null;
    }
  }

  static Future<Message?> getMessage(String messageId) async {
    try {
      final response = await _client
          .from('messages')
          .select('''
            *,
            sender:sender_id (
              id,
              display_name,
              username,
              email,
              avatar_url
            ),
            message_reads (
              user_id,
              read_at
            ),
            message_reactions (
              id,
              message_id,
              user_id,
              emoji,
              created_at
            )
          ''')
          .eq('id', messageId)
          .single();

      return Message.fromMap(response);
    } catch (e) {
      developer.log('Error getting message: $e');
      return null;
    }
  }

  static Stream<List<Message>> subscribeToMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) {
          final messages = (data as List<dynamic>)
              .map((message) => Message.fromMap(message as Map<String, dynamic>))
              .toList();
          return messages;
        });
  }

  static Future<bool> deleteMessage(String messageId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // Check if the message belongs to the current user
      final message = await getMessage(messageId);
      if (message == null || message.senderId != currentUserId) {
        return false; // Can only delete own messages
      }

      await _client.from('messages').delete().eq('id', messageId);
      return true;
    } catch (e) {
      developer.log('Error deleting message: $e');
      return false;
    }
  }

  static Future<bool> addReaction({required String messageId, required String emoji}) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await _client.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': currentUserId,
        'emoji': emoji,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      developer.log('Error adding reaction: $e');
      return false;
    }
  }

  static Future<bool> removeReaction({required String messageId, required String emoji}) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', currentUserId)
          .eq('emoji', emoji);

      return true;
    } catch (e) {
      developer.log('Error removing reaction: $e');
      return false;
    }
  }

  static String _getCallEventDisplayText(CallEventType eventType, int duration) {
    switch (eventType) {
      case CallEventType.missed:
        return '📞 Missed call';
      case CallEventType.answered:
        return '📞 Call answered (${_formatDuration(duration)})';
      case CallEventType.ended:
        return '📞 Call ended (${_formatDuration(duration)})';
      case CallEventType.declined:
        return '📞 Call declined';
      case CallEventType.noAnswer:
        return '📞 No answer';
    }
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${remainingSeconds}s';
    }
  }
  
  static Future<bool> markConversationMessagesAsRead(String conversationId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // Find unread messages for the current user in this conversation.
      final unreadMessagesResponse = await _client
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUserId);

      // We need to check which of these are actually unread.
      // A more robust way is to use an RPC or a more complex query.
      // For now, we will just attempt to insert read receipts for all of them.
      // The database unique constraint on (message_id, user_id) will prevent duplicates.
      final messageIds = (unreadMessagesResponse as List<dynamic>)
          .map((m) => m['id'] as String)
          .toList();

      if (messageIds.isEmpty) return true;
      
      final readReceipts = messageIds.map((messageId) => {
        'message_id': messageId,
        'user_id': currentUserId,
        'read_at': DateTime.now().toIso8601String(),
      }).toList();

      await _client.from('message_reads').upsert(
        readReceipts, 
        onConflict: 'message_id, user_id',
        ignoreDuplicates: true
      );

      return true;
    } catch (e) {
      developer.log('Error marking messages as read: $e');
      return false;
    }
  }
}
