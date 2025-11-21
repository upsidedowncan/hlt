import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/ai_settings_provider.dart';
import '../../../core/services/perplexity_service.dart';
import '../../../core/services/zai_service.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../shared/repositories/profile_service.dart';
import '../../../core/services/file_upload_service.dart';
import '../../../core/services/voice_recording_service.dart';
import '../../../core/services/typing_service.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/models/ai_conversation.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/user.dart' as app_user;
import '../../../shared/repositories/message_service.dart';
import '../../../shared/repositories/conversation_service.dart';
import '../../../shared/repositories/ai_chat_service.dart';
import '../../../shared/widgets/file_message_widget.dart';
import '../screens/visualization_screen.dart';
import '../../../shared/widgets/audio_message_widget.dart';
import '../../profile/widgets/profile_avatar.dart';

// --- MODELS for Message Grouping ---

enum MessagePosition { single, first, middle, last }

class MessageGroup {
  final List<Message> messages;
  final bool isFromMe;
  final DateTime timestamp;

  MessageGroup({
    required this.messages,
    required this.isFromMe,
    required this.timestamp,
  });
}

class AiMessageGroup {
  final List<AiMessage> messages;
  final bool isFromUser;
  final DateTime timestamp;

  AiMessageGroup({
    required this.messages,
    required this.isFromUser,
    required this.timestamp,
  });
}

// --- STATE MANAGEMENT with ChangeNotifier ---

class ChatProvider with ChangeNotifier {
  // Common properties
  bool _isLoading = true;
  String? _conversationTitle;
  Conversation? _conversation;
  List<app_user.User> _participants = [];
  final ScrollController scrollController = ScrollController();
  final TextEditingController messageController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();

  // Regular chat properties
  List<Message> _messages = [];
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<bool>? _typingSubscription;
  RealtimeChannel? _reactionsChannel;
  RealtimeChannel? _readReceiptsChannel;
  final Set<String> _newMessageIds = {};
  bool _isSomeoneTyping = false;

  // AI chat properties
  List<AiMessage> _aiMessages = [];
  final int _dailyAiMessageCount = 0;
  final int _dailyAiMessageLimit = 7;

  // Upload progress
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Voice recording
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;

  // Initial scroll flag
  bool _hasScrolledInitial = false;



  // Getters
  bool get isLoading => _isLoading;
  String? get conversationTitle => _conversationTitle;
  Conversation? get conversation => _conversation;
  List<app_user.User> get participants => _participants;
  List<Message> get messages => _messages;
  List<AiMessage> get aiMessages => _aiMessages;
  int get dailyAiMessageCount => _dailyAiMessageCount;
  int get dailyAiMessageLimit => _dailyAiMessageLimit;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;
  Set<String> get newMessageIds => _newMessageIds;
  bool get isSomeoneTyping => _isSomeoneTyping;

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Grouped Messages
  List<MessageGroup> get messageGroups => _groupMessages(_messages);
  List<AiMessageGroup> get aiMessageGroups => _groupAiMessages(_aiMessages);

  final String? conversationId;
  final String? aiConversationId;

  bool get isAiConversation => aiConversationId != null;

  ChatProvider({this.conversationId, this.aiConversationId}) {
    _hasScrolledInitial = false;

    // Setup typing detection
    messageController.addListener(_onTyping);

    if (isAiConversation) {
      _loadAiConversation();
    } else {
      _loadConversation();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _reactionsChannel?.unsubscribe();
    _readReceiptsChannel?.unsubscribe();
    _recordingTimer?.cancel();
    scrollController.dispose();
    messageController.dispose();
    inputFocusNode.dispose();
    super.dispose();
  }

  // --- MESSAGE CACHING ---

  Future<void> _saveAiMessagesCache() async {
    if (!isAiConversation || aiConversationId == null) return;
    const storage = FlutterSecureStorage();
    final messagesJson = _aiMessages.map((m) => m.toMap()).toList();
    await storage.write(
        key: 'ai_messages_$aiConversationId', value: jsonEncode(messagesJson));
  }

  Future<void> clearAiConversation() async {
    if (!isAiConversation || aiConversationId == null) return;

    _aiMessages.clear();
    notifyListeners();

    // Clear cache
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'ai_messages_$aiConversationId');

    // Clear in persistent storage
    try {
      final conversation =
          await AiChatService.getConversation(aiConversationId!);
      if (conversation != null) {
        conversation.messages.clear();
        await AiChatService.saveConversation(conversation);
      }
    } catch (e) {
      debugPrint("Error clearing AI conversation: $e");
    }
  }

  Future<void> _loadAiMessagesFromCache() async {
    if (!isAiConversation || aiConversationId == null) return;
    const storage = FlutterSecureStorage();
    final cached = await storage.read(key: 'ai_messages_$aiConversationId');
    if (cached != null) {
      try {
        final messagesJson = jsonDecode(cached) as List;
        _aiMessages = messagesJson
            .map((m) => AiMessage.fromMap(m as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading cached messages: $e');
      }
    }
  }

  // --- DATA LOADING ---

  Future<void> _loadConversation() async {
    try {
      _conversation = await ConversationService.getConversation(conversationId!);
      _conversationTitle = _conversation?.name ?? 'Chat';
      _participants = await ConversationService.getConversationParticipants(conversationId!);

        // Setup realtime subscription for messages
        _messagesSubscription = MessageService.subscribeToMessages(conversationId!)
            .listen((messages) async {
          // Detect new messages
          final previousMessageIds = _messages.map((m) => m.id).toSet();
          final newMessages =
              messages.where((m) => !previousMessageIds.contains(m.id)).toList();
          _newMessageIds.addAll(newMessages.map((m) => m.id));

          // Preserve existing read receipts when updating messages
          final Map<String, List<MessageRead>> existingReadReceipts = {};
          for (final existingMessage in _messages) {
            existingReadReceipts[existingMessage.id] = existingMessage.readBy;
          }

          _messages = messages
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));



          // Restore read receipts for messages that already had them
          for (int i = 0; i < _messages.length; i++) {
            final message = _messages[i];
            if (existingReadReceipts.containsKey(message.id)) {
              final existingReads = existingReadReceipts[message.id]!;
              // Merge existing read receipts with new ones from database
              final mergedReads = <MessageRead>[];
              mergedReads.addAll(message.readBy); // From database
              for (final existingRead in existingReads) {
                if (!mergedReads.any((r) => r.userId == existingRead.userId)) {
                  mergedReads.add(existingRead);
                }
              }
              _messages[i] = message.copyWith(readBy: mergedReads);
            }
          }

           if (_isLoading) _isLoading = false;
           notifyListeners();
           if (!_hasScrolledInitial) {
             _scrollToBottomInitial();
             _hasScrolledInitial = true;
           } else if (_newMessageIds.isNotEmpty) {
             _scrollToBottom();
           }

           // Mark messages as read
           _markMessagesAsRead();
        });

      // Setup realtime subscription for reactions
      _setupReactionsRealtime();

      // Setup realtime subscription for typing indicators
      _setupTypingRealtime();

      // Setup realtime subscription for read receipts
      _setupReadReceiptsRealtime();

      // Mark messages as read when opening the conversation
      _markMessagesAsRead();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Error loading conversation: $e");
    }
  }

