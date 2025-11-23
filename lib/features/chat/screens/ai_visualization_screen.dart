import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/zai_service.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/models/ai_conversation.dart';
import '../../../shared/repositories/ai_chat_service.dart';

class AiVisualizationScreen extends StatefulWidget {
  const AiVisualizationScreen({super.key});

  @override
  State<AiVisualizationScreen> createState() => _AiVisualizationScreenState();
}

class _AiVisualizationScreenState extends State<AiVisualizationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<AiMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String? _conversationId;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _fadeController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  Future<void> _initializeConversation() async {
    _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
    final conversation = AiConversation(
      id: _conversationId!,
      title: 'AI Visualization Chat ${DateTime.now().toString().substring(0, 16)}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );
    await AiChatService.saveConversation(conversation);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveToPersistentStorage() async {
    if (_conversationId == null) return;
    try {
      var conversation = await AiChatService.getConversation(_conversationId!);
      if (conversation != null) {
        conversation = conversation.copyWith(messages: _messages, updatedAt: DateTime.now());
        await AiChatService.saveConversation(conversation);
      }
    } catch (e) {
      debugPrint("Error saving to persistent storage: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _isTyping = true;
    });

    // Add user message
    final userMessage = AiMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      isFromUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _messageController.clear();
    _scrollToBottom();

    try {
      // Get conversation history
      final conversationHistory = _messages
          .map((msg) => {
                'role': msg.isFromUser ? 'user' : 'assistant',
                'content': msg.content,
              })
          .toList();

      // Get user info
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userInfo = {
        'display_name': userProvider.currentUser?.displayName ?? 'User',
        'username': userProvider.currentUser?.username,
        'email': userProvider.currentUser?.email,
        'platform': 'mobile',
      };

      // Send to AI
      final response = await ZaiService.sendMessage(
        message: message,
        conversationHistory: conversationHistory,
        userInfo: userInfo,
      );

      final aiContent = response['choices'][0]['message']['content'] as String;

      // Check for visualization
      final visualizationRegex = RegExp(r'\[HLT_VISUALIZATION\](.*?)\[/HLT_VISUALIZATION\]', dotAll: true);
      final match = visualizationRegex.firstMatch(aiContent);

      if (match != null) {
        final htmlCode = match.group(1)!;
        // Remove the visualization tags from the text content
        final textContent = aiContent.replaceAll(visualizationRegex, '').trim();

        // Add AI message with visualization
        final aiMessage = AiMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: textContent.isNotEmpty ? textContent : 'Here\'s your visualization!',
          isFromUser: false,
          timestamp: DateTime.now(),
          visualizationCode: htmlCode,
        );
        _messages.add(aiMessage);
      } else {
        // Regular message
        final aiMessage = AiMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiContent,
          isFromUser: false,
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);
      }
      // Save to persistent storage
      await _saveToPersistentStorage();
    } catch (e) {
      final errorMessage = AiMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Sorry, I encountered an error: $e',
        isFromUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(errorMessage);
      await _saveToPersistentStorage();
    } finally {
      setState(() {
        _isLoading = false;
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Visualization'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ask me to visualize anything!',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try: "Draw a sine wave" or "Create a bar chart of monthly sales"',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator();
                        }

                        final message = _messages[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: _buildMessageBubble(message),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage message) {
    final isFromUser = message.isFromUser;
    return Align(
      alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isFromUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isFromUser ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isFromUser ? const Radius.circular(4) : const Radius.circular(18),
          ),
        ),
        child: Text(
          message.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isFromUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI is thinking',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ask for a visualization...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isLoading ? null : _sendMessage,
            mini: true,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}