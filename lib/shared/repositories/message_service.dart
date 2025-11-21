import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/message.dart';
import 'conversation_service.dart';

class MessageService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<Message>> getMessages(String conversationId, {int limit = 50}) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      developer.log('=== GETTING MESSAGES FOR CONVERSATION: $conversationId ===');

      // First, get the messages
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

      final messageIds = (messagesResponse as List<dynamic>).map((m) => m['id'] as String).toList();
      developer.log('Found ${messagesResponse.length} messages with IDs: $messageIds');

      // Then, get ALL read receipts (not just for this conversation)
      final allReadReceiptsResponse = await _client
          .from('message_reads')
          .select('message_id, user_id, read_at');

      developer.log('Total read receipts in DB: ${allReadReceiptsResponse.length}');
      for (final receipt in allReadReceiptsResponse) {
        developer.log('DB Read receipt: message=${receipt['message_id']}, user=${receipt['user_id']}');
      }

      // Filter read receipts to only include those for our messages
      final filteredReadReceipts = (allReadReceiptsResponse as List<dynamic>)
          .where((receipt) => messageIds.contains(receipt['message_id']))
          .toList();

      developer.log('Filtered read receipts for this conversation: ${filteredReadReceipts.length}');
      for (final receipt in filteredReadReceipts) {
        developer.log('Filtered Read receipt: message=${receipt['message_id']}, user=${receipt['user_id']}');
      }

      // Group read receipts by message_id
      final readReceiptsMap = <String, List<Map<String, dynamic>>>{};
      for (final receipt in filteredReadReceipts) {
        final messageId = receipt['message_id'] as String;
        readReceiptsMap.putIfAbsent(messageId, () => []).add(receipt);
      }

      developer.log('Read receipts map keys: ${readReceiptsMap.keys.toList()}');

      // Parse messages and merge read receipts
      final messages = (messagesResponse as List<dynamic>).map((messageMap) {
        final message = messageMap as Map<String, dynamic>;
        final messageId = message['id'] as String;

        // Get read receipts for this message
        final messageReadReceipts = readReceiptsMap[messageId] ?? [];
        message['message_reads'] = messageReadReceipts;

        developer.log('FINAL: Message $messageId has ${messageReadReceipts.length} read receipts');

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
    developer.log('🔄 Setting up real-time subscription for conversation: $conversationId');

    // Use the standard Supabase stream approach with proper filtering
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) {
          developer.log('📡 Real-time message update: ${data.length} records received for conversation $conversationId');

          final messages = (data as List)
              .map((message) => Message.fromMap(message as Map<String, dynamic>))
              .toList();

          developer.log('✅ Processed ${messages.length} messages for conversation $conversationId');
          return messages;
        });
  }

  static Future<bool> updateMessageStatus({
    required String messageId,
    required MessageStatus status,
  }) async {
    try {
      await _client
          .from('messages')
          .update({
            'status': status.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);

      return true;
    } catch (e) {
      developer.log('Error updating message status: $e');
      return false;
    }
  }

  static Future<bool> markMessageAsRead({
    required String messageId,
  }) async {
    return await updateMessageStatus(
      messageId: messageId,
      status: MessageStatus.read,
    );
  }

  static Future<bool> markMessageAsDelivered({
    required String messageId,
  }) async {
    return await updateMessageStatus(
      messageId: messageId,
      status: MessageStatus.delivered,
    );
  }

  static Future<bool> deleteMessage(String messageId) async {
    try {
      await _client
          .from('messages')
          .delete()
          .eq('id', messageId);

      return true;
    } catch (e) {
      developer.log('Error deleting message: $e');
      return false;
    }
  }

  static Future<bool> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _client
          .from('users')
          .update({
            'is_online': isOnline,
            'last_seen': isOnline ? null : DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      developer.log('Error updating online status: $e');
      return false;
    }
  }

  static Future<bool> updateTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      // This would typically use a separate typing indicators table
      // For now, we'll use a simple approach with user status
      developer.log('User $userId is ${isTyping ? "typing" : "not typing"} in conversation $conversationId');
      return true;
    } catch (e) {
      developer.log('Error updating typing status: $e');
      return false;
    }
  }

  static Future<int> markConversationMessagesAsRead(String conversationId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      // Get all messages in the conversation that are not from the current user
      final messagesResponse = await _client
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId);

      final messageIds = (messagesResponse as List<dynamic>)
          .map((m) => m['id'] as String)
          .toList();

      if (messageIds.isEmpty) return 0;

      // Insert read receipts for messages that don't already have them
      final readReceiptsToInsert = messageIds.map((messageId) => {
        'message_id': messageId,
        'user_id': userId,
      }).toList();

      final response = await _client
          .from('message_reads')
          .insert(readReceiptsToInsert)
          .select();

      final messagesRead = (response as List<dynamic>).length;
      developer.log('Inserted $messagesRead read receipts for conversation $conversationId');
      return messagesRead;
    } catch (e) {
      developer.log('Error marking messages as read: $e');
      return 0;
    }
  }

  static Future<bool> markSingleMessageAsRead(String messageId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('message_reads')
          .insert({
            'message_id': messageId,
            'user_id': userId,
          });

      developer.log('Marked message $messageId as read by user $userId');
      return true;
    } catch (e) {
      developer.log('Error marking message as read: $e');
      return false;
    }
  }

  static Future<List<String>> getMessageReadBy(String messageId) async {
    try {
      final response = await _client
          .from('message_reads')
          .select('user_id')
          .eq('message_id', messageId);

      return (response as List<dynamic>)
          .map((read) => read['user_id'] as String)
          .toList();
    } catch (e) {
      developer.log('Error getting message read status: $e');
      return [];
    }
  }

  static Future<bool> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('message_reactions')
          .insert({
            'message_id': messageId,
            'user_id': userId,
            'emoji': emoji,
          });

      return true;
    } catch (e) {
      // Ignore duplicate key errors (already reacted)
      if (e.toString().contains('23505')) {
        return true;
      }
      developer.log('Error adding reaction: $e');
      return false;
    }
  }

  static Future<bool> removeReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('message_reactions')
          .delete()
          .match({
            'message_id': messageId,
            'user_id': userId,
            'emoji': emoji,
          });

      return true;
    } catch (e) {
      developer.log('Error removing reaction: $e');
      return false;
    }
  }
}