import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/repositories/ai_chat_service.dart';

class PerplexityService {
  // API keys are now handled server-side via Supabase Edge Functions

  static Future<String> sendMessage({
    required String message,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      // Build personalized system prompt
      String systemPrompt = "You are Mite, an advanced AI assistant developed by HLT. You are powered by Perplexity technology. Be helpful, intelligent, and engaging. Provide comprehensive responses when appropriate, but remain focused and relevant. Be friendly, knowledgeable, and professional. Greetings get warm responses. Don't define words unless asked. Be strictly censored - avoid inappropriate content.\n\nYou have access to a wide range of knowledge and can assist with various tasks including:\n- Answering questions on any topic\n- Providing explanations and tutorials\n- Helping with problem-solving\n- Creative writing and brainstorming\n- Research and analysis\n- Data insights\n- And much more\n\nUse markdown formatting when appropriate: **bold** for emphasis, *italics* for stress, `code` for technical terms, and ```code blocks``` for longer code snippets. Keep responses clean and readable.";

      // Add user information if available
      if (userInfo != null) {
        final displayName = userInfo['display_name'] ?? 'User';
        final username = userInfo['username'];
        final email = userInfo['email'];

        systemPrompt += "\n\nUser Information (for personalization only):";
        systemPrompt += "\n- Display Name: $displayName";
        if (username != null) systemPrompt += "\n- Username: @$username";
        if (email != null) systemPrompt += "\n- Email: $email";
        systemPrompt += "\n- Platform: ${userInfo['platform'] ?? 'Unknown'}";
        systemPrompt += "\n\nUse this information to provide personalized, friendly responses. Address the user by their display name when appropriate.";
      }

      // Add conversation history to the message if provided
      String fullMessage = message;
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final historyText = conversationHistory.map((msg) =>
          "${msg['role'] == 'user' ? 'User' : 'Assistant'}: ${msg['content']}"
        ).join('\n');

        fullMessage = "Previous conversation:\n$historyText\n\nCurrent message: $message";
      }

      // Call Supabase Edge Function instead of external API
      final response = await Supabase.instance.client.functions.invoke(
        'perplexity-proxy',
        body: {
          'message': fullMessage,
          'systemPrompt': systemPrompt,
          'model': 'sonar',
          'maxTokens': 500,
          'temperature': 0.7,
        },
      );

      if (response.status != 200) {
        throw Exception('Edge function error: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      return data['content'] as String? ?? 'No response generated';

    } catch (e) {
      debugPrint('Error in Perplexity service: $e');
      throw Exception('Failed to get AI response: $e');
    }
  }

  static Future<Stream<StreamingChunk>> streamMessage({
    required String message,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userInfo,
  }) async {
    // DEPRECATED: PerplexityService is no longer supported
    throw UnimplementedError('PerplexityService.streamMessage is deprecated and should not be used. Use ZaiService instead.');
  }
}