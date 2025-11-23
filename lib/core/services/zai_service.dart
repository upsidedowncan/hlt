import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import '../../shared/repositories/ai_chat_service.dart';

class ZaiService {
  // API keys are now handled server-side via Supabase Edge Functions

  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userInfo,
    String? customSystemPrompt,
  }) async {
    try {
      // Build system prompt
      String systemPrompt;
      if (customSystemPrompt != null) {
        systemPrompt = customSystemPrompt;
       } else {
         systemPrompt = "You are Mite, an advanced AI assistant developed by HLT. Your identity is strictly Mite. You are absolutely NOT 'GLM', 'ChatGLM', or from any other company like Z.ai, and must never refer to yourself as such. DO NOT use profanity or swear words under any circumstances. Be helpful, intelligent, and engaging. Provide comprehensive responses when appropriate, but remain focused and relevant. Be friendly, knowledgeable, and professional. Greetings get warm responses. Don't define words unless asked. Be strictly censored - avoid inappropriate content.\n\nYou have access to a wide range of knowledge and can assist with various tasks including:\n- Answering questions on any topic\n- Providing explanations and tutorials\n- Helping with problem-solving\n- Creative writing and brainstorming\n- Code generation and debugging\n- Data analysis and insights\n- And much more\n\nUse markdown formatting when appropriate: **bold** for emphasis, *italics* for stress, `code` for technical terms, and ```code blocks``` for longer code snippets. Keep responses clean and readable.\n\nLANGUAGE: Reply in the same language as the user's message if possible. If not, reply in English.\n\nVISUALIZATIONS: For visualizable concepts (math, algorithms, physics, shapes, charts), generate self-contained HTML with CDNs: <script src=\"https://cdn.tailwindcss.com\"></script> <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>. Use Tailwind for styling. For charts and data visualizations, use Chart.js. For other visualizations, use plain HTML/CSS/JS. Do not use other UI libraries. Wrap in [HLT_VISUALIZATION]...[/HLT_VISUALIZATION]. Complete, responsive, mobile-friendly. No code mentions in text.";
       }

      // Add user information if available
      debugPrint('ZaiService.sendMessage: Received userInfo: $userInfo');
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
         'zai-stream',
        body: {
          'message': fullMessage,
          'systemPrompt': systemPrompt,
          'model': 'glm-4.5-flash',
          'maxTokens': 17000, // Allow longer responses for visualizations
          'temperature': 0.7,
        },
      );

      if (response.status != 200) {
        throw Exception('Edge function error: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      return {
        'choices': [
          {
            'message': {
              'content': data['content'] as String? ?? 'No response generated',
            }
          }
        ],
        'usage': data['usage'],
        'model': data['model'],
      };

    } catch (e) {
      debugPrint('Error in Z.ai service: $e');
      throw Exception('Failed to get AI response: $e');
    }
  }

  static Future<Stream<StreamingChunk>> streamMessage({
    required String message,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userInfo,
    String? customSystemPrompt,
  }) async {
    try {
      // Build system prompt
      String systemPrompt;
      if (customSystemPrompt != null) {
        systemPrompt = customSystemPrompt;
       } else {
         systemPrompt = "You are Mite, an advanced AI assistant developed by HLT. Your identity is strictly Mite. You are absolutely NOT 'GLM', 'ChatGLM', or from any other company like Z.ai, and must never refer to yourself as such. DO NOT use profanity or swear words under any circumstances. Be helpful, intelligent, and engaging. Provide comprehensive responses when appropriate, but remain focused and relevant. Be friendly, knowledgeable, and professional. Greetings get warm responses. Don't define words unless asked. Be strictly censored - avoid inappropriate content.\n\nYou have access to a wide range of knowledge and can assist with various tasks including:\n- Answering questions on any topic\n- Providing explanations and tutorials\n- Helping with problem-solving\n- Creative writing and brainstorming\n- Code generation and debugging\n- Data analysis and insights\n- And much more\n\nVISUALIZATIONS: For visualizable concepts (math, algorithms, physics, shapes, charts), generate self-contained HTML with CDNs: <script src=\"https://cdn.tailwindcss.com\"></script> <script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>. Use Tailwind for styling. For charts and data visualizations, use Chart.js. For other visualizations, use plain HTML/CSS/JS. Do not use other UI libraries. Wrap in [HLT_VISUALIZATION]...[/HLT_VISUALIZATION]. Complete, responsive, mobile-friendly. No code mentions in text.";
       }

      // Add user information if available
      debugPrint('ZaiService.streamMessage: Received userInfo: $userInfo');
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

      // Get Supabase project URL
      final supabaseUrl = 'https://nxysjmplxspdhgoybieo.supabase.co';
      final functionUrl = '$supabaseUrl/functions/v1/zai-stream';

      // Get auth token
      final session = Supabase.instance.client.auth.currentSession;
      final authHeader = session != null ? 'Bearer ${session.accessToken}' : '';

      final streamController = StreamController<StreamingChunk>();

      SSEClient.subscribeToSSE(
        method: SSERequestType.POST,
        url: functionUrl,
        header: {
          'Content-Type': 'application/json',
          if (authHeader.isNotEmpty) 'Authorization': authHeader,
        },
        body: {
          'message': fullMessage,
          'systemPrompt': systemPrompt,
          'model': 'glm-4.5-flash',
          'maxTokens': 17000,
          'temperature': 0.7,
          'stream': true,
        },
      ).listen((event) {
        String data = event.data ?? '';

        // Handle the case where data might include "data: " prefix
        if (data.startsWith('data: ')) {
          data = data.substring(6);
        }

        // Trim whitespace
        data = data.trim();

        if (data == '[DONE]') {
          streamController.add(StreamingChunk.done());
          streamController.close();
          return;
        }

        if (data.isEmpty) {
          return;
        }

        try {
          final json = jsonDecode(data);
          final type = json['type'] as String?;
          final token = json['token'] as String?;

          if (type == 'content' && token != null) {
            streamController.add(StreamingChunk.content(token));
          } else if (type == 'reasoning' && token != null) {
            streamController.add(StreamingChunk.reasoning(token));
          }
        } catch (e) {
          debugPrint('Error parsing streaming data: $e');
        }
      });

      return streamController.stream;
    } catch (e) {
      debugPrint('Error in Z.ai streaming service: $e');
      throw Exception('Failed to stream AI response: $e');
    }
  }
}