  void _setupReactionsRealtime() {
    final channelName = 'conversation_${conversationId}_reactions';
    _reactionsChannel = Supabase.instance.client.channel(channelName);

    _reactionsChannel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reactions',
      callback: (payload) async {
        debugPrint('📡 Reaction event received: ${payload.eventType}');
        if (payload.eventType == PostgresChangeEvent.insert) {
          final messageId = payload.newRecord['message_id'] as String;
          // Check if this reaction belongs to a message in current chat
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            // Re-fetch the message to get updated reactions list cleanly
            final updatedMessage = await MessageService.getMessage(messageId);
            if (updatedMessage != null) {
              _messages[index] = updatedMessage;
              notifyListeners();
              debugPrint('✅ Updated message with new reaction');
            }
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final reactionId = payload.oldRecord['id'];
          if (reactionId != null) {
            // Find which message has this reaction
            for (var i = 0; i < _messages.length; i++) {
              if (_messages[i].reactions.any((r) => r.id == reactionId)) {
                final updatedMessage =
                    await MessageService.getMessage(_messages[i].id);
                if (updatedMessage != null) {
                  _messages[i] = updatedMessage;
                  notifyListeners();
                  debugPrint('✅ Updated message after reaction deletion');
                }
                break;
              }
            }
          }
        }
      },
    );

