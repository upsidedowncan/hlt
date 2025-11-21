import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/zai_service.dart';
import '../models/ai_conversation.dart';
import '../models/ai_message.dart';
import 'profile_service.dart';

enum StreamingTokenType {
  content,
  reasoning,
}

class StreamingChunk {
  final StreamingTokenType? type;
  final String? token;
  final bool done;

  StreamingChunk({
    this.type,
    this.token,
    this.done = false,
  });

  // Factory for content tokens
  factory StreamingChunk.content(String token) {
    return StreamingChunk(type: StreamingTokenType.content, token: token);
  }

  // Factory for reasoning tokens
  factory StreamingChunk.reasoning(String token) {
    return StreamingChunk(type: StreamingTokenType.reasoning, token: token);
  }

  // Factory for done signal
  factory StreamingChunk.done() {
    return StreamingChunk(done: true);
  }
}

class AiChatService {
  static const String _conversationsKey = 'ai_conversations';
  static const String _miteConversationId = 'mite-ai-conversation';
  static const String _selectedModelKey = 'selected_ai_model';

  // Available models
  static const String modelDeep = 'mite_deep'; // Perplexity Sonar
  static const String modelQuick = 'mite_quick'; // Z.ai GLM-4.5-flash

  static const Map<String, String> modelNames = {
    modelDeep: 'Mite Deep',
    modelQuick: 'Mite Quick',
  };

  static const Map<String, String> modelDescriptions = {
    modelDeep: 'Deep reasoning with Perplexity Sonar',
    modelQuick: 'Fast responses with GLM-4.5-flash',
  };