    _reactionsChannel?.subscribe();
  }

  void _setupTypingRealtime() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || conversationId == null) return;

    _typingSubscription = TypingService.getTypingStatus(conversationId!, currentUserId)
        .listen((isTyping) {
      _isSomeoneTyping = isTyping;
      notifyListeners();
    });
  }

  void _setupReadReceiptsRealtime() {
    final channelName = 'conversation_${conversationId}_read_receipts';
    _readReceiptsChannel = Supabase.instance.client.channel(channelName);

    _readReceiptsChannel?.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'message_reads',
      callback: (payload) async {
        debugPrint('📡 Read receipt event received: ${payload.eventType}');
        final messageId = payload.newRecord['message_id'] as String?;
        final userId = payload.newRecord['user_id'] as String?;
        final readAt = payload.newRecord['read_at'] as String?;

        if (messageId != null && userId != null && readAt != null) {
          // Find the message and update its readBy list
          final messageIndex = _messages.indexWhere((m) => m.id == messageId);
          if (messageIndex != -1) {
            final message = _messages[messageIndex];
            final existingRead = message.readBy.firstWhereOrNull((r) => r.userId == userId);
            if (existingRead == null) {
              final updatedReadBy = [...message.readBy, MessageRead(
                userId: userId,
                readAt: DateTime.parse(readAt),
              )];
              _messages[messageIndex] = message.copyWith(readBy: updatedReadBy);
              notifyListeners();
              debugPrint('✅ Updated message with new read receipt');
            }
          }
        }
      },
    );

    _readReceiptsChannel?.subscribe();
  }

  Future<void> _loadAiConversation() async {
    // Load from cache first for instant display
    await _loadAiMessagesFromCache();

    try {
      final conversation =
          await AiChatService.getConversation(aiConversationId!);
      if (conversation != null) {
        _aiMessages = conversation.messages
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _conversationTitle = conversation.title;
        // Save to cache after loading
        await _saveAiMessagesCache();
      }
    } catch (e) {
      debugPrint("Error loading AI conversation: $e");
     } finally {
       _isLoading = false;
       notifyListeners();
       _scrollToBottomInitial();
     }
  }

  // --- MESSAGE SENDING ---

  Future<void> sendMessage(BuildContext context) async {
    if (messageController.text.trim().isEmpty) return;

    if (isAiConversation) {
      await _sendAiMessage(context);
    } else {
      await _sendRegularMessage();
    }
  }

  Future<void> _sendRegularMessage() async {
    final content = messageController.text.trim();
    messageController.clear();

    // Stop typing indicator when sending message
    if (conversationId != null) {
      TypingService.stopTyping(conversationId!);
    }

    // Check for @mite mention
    if (content.contains('@mite')) {
      // Send the user's message first
      try {
        await MessageService.sendMessage(
          conversationId: conversationId!,
          content: content,
        );
        // Then trigger AI response
        await _handleMiteMention(content);
      } catch (e) {
        debugPrint("Error sending message: $e");
      }
      return;
    }

    try {
      await MessageService.sendMessage(
        conversationId: conversationId!,
        content: content,
      );
    } catch (e) {
      debugPrint("Error sending message: $e");
      // Optionally, show a snackbar to the user
    }
  }

  Future<void> _handleMiteMention(String userPrompt) async {
    try {
      // 1. Get recent chat history
      final recentMessages = _messages
          .take(20) // Limit context
          .toList()
          .reversed
          .map((msg) {
        final senderName =
            msg.senderId == Supabase.instance.client.auth.currentUser?.id
                ? 'Me'
                : 'Other User';
        return {
          'role': 'user', // Treat all chat history as 'user' content for the AI
          'content': '$senderName: ${msg.content}'
        };
      }).toList();

      // 2. Get user info via RPC
      final userProfile = await ProfileService.getCurrentUserProfile();
      debugPrint('ChatScreen: Fetched user profile: $userProfile');
      final userInfo = userProfile != null
          ? {
              'display_name': userProfile.displayName,
              'username': userProfile.username,
              'email': userProfile.email,
              'platform': Platform.operatingSystem,
            }
          : {'platform': Platform.operatingSystem};
      debugPrint('ChatScreen: User info for Mite: $userInfo');

      // 3. Call Z.ai (Mite Quick)
      final response = await ZaiService.sendMessage(
        message:
            "The user mentioned you (@mite) in a chat. Here is the context:\n\nPrompt: $userPrompt",
        conversationHistory: recentMessages,
        userInfo: userInfo,
      );

      final aiContent = response['choices'][0]['message']['content'];

      // 4. Send AI response as a message (simulated bot)
      if (aiContent != null) {
        final parsed = _parseAiResponse(aiContent);

        await MessageService.sendMessage(
          conversationId: conversationId!,
          content: "[HLT_SENT_FROM_MITE]${parsed.content}",
        );
      }
    } catch (e) {
      debugPrint("Error handling @mite mention: $e");
    }
  }



  // --- FIXED AI MESSAGE SENDING METHOD ---
   Future<void> _sendAiMessage(BuildContext context) async {
     final content = messageController.text.trim();
     messageController.clear();
     inputFocusNode.unfocus();

     // Capture providers before async operations
     final aiSettings = context.read<AiSettingsProvider>();
     final userProvider = context.read<UserProvider>();

     // 1. Add User Message immediately
     final userMessage = AiMessage(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       content: content,
       isFromUser: true,
       timestamp: DateTime.now(),
     );

     _aiMessages.add(userMessage);
     notifyListeners();
     _scrollToBottom();

     // 2. Add Placeholder for AI response (Thinking state)
     final placeholderId = 'thinking_${DateTime.now().millisecondsSinceEpoch}';
     _aiMessages.add(AiMessage(
       id: placeholderId,
       content: "",
       isFromUser: false,
       timestamp: DateTime.now(),
       isThinking: true,
     ));
     notifyListeners();
     _scrollToBottom();

     try {
       // Prepare context for AI
       final recentMessages = _aiMessages
           .where((m) => !(m.isThinking ?? false) && m.id != placeholderId)
           .take(20)
           .map((msg) => {
                 'role': msg.isFromUser ? 'user' : 'assistant',
                 'content': msg.content
               })
           .toList();

        // Fetch fresh user profile via RPC
        final userProfile = await ProfileService.getCurrentUserProfile();
        debugPrint('ChatScreen AI: Fetched user profile: $userProfile');
        final userInfo = userProfile != null
            ? {
                'display_name': userProfile.displayName,
                'username': userProfile.username,
                'email': userProfile.email,
                'platform': Platform.operatingSystem,
              }
            : {'platform': Platform.operatingSystem};
        debugPrint('ChatScreen AI: User info for Mite: $userInfo');

        // Use streaming for Quick mode, non-streaming for Deep mode
        final displayName = userProfile?.displayName ?? userProfile?.email ?? 'User';
        final enhancedContent = 'You are talking to $displayName. $content';

        if (aiSettings.useDeepMode) {
          // Non-streaming for Deep mode
          final response = await PerplexityService.sendMessage(
            message: enhancedContent,
            conversationHistory: recentMessages,
            userInfo: userInfo,
          );

         final aiRawContent = response as String;
         final parsed = _parseAiResponse(aiRawContent);

         // Update the placeholder message with actual response
         final index = _aiMessages.indexWhere((m) => m.id == placeholderId);
         if (index != -1) {
           _aiMessages[index] = _aiMessages[index].copyWith(
             id: DateTime.now().millisecondsSinceEpoch.toString(),
             content: parsed.content,
             visualizationCode: parsed.visualizationCode,
             timestamp: DateTime.now(),
             isThinking: false,
           );
         }

         notifyListeners();
         _scrollToBottom();
        } else {
          // Streaming for Quick mode
          final stream = await ZaiService.streamMessage(
            message: content,
            conversationHistory: recentMessages,
            userInfo: userInfo,
          );

          String accumulatedContent = '';
          String accumulatedReasoning = '';

          await for (final chunk in stream) {
            if (chunk.done) {
              // Final update with complete content
              final parsed = _parseAiResponse(accumulatedContent);
              final index = _aiMessages.indexWhere((m) => m.id == placeholderId);
              if (index != -1) {
                _aiMessages[index] = _aiMessages[index].copyWith(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  content: parsed.content,
                  visualizationCode: parsed.visualizationCode,
                  timestamp: DateTime.now(),
                  isThinking: false,
                  isStreaming: false,
                  reasoning_content: accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
                );
              }
              notifyListeners();
              _scrollToBottom();
              break;
            }

            // Update content incrementally based on token type
            if (chunk.type == StreamingTokenType.content && chunk.token != null) {
              accumulatedContent += chunk.token!;
            } else if (chunk.type == StreamingTokenType.reasoning && chunk.token != null) {
              accumulatedReasoning += chunk.token!;
            }

            final index = _aiMessages.indexWhere((m) => m.id == placeholderId);
            if (index != -1) {
              _aiMessages[index] = _aiMessages[index].copyWith(
                content: accumulatedContent,
                reasoning_content: accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
                isThinking: false, // Stop thinking animation once we start receiving content
                isStreaming: true, // Add streaming indicator
              );
            }

            notifyListeners();
            _scrollToBottom();
          }
       }

       await _saveAiMessagesCache();
       await _saveToPersistentStorage();

       // Generate conversation title if it's a new conversation
       if (context.mounted) {
         final aiContent = _aiMessages
             .where((m) => m.id != placeholderId && !m.isFromUser)
             .last
             .content;
         await _generateConversationTitleIfNeeded(
             context, content, aiContent);
       }
     } catch (e) {
       debugPrint("Error getting AI response: $e");

       final index = _aiMessages.indexWhere((m) => m.id == placeholderId);
       if (index != -1) {
         _aiMessages[index] = _aiMessages[index].copyWith(
           content: "Sorry, I encountered an error. Please try again.",
           isThinking: false,
         );
       } else {
         _aiMessages.add(AiMessage(
           id: DateTime.now().millisecondsSinceEpoch.toString(),
           content: "Sorry, I encountered an error. Please try again.",
           isFromUser: false,
           timestamp: DateTime.now(),
         ));
       }

       notifyListeners();
       _scrollToBottom();
       await _saveAiMessagesCache();
       await _saveToPersistentStorage();
     }
   }

  Future<void> _saveToPersistentStorage() async {
    if (!isAiConversation || aiConversationId == null) return;
    try {
      var conversation = await AiChatService.getConversation(aiConversationId!);
      if (conversation != null) {
        // Update conversation messages
        conversation = conversation.copyWith(messages: _aiMessages);
        await AiChatService.saveConversation(conversation);
      }
    } catch (e) {
      debugPrint("Error saving to persistent storage: $e");
    }
  }

  // --- PARSING UTILS ---
  ({String content, String? visualizationCode}) _parseAiResponse(
      String rawContent) {
    // Check for both correct and misspelled tags
    final tags = [
      ('[HLT_VISUALIZATION]', '[/HLT_VISUALIZATION]'),
      ('[HLT_VISUALISATION]', '[/HLT_VISUALISATION]'),
    ];

    for (final (startTag, endTag) in tags) {
      final startIndex = rawContent.indexOf(startTag);
      final endIndex = rawContent.indexOf(endTag);

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final codeBlock =
            rawContent.substring(startIndex + startTag.length, endIndex).trim();

        // Extract HTML from markdown code block if present
        String code = codeBlock;
        if (codeBlock.startsWith('```html') && codeBlock.endsWith('```')) {
          code = codeBlock.substring(7, codeBlock.length - 3).trim();
        } else if (codeBlock.startsWith('```') && codeBlock.endsWith('```')) {
          code = codeBlock.substring(3, codeBlock.length - 3).trim();
        }

        // Remove the block from content
        final contentBefore = rawContent.substring(0, startIndex).trim();
        final contentAfter =
            rawContent.substring(endIndex + endTag.length).trim();
        final cleanContent = "$contentBefore\n$contentAfter".trim();

        return (content: cleanContent, visualizationCode: code);
      }
    }

    return (content: rawContent, visualizationCode: null);
  }

  void startUpload() {
    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();
  }

  void updateUploadProgress(double progress) {
    _uploadProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  void finishUpload() {
    _isUploading = false;
    _uploadProgress = 0.0;
    notifyListeners();
  }

  Future<void> startVoiceRecording() async {
    if (_isRecording || isAiConversation) return; // Don't allow recording in AI conversations

    try {
      final filePath = await VoiceRecordingService.startRecording();
      if (filePath != null) {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        // Update UI every second to show recording duration
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          notifyListeners();
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
    }
  }

  Future<void> stopVoiceRecording() async {
    if (!_isRecording) return;

    try {
      final filePath = await VoiceRecordingService.stopRecording();
      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordingStartTime = null;
      notifyListeners();

      if (filePath != null && conversationId != null) {
        final audioFile = File(filePath);
        if (await audioFile.exists()) {
          // Send the audio message
          final message = await FileUploadService.sendAudioMessage(
            conversationId: conversationId!,
            audioFile: audioFile,
          );

          if (message != null) {
            // Scroll to bottom after sending voice message
            _scrollToBottom();
          } else {
            debugPrint('Failed to send audio message');
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping voice recording: $e');
      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordingStartTime = null;
      notifyListeners();
    }
  }

  Future<void> cancelVoiceRecording() async {
    if (!_isRecording) return;

    try {
      await VoiceRecordingService.cancelRecording();
      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordingStartTime = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error canceling voice recording: $e');
      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordingStartTime = null;
      notifyListeners();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  void _scrollToBottomInitial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  Future<void> _generateConversationTitleIfNeeded(
      BuildContext context, String userMessage, String aiResponse) async {
    if (!isAiConversation || aiConversationId == null) return;

    // Check if this is a new conversation with default title
    if (_conversationTitle?.startsWith('New Chat') != true) return;

    // Check if this is the first meaningful exchange (user message + AI response)
    final realMessages = _aiMessages
        .where((m) => !(m.isThinking ?? false) && m.content.isNotEmpty)
        .toList();
    if (realMessages.length < 2)
      return; // Need at least user message + AI response

    try {
      // Generate a title based on the conversation
      final titlePrompt =
          'Based on this conversation, generate a concise, descriptive title (max 6 words) that captures the main topic or purpose:\n\nUser: $userMessage\nAI: $aiResponse\n\nTitle:';

      final aiSettings = context.read<AiSettingsProvider>();
      final userProvider = context.read<UserProvider>();

      final currentUser = userProvider.currentUser;
      final userInfo = currentUser != null
          ? {
              'display_name': currentUser.displayName ?? currentUser.email ?? 'User',
              'username': currentUser.username,
              'email': currentUser.email,
            }
          : null;

      final titleResponse = aiSettings.useDeepMode
          ? await PerplexityService.sendMessage(
              message: titlePrompt,
              conversationHistory: [],
              userInfo: userInfo,
            )
          : await ZaiService.sendMessage(
              message: titlePrompt,
              conversationHistory: [],
              userInfo: userInfo,
            );

      final rawTitle = titleResponse is Map
          ? titleResponse['choices'][0]['message']['content']
          : titleResponse.toString();

      // Clean up the title
      String generatedTitle = rawTitle.trim();
      // Remove quotes if present
      if (generatedTitle.startsWith('"') && generatedTitle.endsWith('"')) {
        generatedTitle = generatedTitle.substring(1, generatedTitle.length - 1);
      }
      if (generatedTitle.startsWith("'") && generatedTitle.endsWith("'")) {
        generatedTitle = generatedTitle.substring(1, generatedTitle.length - 1);
      }

      // Limit to reasonable length
      if (generatedTitle.length > 50) {
        generatedTitle = generatedTitle.substring(0, 47) + '...';
      }

      // Update conversation title
      _conversationTitle = generatedTitle;
      notifyListeners();

      // Save to persistent storage
      try {
        var conversation =
            await AiChatService.getConversation(aiConversationId!);
        if (conversation != null) {
          conversation = conversation.copyWith(title: generatedTitle);
          await AiChatService.saveConversation(conversation);
        }
      } catch (e) {
        debugPrint('Error saving updated conversation title: $e');
      }
    } catch (e) {
      debugPrint('Error generating conversation title: $e');
      // Don't update title if generation fails
    }
  }

  void removeFromNewMessages(Set<String> messageIds) {
    _newMessageIds.removeAll(messageIds);
  }

  void _onTyping() {
    if (conversationId != null) {
      if (messageController.text.isNotEmpty) {
        TypingService.startTyping(conversationId!);
      } else {
        TypingService.stopTyping(conversationId!);
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (conversationId == null || isAiConversation) return;

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final messagesRead = await MessageService.markConversationMessagesAsRead(conversationId!);

      if (messagesRead > 0) {
        // Update local messages to reflect read status
        bool hasUpdates = false;
        for (var i = 0; i < _messages.length; i++) {
          final message = _messages[i];
          // Only mark messages sent by others as read
          if (message.senderId != currentUserId &&
              !message.readBy.any((read) => read.userId == currentUserId)) {
            final updatedReadBy = [...message.readBy, MessageRead(
              userId: currentUserId,
              readAt: DateTime.now(),
            )];
            _messages[i] = message.copyWith(readBy: updatedReadBy);
            hasUpdates = true;
          }
        }
        if (hasUpdates) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }



  // --- MESSAGE GROUPING LOGIC ---
  List<MessageGroup> _groupMessages(List<Message> messages) {
    if (messages.isEmpty) return [];
    final sorted = List<Message>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final groups = <MessageGroup>[];
    Message? lastMessage;

    for (final message in sorted) {
      final isFromMe =
          message.senderId == Supabase.instance.client.auth.currentUser?.id;
      final shouldGroup = lastMessage != null &&
          lastMessage.senderId == message.senderId &&
          message.createdAt.difference(lastMessage.createdAt).inMinutes < 5;

      if (shouldGroup) {
        // Add to existing group
        final lastGroup = groups.last;
        groups[groups.length - 1] = MessageGroup(
          messages: [...lastGroup.messages, message],
          isFromMe: isFromMe,
          timestamp: lastGroup.timestamp,
        );
      } else {
        // Create new group
        groups.add(MessageGroup(
          messages: [message],
          isFromMe: isFromMe,
          timestamp: message.createdAt,
        ));
      }

      lastMessage = message;
    }

    return groups;
  }

  List<AiMessageGroup> _groupAiMessages(List<AiMessage> messages) {
    if (messages.isEmpty) return [];
    final sorted = List<AiMessage>.from(messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final groups = <AiMessageGroup>[];
    AiMessage? lastMessage;

    for (final message in sorted) {
      final shouldGroup = lastMessage != null &&
          lastMessage.isFromUser == message.isFromUser &&
          message.timestamp.difference(lastMessage.timestamp).inMinutes < 5;

      if (shouldGroup) {
        // Add to existing group
        final lastGroup = groups.last;
        groups[groups.length - 1] = AiMessageGroup(
          messages: [...lastGroup.messages, message],
          isFromUser: message.isFromUser,
          timestamp: lastGroup.timestamp,
        );
      } else {
        // Create new group
        groups.add(AiMessageGroup(
          messages: [message],
          isFromUser: message.isFromUser,
          timestamp: message.timestamp,
        ));
      }

      lastMessage = message;
    }

    return groups;
  }

  Future<bool> deleteMessage(String messageId) async {
    debugPrint('🗑️ Attempting to delete message: $messageId');
    try {
      final success = await MessageService.deleteMessage(messageId);
      debugPrint('🗑️ Delete operation result: $success');
      if (success) {
        // Remove from local list immediately as fallback
        final beforeCount = _messages.length;
        _messages.removeWhere((m) => m.id == messageId);
        final afterCount = _messages.length;
        final removedCount = beforeCount - afterCount;
        debugPrint('🗑️ Removed $removedCount messages from local list immediately');
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }
}

// --- MAIN CHAT SCREEN WIDGET ---

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? aiConversationId;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.aiConversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndShowAiWarning();
  }

  Future<void> _checkAndShowAiWarning() async {
    if (widget.aiConversationId != null) {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('ai_data_warning_dismissed') ?? false;

      if (!dismissed && mounted) {
        // Show warning dialog after a brief delay to ensure the screen is built
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const _AiDataWarningDialog(),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        conversationId: widget.conversationId,
        aiConversationId: widget.aiConversationId,
      ),
      child: const _ChatScreenContent(),
    );
  }
}

class _ChatScreenContent extends StatelessWidget {
  const _ChatScreenContent();

  static void _showChatHistory(BuildContext context) async {
    final conversations = await AiChatService.getConversations();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: EdgeInsets.all(AppSizes.paddingMedium),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Chat History',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                                 ),
                               ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                          ),
                          AppSpacing.verticalMedium,
                          Text(
                            'No conversations yet',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                          ),
                          AppSpacing.verticalSmall,
                          Text(
                            'Start a new chat to see it here',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.4),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.all(AppSizes.paddingSmall),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final lastMessage = conversation.messages.isNotEmpty
                            ? conversation.messages.last
                            : null;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              conversation.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            subtitle: lastMessage != null
                                ? Text(
                                    lastMessage.content.length > 50
                                        ? '${lastMessage.content.substring(0, 50)}...'
                                        : lastMessage.content,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    'No messages',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.4),
                                        ),
                                  ),
                            trailing: Text(
                              _formatTime(conversation.messages.isNotEmpty
                                  ? conversation.messages.last.timestamp
                                  : DateTime.now()),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.go(
                                  '/chat?aiConversationId=${conversation.id}');
                            },
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Conversation'),
                                  content: const Text(
                                      'Are you sure you want to delete this conversation?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await AiChatService.deleteConversation(
                                            conversation.id);
                                        Navigator.of(context).pop();
                                        // Refresh the history sheet
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          _showChatHistory(context);
                                        }
                                      },
                                       child: Text('Delete',
                                           style: TextStyle(color: AppColors.error)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _ChatAppBar(onShowHistory: () => _showChatHistory(context)),
      body: Column(
        children: [
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(child: _MessageList()),
                      if (provider.isSomeoneTyping && !provider.isAiConversation)
                        const _TypingIndicator(),
                    ],
                  ),
          ),
          const _ChatInputBar(),
        ],
      ),
    );
  }
}

// --- UI COMPONENTS ---
// --- Reaction Logic ---

class _ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;

  const _ReactionPicker({required this.onReactionSelected});

  @override
  Widget build(BuildContext context) {
    final reactions = ['❤️', '😂', '😮', '😢', '👍', '👎'];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingSmall, vertical: AppSizes.paddingSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactions.map((emoji) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onReactionSelected(emoji),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onShowHistory;

  const _ChatAppBar({this.onShowHistory});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => context.go('/home'),
      ),
      title: Row(
        children: [
          if (provider.isAiConversation) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 16,
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
          ] else ...[
            ProfileAvatar(
              avatarUrl: provider.conversation?.avatarUrl ?? (provider.participants.isNotEmpty ? provider.participants.first.avatarUrl : null),
              displayName: provider.participants.isNotEmpty
                  ? provider.participants.first.displayName ?? provider.participants.first.username ?? provider.participants.first.email
                  : 'Unknown',
              size: 32,
              showBorder: false,
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider.conversationTitle ?? 'Chat',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (provider.isAiConversation)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Chat',
            onPressed: () async {
              // Create a new AI conversation
              final newConversation = AiConversation(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: 'New Chat ${DateTime.now().toString().substring(0, 16)}',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                messages: [],
              );
              await AiChatService.saveConversation(newConversation);
              if (context.mounted) {
                context.go('/chat?aiConversationId=${newConversation.id}');
              }
            },
          ),
        if (provider.isAiConversation) ...[
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat History',
            onPressed: onShowHistory,
          ),
          InkWell(
            onTap: () {
              context.read<AiSettingsProvider>().toggleAiMode();
            },
            borderRadius: AppBorderRadius.medium,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingSmall, vertical: 2),
              decoration: BoxDecoration(
                color: context.watch<AiSettingsProvider>().useDeepMode
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: AppBorderRadius.medium,
              ),
              child: Text(
                context.watch<AiSettingsProvider>().useDeepMode
                    ? 'DEEP'
                    : 'QUICK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: context.watch<AiSettingsProvider>().useDeepMode
                      ? Colors.blue
                      : Colors.green,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Conversation',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Conversation?'),
                  content: const Text(
                      'This will remove all messages from this conversation. This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<ChatProvider>().clearAiConversation();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
           ),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MessageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    if (provider.isAiConversation && provider.aiMessages.isEmpty) {
      return _AiWelcomeScreen();
    }

    final itemCount = provider.isAiConversation
        ? provider.aiMessageGroups.length
        : provider.messageGroups.length;

    if (itemCount == 0) {
      return const Center(child: Text("Send a message to start."));
    }

    return AnimationLimiter(
      child: ListView.builder(
        controller: provider.scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final child = provider.isAiConversation
              ? _AiMessageGroupWidget(group: provider.aiMessageGroups[index])
              : _MessageGroupWidget(group: provider.messageGroups[index]);

          // Add entrance animation for new messages
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium, vertical: AppSizes.paddingSmall),
      margin: const EdgeInsets.only(left: 8, bottom: 8, right: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          AppSpacing.horizontalSmall,
          Text(
            'Someone is typing...',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  final bool isBubble;
  const _ThinkingIndicator({this.isBubble = false});

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If inside bubble, remove container styling as bubble provides it
    if (widget.isBubble) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double start = index * 0.2;
                final double end = start + 0.4;

                double value = 0.0;
                if (_controller.value >= start && _controller.value <= end) {
                  value = (_controller.value - start) / 0.4;
                  if (value > 0.5) value = 1.0 - value;
                  value *= 2.0;
                }

                return Opacity(
                  opacity: 0.3 + (0.7 * value),
                  child: Transform.translate(
                    offset: Offset(0, -4 * value),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      );
    }

    // Standalone widget fallback
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(left: 8, bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double start = index * 0.2;
                final double end = start + 0.4;

                double value = 0.0;
                if (_controller.value >= start && _controller.value <= end) {
                  value = (_controller.value - start) / 0.4;
                  if (value > 0.5) value = 1.0 - value;
                  value *= 2.0;
                }

                return Opacity(
                  opacity: 0.3 + (0.7 * value),
                  child: Transform.translate(
                    offset: Offset(0, -4 * value),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _MessageGroupWidget extends StatelessWidget {
  final MessageGroup group;
  const _MessageGroupWidget({required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    return Align(
      alignment: group.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            group.isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ...group.messages.asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
            final isLast = index == group.messages.length - 1;
            final length = group.messages.length;
            MessagePosition pos;
            if (length == 1) {
              pos = MessagePosition.single;
            } else if (index == 0) {
              pos = MessagePosition.first;
            } else if (index == length - 1) {
              pos = MessagePosition.last;
            } else {
              pos = MessagePosition.middle;
            }
            final messageBubble = _MessageBubble(
              message: message,
              content: message.content,
              messageType: message.type,
              isFromMe: group.isFromMe,
              showTail: pos == MessagePosition.last,
              timestamp: isLast ? message.createdAt : null,
              status: isLast ? message.status : null,
              position: pos,
              reactions: message.reactions,
            );

            // Animate if this message is new
            if (provider.newMessageIds.contains(message.id)) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                onEnd: () {
                  provider.removeFromNewMessages({message.id});
                },
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: messageBubble,
              );
            } else {
              return messageBubble;
            }
          }),
        ],
      ),
    );
  }
}

class _AiMessageGroupWidget extends StatelessWidget {
  final AiMessageGroup group;
  const _AiMessageGroupWidget({required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    return Align(
      alignment:
          group.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: group.isFromUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ...group.messages.asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
            final isLast = index == group.messages.length - 1;
            final length = group.messages.length;
            MessagePosition pos;
            if (length == 1) {
              pos = MessagePosition.single;
            } else if (index == 0) {
              pos = MessagePosition.first;
            } else if (index == length - 1) {
              pos = MessagePosition.last;
            } else {
              pos = MessagePosition.middle;
            }
            final messageBubble = _MessageBubble(
              message: null, // AI messages don't have read receipts
              content: message.content,
              messageType: MessageType.text, // AI messages are always text
              isFromMe: group.isFromUser,
              isAiMessage: !message.isFromUser,
              isThinking: message.isThinking ?? false,
              isStreaming: message.isStreaming,
              reasoningContent: message.reasoning_content,
              showTail: pos == MessagePosition.last,
              timestamp: isLast ? message.timestamp : null,
              position: pos,
              reactions: const [], // Ensure empty reactions for AI messages
              visualizationCode: message.visualizationCode,
            );

            // For AI conversations, animate all messages since they are loaded from storage
            // But for new messages, we want to animate them
            // Since AI messages don't have real-time new detection, we'll animate based on recency
            final isRecent =
                DateTime.now().difference(message.timestamp).inSeconds < 30;

            if (isRecent && !message.isFromUser) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: messageBubble,
              );
            } else {
              return messageBubble;
            }
          }),
        ],
      ),
    );
  }
}

class _TypingCursor extends StatefulWidget {
  const _TypingCursor();

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message? message;
  final String content;
  final MessageType messageType;
  final bool isFromMe;
  final bool isAiMessage;
  final bool isThinking;
  final bool isStreaming;
  final String? reasoningContent;
  final DateTime? timestamp;
  final MessageStatus? status;
  final String? fileName;
  final MessagePosition position;
  final List<MessageReaction> reactions;
  final String? visualizationCode;

  const _MessageBubble({
    this.message,
    required this.content,
    this.messageType = MessageType.text,
    required this.isFromMe,
    this.isAiMessage = false,
    this.isThinking = false,
    this.isStreaming = false,
    this.reasoningContent,
    bool showTail = true,
    this.timestamp,
    this.status,
    this.fileName,
    this.position = MessagePosition.single,
    this.reactions = const [],
    this.visualizationCode,
  });

  void _showReactionPicker(BuildContext context, TapDownDetails details) {
    if (isAiMessage || isThinking || message == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        details.globalPosition,
        details.globalPosition,
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: _ReactionPicker(
            onReactionSelected: (emoji) {
              Navigator.pop(context);
              _handleReaction(context, emoji);
            },
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 12),
              Text('Copy'),
            ],
          ),
        ),
        if (isFromMe)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ).then((value) {
      if (value == 'copy') {
        // Check for Mite tag
        final bool isMiteMessage = content.contains('[HLT_SENT_FROM_MITE]');
        final String displayContent = isMiteMessage
            ? content.replaceAll('[HLT_SENT_FROM_MITE]', '').trim()
            : content;
        Clipboard.setData(ClipboardData(text: displayContent));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied to clipboard'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (value == 'delete') {
        // TODO: Implement delete functionality
      }
    });
  }

  Future<void> _handleReaction(BuildContext context, String emoji) async {
    // Check if user already reacted with this emoji
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || message == null) return;

    final existingReaction = reactions.firstWhereOrNull(
      (r) => r.userId == currentUserId && r.emoji == emoji,
    );

    if (existingReaction != null) {
      await MessageService.removeReaction(messageId: message!.id, emoji: emoji);
    } else {
      await MessageService.addReaction(messageId: message!.id, emoji: emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isFromMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;

    const Radius radius = Radius.circular(18);
    const Radius smallRadius = Radius.circular(4);
    final BorderRadius borderRadius = isFromMe
        ? (position == MessagePosition.single
            ? BorderRadius.only(
                topLeft: radius,
                topRight: radius,
                bottomLeft: radius,
                 bottomRight: smallRadius)
             : position == MessagePosition.first
                ? BorderRadius.only(
                    topLeft: radius,
                    topRight: radius,
                    bottomLeft: radius,
                 bottomRight: smallRadius)
                 : position == MessagePosition.middle
                    ? BorderRadius.only(
                        topLeft: radius,
                        topRight: smallRadius,
                        bottomLeft: radius,
                     bottomRight: smallRadius)
                     : BorderRadius.only(
                         topLeft: radius,
                         topRight: smallRadius,
                         bottomLeft: radius,
                         bottomRight: radius))
         : (position == MessagePosition.single
            ? BorderRadius.only(
                topLeft: radius,
                topRight: radius,
                bottomLeft: radius,
                bottomRight: radius)
             : position == MessagePosition.first
                ? BorderRadius.only(
                    topLeft: radius,
                    topRight: radius,
                    bottomLeft: smallRadius,
                 bottomRight: radius)
                 : position == MessagePosition.middle
                    ? BorderRadius.only(
                        topLeft: smallRadius,
                        topRight: radius,
                        bottomLeft: smallRadius,
                        bottomRight: radius)
                    : BorderRadius.only(
                        topLeft: smallRadius,
                        topRight: radius,
                        bottomLeft: radius,
                        bottomRight: radius));

    // Check for Mite tag
    final bool isMiteMessage = content.contains('[HLT_SENT_FROM_MITE]');
    final String displayContent = isMiteMessage
        ? content.replaceAll('[HLT_SENT_FROM_MITE]', '').trim()
        : content;

    // Determine bubble decoration
    BoxDecoration bubbleDecoration;
    if (isMiteMessage) {
      bubbleDecoration = BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF8B5CF6), // Violet
            Color(0xFFD946EF), // Fuchsia
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );
    } else {
      bubbleDecoration = BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Column(
        crossAxisAlignment:
            isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onDoubleTapDown: (details) => _showReactionPicker(context,
                details), // Long press for menu including reactions
            onLongPressStart: (details) => _showReactionPicker(context,
                TapDownDetails(globalPosition: details.globalPosition)),
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 8),
              decoration: bubbleDecoration,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isThinking
                            ? const _ThinkingIndicator(isBubble: true)
                            : _buildMessageContent(
                                context, displayContent, messageType, isFromMe, isMiteMessage,
                                fileName, timestamp, reasoningContent, isStreaming),
                        if (visualizationCode != null && !isThinking) ...[
                          AppSpacing.verticalSmall,
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VisualizationScreen(
                                    htmlCode: visualizationCode!,
                                  ),
                                ),
                              );
                            },
                            borderRadius: AppBorderRadius.medium,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMiteMessage
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                borderRadius: AppBorderRadius.medium,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.preview,
                                      size: 18,
                                      color: isMiteMessage
                                          ? Colors.white
                                          : theme.colorScheme.primary),
                                  AppSpacing.horizontalSmall,
                                  Text(
                                    'Open Preview',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isMiteMessage
                                          ? Colors.white
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                           ],
                         ),
                        ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (reactions.isNotEmpty)
                    Positioned(
                      bottom: -20,
                      right: isFromMe ? 0 : null,
                      left: isFromMe ? null : 0,
                      child: _ReactionsDisplay(reactions: reactions),
                    ),
                ],
              ),
            ),
          ),
          if (reactions.isNotEmpty)
            const SizedBox(height: 16), // Space for reactions
          if (timestamp != null)
            Padding(
              padding: EdgeInsets.only(
                left: isFromMe ? 0 : 16,
                right: isFromMe ? 16 : 0,
                bottom: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMiteMessage) ...[
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mite Quick',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.horizontalSmall,
                  ],
                  Text(
                    _formatTimestamp(timestamp!),
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                   if (status != null && isFromMe) ...[
                     const SizedBox(width: 4),
                     Icon(
                       _getStatusIcon(status!, message: message),
                       size: 12,
                       color: _getStatusIconColor(status!, message: message, theme: theme),
                     ),
                   ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }



  IconData _getStatusIcon(MessageStatus status, {Message? message}) {
    // If we have message data, check read receipts for more accurate status
    if (message != null && message.senderId == Supabase.instance.client.auth.currentUser?.id) {
      if (message.readBy.isNotEmpty) {
        return Icons.done_all; // Read by someone
      } else if (status == MessageStatus.delivered || status == MessageStatus.sent) {
        return Icons.check; // Delivered but not read
      }
    }

    switch (status) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusIconColor(MessageStatus status, {Message? message, required ThemeData theme}) {
    // If message has been read by someone, use primary color (like blue in WhatsApp)
    if (message != null && message.readBy.isNotEmpty) {
      return theme.colorScheme.primary;
    }

    // Otherwise use muted color
    return theme.colorScheme.onSurface.withValues(alpha: 0.6);
  }

}

  Widget _buildMessageContent(BuildContext context, String content, MessageType messageType, bool isFromMe, bool isMite,
      [String? fileName, DateTime? timestamp, String? reasoningContent, bool isStreaming = false]) {
    final theme = Theme.of(context);
    final textColor = isMite
        ? Colors.white
        : (isFromMe
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface);
    final baseStyle = TextStyle(color: textColor, fontSize: 16, height: 1.4);

    // Handle different message types
    switch (messageType) {
      case MessageType.image:
        return FileMessageWidget(
          fileUrl: content,
          fileName: fileName ?? _extractFileNameFromUrl(content),
          isFromMe: isFromMe,
          timestamp: timestamp ?? DateTime.now(),
        );
      case MessageType.file:
        return FileMessageWidget(
          fileUrl: content,
          fileName: fileName ?? _extractFileNameFromUrl(content),
          isFromMe: isFromMe,
          timestamp: timestamp ?? DateTime.now(),
        );
      case MessageType.audio:
        return AudioMessageWidget(
          audioUrl: content,
          isFromMe: isFromMe,
          timestamp: timestamp ?? DateTime.now(),
        );
      case MessageType.video:
        // TODO: Implement video message widget
        return Text('🎥 Video message', style: baseStyle);
      case MessageType.text:
      default:
        // Parse for visualization
        String displayContent = content;
        String? vizCode;
        const startTag = '[HLT_VISUALIZATION]';
        const endTag = '[/HLT_VISUALIZATION]';
        final startIndex = content.indexOf(startTag);
        final endIndex = content.indexOf(endTag);
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final codeBlock = content
            .substring(startIndex + startTag.length, endIndex)
            .trim();
          String code = codeBlock;
          if (codeBlock.startsWith('```html') && codeBlock.endsWith('```')) {
            code = codeBlock.substring(7, codeBlock.length - 3).trim();
          }
          vizCode = code;
          displayContent = content
              .replaceRange(startIndex, endIndex + endTag.length, '')
              .trim();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show reasoning content if available
            if (reasoningContent != null && reasoningContent!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, size: AppSizes.iconSmall, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Thinking...',
                          style: baseStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reasoningContent!,
                      style: baseStyle.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Main content with typing cursor if streaming
            Stack(
              children: [
                _buildCustomText(_preprocessMiteMentions(_preprocessMarkdown(displayContent)), baseStyle),
                if (isStreaming)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _TypingCursor(),
                  ),
              ],
            ),
            if (vizCode != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => VisualizationScreen(
                        htmlCode: vizCode!,
                        title: 'Visualization',
                      ),
                    ),
                  );
                },
                borderRadius: AppBorderRadius.medium,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFromMe
                        ? theme.colorScheme.surface.withValues(alpha: 0.2)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: AppBorderRadius.medium,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.preview,
                          size: 18,
                          color: isFromMe
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.primary),
                      AppSpacing.horizontalSmall,
                      Text(
                        'Open Preview',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isFromMe
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ],
        );
    }
  }

  String _preprocessMarkdown(String text) {
    // Convert markdown to font tags
    // Process in order: code blocks, inline code, bold, italic, strikethrough

    // Code blocks (```text```)
    text = text.replaceAllMapped(
      RegExp(r'```(.*?)```', dotAll: true),
      (match) => '[font:mono]${match.group(1)}[/font]',
    );

    // Inline code (`text`)
    text = text.replaceAllMapped(
      RegExp(r'`([^`\n]+)`'),
      (match) => '[font:mono]${match.group(1)}[/font]',
    );

    // Bold (**text**)
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => '[font:bold]${match.group(1)}[/font]',
    );

    // Italic (*text*)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'),
      (match) => '[font:italic]${match.group(1)}[/font]',
    );

    // Strikethrough (~~text~~)
    text = text.replaceAllMapped(
      RegExp(r'~~(.*?)~~'),
      (match) => '[font:strikethrough]${match.group(1)}[/font]',
    );

    return text;
  }



  String _preprocessMiteMentions(String text) {
    // Replace @mite with [font:bold]@mite[/font] to make it bold
    return text.replaceAll('@mite', '[font:bold]@mite[/font]');
  }

  Widget _buildCustomText(String text, TextStyle baseStyle) {
    // Parse custom font tags: [font:name]text[/font]
    final RegExp fontRegex = RegExp(r'\[font:([^\]]+)\](.*?)\[/font\]');
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final Match match in fontRegex.allMatches(text)) {
      // Add text before the font tag
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      // Add the font-styled text
      final String fontName = match.group(1)!;
      final String fontText = match.group(2)!;
      spans.add(TextSpan(
        text: fontText,
        style: _getFontStyle(baseStyle, fontName),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    // If no font tags found, return regular text
    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  TextStyle _getFontStyle(TextStyle baseStyle, String fontName) {
    final String normalizedFontName = fontName.toLowerCase().trim();

    switch (normalizedFontName) {
      case 'mono':
      case 'monospace':
      case 'jetbrains':
      case 'jetbrainsmono':
        return GoogleFonts.jetBrainsMono(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'serif':
      case 'merriweather':
        return GoogleFonts.merriweather(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'script':
      case 'cursive':
      case 'dancing':
      case 'dancingscript':
        return GoogleFonts.dancingScript(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'roboto':
        return GoogleFonts.roboto(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'opensans':
      case 'open_sans':
        return GoogleFonts.openSans(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'lato':
        return GoogleFonts.lato(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'playfair':
      case 'playfairdisplay':
        return GoogleFonts.playfairDisplay(
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
          color: baseStyle.color,
          fontWeight: baseStyle.fontWeight,
        );
      case 'bold':
        return baseStyle.copyWith(fontWeight: FontWeight.bold);
      case 'italic':
        return baseStyle.copyWith(fontStyle: FontStyle.italic);
      case 'underline':
        return baseStyle.copyWith(decoration: TextDecoration.underline);
      case 'strikethrough':
      case 'strike':
        return baseStyle.copyWith(decoration: TextDecoration.lineThrough);
      default:
        // Try to use the font name directly if it's a Google Font
        try {
          // First try the font name as-is
          debugPrint('Trying to load Google Font: $fontName');
          return GoogleFonts.getFont(
            fontName,
            fontSize: baseStyle.fontSize,
            height: baseStyle.height,
            color: baseStyle.color,
            fontWeight: baseStyle.fontWeight,
          );
        } catch (e) {
          try {
            // If that fails, try different cleaning approaches
            // Method 1: Remove spaces and capitalize each word
            final String pascalCase = fontName.split(' ').map((word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
            ).join('');
            debugPrint('Trying PascalCase font name: $pascalCase');

            return GoogleFonts.getFont(
              pascalCase,
              fontSize: baseStyle.fontSize,
              height: baseStyle.height,
              color: baseStyle.color,
              fontWeight: baseStyle.fontWeight,
            );
          } catch (e2) {
            try {
              // Method 2: Remove all spaces and special chars completely
              final String cleanFontName = fontName.replaceAll(RegExp(r'[^a-zA-Z]'), '');
              debugPrint('Trying cleaned font name: $cleanFontName');

              return GoogleFonts.getFont(
                cleanFontName,
                fontSize: baseStyle.fontSize,
                height: baseStyle.height,
                color: baseStyle.color,
                fontWeight: baseStyle.fontWeight,
              );
            } catch (e3) {
              debugPrint('Failed to load font "$fontName" (tried multiple formats): $e3');
              // Fallback to base style if font not found
              return baseStyle;
            }
          }
        }
    }
  }



  Future<void> _showDeleteConfirmation(BuildContext context, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<ChatProvider>(context, listen: false);
      final success = await provider.deleteMessage(messageId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Message deleted' : 'Failed to delete message'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }



  String _extractFileNameFromUrl(String url) {
    try {
      // Extract filename from Supabase URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last;
      }
      return 'Unknown file';
    } catch (e) {
      return 'Unknown file';
    }
  }

class _ReactionsDisplay extends StatelessWidget {
  final List<MessageReaction> reactions;

  const _ReactionsDisplay({required this.reactions});

  @override
  Widget build(BuildContext context) {
    // Group reactions by emoji
    final Map<String, int> reactionCounts = {};
    for (var r in reactions) {
      reactionCounts[r.emoji] = (reactionCounts[r.emoji] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactionCounts.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${e.key} ${e.value > 1 ? e.value : ""}',
              style: const TextStyle(fontSize: 10),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar();

  void _showAttachmentSheet(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<ChatProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Attachment',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalLarge,
            Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _AttachmentOption(
                      icon: Icons.image,
                      label: 'Image',
                      color: Colors.blue,
                      onTap: () => _pickImage(context, provider),
                    ),
                  ),
                ),
                AppSpacing.horizontalMedium,
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _AttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: 'File',
                      color: Colors.green,
                      onTap: () => _pickFile(context, provider),
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalLarge,
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ChatProvider provider) async {
    Navigator.of(context).pop(); // Close the attachment sheet

    try {
      final result = await FilePickerService.pickImage();

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);

        // Check file size (max 10MB for images)
        if (!FilePickerService.isValidFileSize(file, maxSizeInMB: 10)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Image file is too large (max 10MB)')),
            );
          }
          return;
        }

        // Start upload progress
        provider.startUpload();

        // Simulate upload progress
        _simulateUploadProgress(provider);

        // Upload and send message
        final message = await FileUploadService.sendImageMessage(
          conversationId: provider.conversationId!,
          imageFile: file,
        );

        // Finish upload
        provider.finishUpload();

        if (message != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image sent successfully!')),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send image')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _pickFile(BuildContext context, ChatProvider provider) async {
    Navigator.of(context).pop(); // Close the attachment sheet

    try {
      final result = await FilePickerService.pickAnyFile();

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);

        // Check file size (max 10MB for files)
        if (!FilePickerService.isValidFileSize(file, maxSizeInMB: 10)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File is too large (max 10MB)')),
            );
          }
          return;
        }

        // Start upload progress
        provider.startUpload();

        // Simulate upload progress
        _simulateUploadProgress(provider);

        // Upload and send message
        final message = await FileUploadService.sendDocumentMessage(
          conversationId: provider.conversationId!,
          documentFile: file,
        );

        // Finish upload
        provider.finishUpload();

        if (message != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File sent successfully!')),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send file')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick file')),
        );
      }
    }
  }

  void _simulateUploadProgress(ChatProvider provider) {
    // Simulate upload progress (in real implementation, this would come from upload service callbacks)
    const totalSteps = 20;
    var currentStep = 0;

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentStep++;
      final progress = currentStep / totalSteps;

      if (currentStep >= totalSteps || !provider.isUploading) {
        timer.cancel();
        return;
      }

      provider.updateUploadProgress(progress);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final isRecording = provider.isRecording;

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
                top: BorderSide(color: theme.dividerColor, width: 0.5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Animated attachment/AI settings buttons
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.2, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              ),
                child: !isRecording && !provider.isAiConversation
                    ? SizedBox(
                      key: const ValueKey('attachment'),
                      height: 48,
                      width: 48,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add attachment',
                        onPressed: () => _showAttachmentSheet(context),
                      ),
                    )
                  : !isRecording && provider.isAiConversation
                      ? SizedBox(
                          key: const ValueKey('ai_settings'),
                          height: 48,
                          width: 48,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.memory),
                            tooltip: 'AI Settings',
                            onPressed: () => context.push(AppConstants.aiSettingsRoute),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('hidden')),
            ),

            // Animated text field / recording indicator
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                ),
                child: !isRecording
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          key: const ValueKey('text_field'),
                          child: Stack(
                            alignment: Alignment.center,
                             children: [
                               TextField(
                                 controller: provider.messageController,
                                 focusNode: provider.inputFocusNode,
                                 textCapitalization: TextCapitalization.sentences,
                                 maxLines: 5,
                                 minLines: 1,
                                 keyboardType: TextInputType.multiline,
                                 textInputAction: Platform.isWindows || Platform.isMacOS || Platform.isLinux
                                     ? TextInputAction.send
                                     : TextInputAction.newline,
                                 onSubmitted: Platform.isWindows || Platform.isMacOS || Platform.isLinux
                                     ? (value) => provider.sendMessage(context)
                                     : null,

                                decoration: InputDecoration(
                                  hintText: provider.isAiConversation
                                      ? (context.watch<AiSettingsProvider>().useDeepMode
                                          ? 'Ask Mite Deep...'
                                          : 'Ask Mite Quick...')
                                      : 'Type a message...',
                                  fillColor: theme.colorScheme.surfaceContainerHighest,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: AppBorderRadius.xLarge,
                                    borderSide: BorderSide.none,
                                  ),
                                 ),
                                  ),
                                if (provider.isUploading)
                                  Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: AppBorderRadius.xLarge,
                                    child: LinearProgressIndicator(
                                      value: provider.uploadProgress,
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: AnimatedContainer(
                          key: const ValueKey('recording_indicator'),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        child: Row(
                          children: [
                            // Animated recording dot with pulse effect
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 1.0, end: 1.3),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeInOut,
                              builder: (context, scale, child) => TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 1.3, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeInOut,
                                builder: (context, reverseScale, child) => Transform.scale(
                                  scale: scale * reverseScale,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.6),
                                          blurRadius: 8 * scale,
                                          spreadRadius: 2 * scale,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Animated "Recording..." text
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 1500),
                              curve: Curves.easeInOut,
                              builder: (context, opacity, child) => Opacity(
                                opacity: opacity,
                                child: Text(
                                  'Recording...',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Animated duration text with slide in
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(10 * (1 - value), 0),
                                  child: Text(
                                    provider.formatDuration(provider.recordingDuration),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFeatures: [const FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),

            // Animated action buttons
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.2, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: provider.messageController,
                builder: (context, value, child) {
                  final isTextEmpty = value.text.isEmpty;

                  if (!isRecording && !isTextEmpty) {
                    // Text is not empty - send message
                    return SizedBox(
                      key: const ValueKey('send_button'),
                      height: 48,
                      width: 48,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.send),
                        onPressed: () => provider.sendMessage(context),
                      ),
                    );
                  } else if (isRecording) {
                    // Currently recording - show recording controls
                    return Row(
                      key: const ValueKey('recording_controls'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stop/Send recording button with bounce animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) => Transform.scale(
                            scale: value,
                            child: SizedBox(
                              height: 48,
                              width: 48,
                              child: IconButton.filled(
                                style: IconButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.red,
                                ),
                                icon: const Icon(Icons.stop),
                                onPressed: () => provider.stopVoiceRecording(),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.horizontalSmall,
                        // Cancel recording button with slide animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(20 * (1 - value), 0),
                              child: SizedBox(
                                height: 48,
                                width: 48,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => provider.cancelVoiceRecording(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Not recording and no text - start recording
                    return SizedBox(
                      key: const ValueKey('mic_button'),
                      height: 48,
                      width: 48,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.mic),
                        onPressed: () async {
                          // Add haptic feedback if available
                          try {
                            // Note: Haptic feedback would require vibration package
                            // For now, we'll just start recording
                            await provider.startVoiceRecording();
                          } catch (e) {
                            debugPrint('Error starting recording: $e');
                          }
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.large,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppBorderRadius.large,
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiDataWarningDialog extends StatefulWidget {
  const _AiDataWarningDialog();

  @override
  State<_AiDataWarningDialog> createState() => _AiDataWarningDialogState();
}

class _AiDataWarningDialogState extends State<_AiDataWarningDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: EdgeInsets.all(AppSizes.paddingLarge),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppBorderRadius.large,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Data Collection Notice',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Mite AI can collect and read your profile information (such as your name, username, and email) to provide personalized responses. This data is used only for improving your chat experience and is not shared with third parties.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.verticalLarge,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _dismissPermanently(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                        child: const Text('Don\'t Show Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dismissPermanently(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_data_warning_dismissed', true);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }


}

class _AiWelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final suggestions = [
      "What are the news for today?",
      "Explain quantum computing in simple terms",
      "Write a creative story about AI",
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: AnimationLimiter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              Icon(Icons.smart_toy_outlined,
                   size: 60, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text("Hello! I'm Mite AI",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                "Ask me anything or try a suggestion.",
                   style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ...suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ActionChip(
                      padding: const EdgeInsets.all(12),
                      label: Text(s),
                      onPressed: () {
                        context.read<ChatProvider>().messageController.text = s;
                        context.read<ChatProvider>().sendMessage(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