  static Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedModelKey) ?? modelDeep; // Default to Deep
  }

  static Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, model);
  }
  
  static Future<List<AiConversation>> getConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString(_conversationsKey);

      List<AiConversation> conversations = [];
      if (conversationsJson != null) {
        final List<dynamic> conversationsList = jsonDecode(conversationsJson);
        conversations = conversationsList
            .map((conv) => AiConversation.fromMap(conv))
            .toList();
      }

      // Ensure Mite conversation is always present and at the top
      final miteIndex = conversations.indexWhere((conv) => conv.id == _miteConversationId);
      if (miteIndex == -1) {
        // Mite doesn't exist, create it
        final miteConversation = AiConversation(
          id: _miteConversationId,
          title: 'Mite AI',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: [],
        );
        conversations.insert(0, miteConversation); // Insert at the beginning
      } else if (miteIndex != 0) {
        // Mite exists but not at the top, move it to the top
        final miteConversation = conversations.removeAt(miteIndex);
        conversations.insert(0, miteConversation);
      }

      // Save the updated conversations back to prefs
      final updatedConversationsJson = jsonEncode(
        conversations.map((conv) => conv.toMap()).toList(),
      );
      await prefs.setString(_conversationsKey, updatedConversationsJson);

      return conversations;
    } catch (e) {
      debugPrint('Error loading AI conversations: $e');
      // Even on error, ensure Mite conversation is available
      final miteConversation = AiConversation(
        id: _miteConversationId,
        title: 'Mite AI',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      return [miteConversation];
    }
  }

  static Future<AiConversation?> getConversation(String id) async {
    try {
      final conversations = await getConversations();
      return conversations.where((conv) => conv.id == id).firstOrNull;
    } catch (e) {
      debugPrint('Error getting AI conversation: $e');
      return null;
    }
  }

  static Future<AiConversation> getOrCreateMiteConversation() async {
    try {
      // Load conversations directly to avoid circular dependency
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString(_conversationsKey);

      List<AiConversation> conversations = [];
      if (conversationsJson != null) {
        final List<dynamic> conversationsList = jsonDecode(conversationsJson);
        conversations = conversationsList
            .map((conv) => AiConversation.fromMap(conv))
            .toList();
      }

      // Check if Mite conversation exists
      final existingConversation = conversations.where((conv) => conv.id == _miteConversationId).firstOrNull;
      if (existingConversation != null) {
        return existingConversation;
      }

      // Create new Mite conversation
      final newConversation = AiConversation(
        id: _miteConversationId,
        title: 'Mite AI',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );

      await saveConversation(newConversation);
      return newConversation;
    } catch (e) {
      debugPrint('Error creating Mite conversation: $e');
      rethrow;
    }
  }

  static Future<bool> saveConversation(AiConversation conversation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = await getConversations();
      
      // Remove existing conversation with same ID if exists
      conversations.removeWhere((conv) => conv.id == conversation.id);
      
      // Add updated conversation
      conversations.add(conversation);
      
      // Sort by updated date (most recent first)
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      final conversationsJson = jsonEncode(
        conversations.map((conv) => conv.toMap()).toList(),
      );
      
      return await prefs.setString(_conversationsKey, conversationsJson);
    } catch (e) {
      debugPrint('Error saving AI conversation: $e');
      return false;
    }
  }

  static Future<AiMessage?> sendMessage({
    required String conversationId,
    required String content,
    int memorySize = 10,
  }) async {
    try {
      var conversation = await getConversation(conversationId);
      if (conversation == null) return null;

      // Create user message
      final userMessage = AiMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        isFromUser: true,
        timestamp: DateTime.now(),
      );

      // Add user message to conversation
      conversation.messages.add(userMessage);
      await saveConversation(conversation);

      // Get user info for personalization
      final userProfile = await ProfileService.getCurrentUserProfile();
      final userInfo = userProfile != null ? {
        'display_name': userProfile.displayName,
        'username': userProfile.username,
        'email': userProfile.email,
      } : null;

      // Get selected model
      final selectedModel = await getSelectedModel();

      // Get conversation history for context (limited by memory size)
      final conversationHistory = conversation.messages
          .where((msg) => msg.id != null)
          .toList()
          .reversed // Get most recent messages first
          .take(memorySize) // Limit to memory size
          .toList()
          .reversed // Put back in chronological order
          .map((msg) => {
            'role': msg.isFromUser ? 'user' : 'assistant',
            'content': msg.content,
          })
          .toList();

      // Get AI response
      final aiResult = await _sendMessageToModel(
        model: selectedModel,
        message: content,
        conversationHistory: conversationHistory,
      );

      // Create AI message
      final aiMessage = AiMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        content: aiResult['content'] as String,
        isFromUser: false,
        timestamp: DateTime.now(),
        reasoning_content: aiResult['reasoning_content'] as String?,
      );

      // Add AI message to conversation
      conversation.messages.add(aiMessage);
      await saveConversation(conversation);

      return aiMessage;
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      return null;
    }
  }

  static Stream<String> sendMessageStream({
    required String conversationId,
    required String content,
    int memorySize = 10,
  }) async* {
    try {
      var aiConversation = await getConversation(conversationId);
      if (aiConversation == null) {
        yield 'Conversation not found.';
        return;
      }

      final selectedModel = await getSelectedModel();

      // Get conversation history for context (limited by memory size)
      final conversationHistory = aiConversation.messages
          .where((msg) => msg.id != null)
          .toList()
          .reversed // Get most recent messages first
          .take(memorySize) // Limit to memory size
          .toList()
          .reversed // Put back in chronological order
          .map((msg) => {
            'role': msg.isFromUser ? 'user' : 'assistant',
            'content': msg.content,
          })
          .toList();

      // Create user message
      final userMessage = AiMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        isFromUser: true,
        timestamp: DateTime.now(),
      );

      aiConversation.messages.add(userMessage);
      await saveConversation(aiConversation);

      // Create streaming AI message
      final aiMessageId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
      final streamingMessage = AiMessage(
        id: aiMessageId,
        content: '',
        isFromUser: false,
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      aiConversation.messages.add(streamingMessage);
      await saveConversation(aiConversation);

      String accumulatedContent = '';
      String accumulatedReasoning = '';

      // Stream AI response
      await for (final chunk in _streamMessageFromModel(
        model: selectedModel,
        message: content,
        conversationHistory: conversationHistory,
      )) {
        if (chunk.done) {
          // Finalize the message
          final finalMessage = streamingMessage.copyWith(
            content: accumulatedContent,
            reasoning_content: accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
            isStreaming: false,
          );

          final messageIndex = aiConversation.messages.indexWhere((msg) => msg.id == aiMessageId);
          if (messageIndex != -1) {
            aiConversation.messages[messageIndex] = finalMessage;
            await saveConversation(aiConversation);
          }
          break;
        } else {
          // Accumulate tokens based on type
          if (chunk.type == StreamingTokenType.content && chunk.token != null) {
            accumulatedContent += chunk.token!;
          } else if (chunk.type == StreamingTokenType.reasoning && chunk.token != null) {
            accumulatedReasoning += chunk.token!;
          }

          // Update streaming message
          final updatedMessage = streamingMessage.copyWith(
            content: accumulatedContent,
            reasoning_content: accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
            isStreaming: true,
          );

          final messageIndex = aiConversation.messages.indexWhere((msg) => msg.id == aiMessageId);
          if (messageIndex != -1) {
            aiConversation.messages[messageIndex] = updatedMessage;
          }

          // Yield accumulated content for UI update
          yield accumulatedContent;
        }
      }

    } catch (e) {
      debugPrint('Error in sendMessageStream: $e');
      yield 'Sorry, I encountered an error. Please try again.';
    }
  }

  static Future<bool> deleteConversation(String id) async {
    try {
      final conversations = await getConversations();
      conversations.removeWhere((conv) => conv.id == id);
      
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = jsonEncode(
        conversations.map((conv) => conv.toMap()).toList(),
      );
      
      return await prefs.setString(_conversationsKey, conversationsJson);
    } catch (e) {
      debugPrint('Error deleting AI conversation: $e');
      return false;
    }
  }

  static Future<bool> clearAllConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_conversationsKey);
    } catch (e) {
      debugPrint('Error clearing AI conversations: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> _sendMessageToModel({
    required String model,
    required String message,
    List<Map<String, String>>? conversationHistory,
  }) async {
    // Only use ZaiService (GLM-4.5-flash) for all models
    final response = await ZaiService.sendMessage(
      message: message,
      conversationHistory: conversationHistory,
    );
    return {
      'content': response['choices']?[0]?['message']?['content'] ?? response['content'] ?? 'No response',
      'reasoning_content': response['reasoning_content'],
    };
  }

  static Stream<StreamingChunk> _streamMessageFromModel({
    required String model,
    required String message,
    List<Map<String, String>>? conversationHistory,
  }) async* {
    // Only use ZaiService (GLM-4.5-flash) for all models
    yield* await ZaiService.streamMessage(
      message: message,
      conversationHistory: conversationHistory,
    );
  }
}