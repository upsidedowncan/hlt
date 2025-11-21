import 'dart:io';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/zai_service.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/repositories/ai_chat_service.dart';
import '../../../shared/repositories/conversation_service.dart';
import '../../../shared/repositories/profile_service.dart';

enum ViewMode { preview, code }

class VisualizationScreen extends StatefulWidget {
  final String htmlCode;
  final String title;
  final String? aiConversationId;

  const VisualizationScreen({
    super.key,
    required this.htmlCode,
    this.title = 'Visualization',
    this.aiConversationId,
  });

  @override
  State<VisualizationScreen> createState() => _VisualizationScreenState();
}

class _VisualizationScreenState extends State<VisualizationScreen>
    with TickerProviderStateMixin {
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = true;

  late final String _processedHtml;
  ViewMode _viewMode = ViewMode.preview;
  late TextEditingController _codeController;
  late TextEditingController _editPromptController;
  WebViewController? _webViewController;
  bool _isEditingCode = false;
  String _reasoningText = '';
  late AnimationController _reasoningFadeController;
  late Animation<double> _reasoningFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Basic HTML wrapper if not provided
    String fullHtml = widget.htmlCode;
    if (!fullHtml.trim().toLowerCase().startsWith('<!doctype html>') &&
        !fullHtml.trim().toLowerCase().startsWith('<html')) {
      fullHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background-color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    * {
      box-sizing: border-box;
    }

    /* Smooth animations */
    .animate-fade-in {
      animation: fadeIn 0.8s ease-in-out;
    }

    .animate-slide-up {
      animation: slideUp 0.6s ease-out;
    }

    .animate-scale-in {
      animation: scaleIn 0.5s ease-out;
    }

    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @keyframes slideUp {
      from {
        opacity: 0;
        transform: translateY(30px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    @keyframes scaleIn {
      from {
        opacity: 0;
        transform: scale(0.9);
      }
      to {
        opacity: 1;
        transform: scale(1);
      }
    }

    /* Apply animations to common elements */
    svg, canvas, div, p, h1, h2, h3, h4, h5, h6 {
      animation: fadeIn 0.8s ease-in-out;
    }

    /* Chart.js animations */
    .chart-container {
      animation: slideUp 0.6s ease-out;
    }
  </style>
</head>
<body>
  <div class="animate-fade-in">
    ${widget.htmlCode}
  </div>
</body>
</html>
      ''';
    }
    _processedHtml = fullHtml;

    _codeController = TextEditingController(text: widget.htmlCode);
    _codeController.addListener(_onCodeChanged);
    _editPromptController = TextEditingController();
    _reasoningFadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _reasoningFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _reasoningFadeController, curve: Curves.easeOut),
    );
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Theme.of(context).colorScheme.surface)
        ..loadHtmlString(_processedHtml);
    }
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await ConversationService.getUserConversations();
      setState(() {
        _conversations = conversations;
        _isLoadingConversations = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingConversations = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversations: $e')),
      );
    }
  }

  void _shareVisualization() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Visualization',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isLoadingConversations)
                const CircularProgressIndicator()
              else if (_conversations.isEmpty)
                const Text('No conversations available')
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return ListTile(
                        title: Text(conversation.name ?? 'Untitled'),
                        subtitle: Text('${conversation.participantIds.length} participants'),
                        onTap: () => _sendToConversation(conversation),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendToConversation(Conversation conversation) async {
    try {
      // Format the HTML code with visualization tags
      final formattedMessage = '[HLT_VISUALIZATION]${widget.htmlCode}[/HLT_VISUALIZATION]';

      // Create a message to send to the conversation
      final messageData = {
        'conversation_id': conversation.id,
        'content': formattedMessage,
        'sender_id': Supabase.instance.client.auth.currentUser?.id,
        'message_type': 'text',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Insert the message into the database
      await Supabase.instance.client
          .from('messages')
          .insert(messageData);

      // Close the bottom sheet
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visualization shared to ${conversation.name ?? 'conversation'}!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share visualization: $e')),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _editPromptController.dispose();
    _reasoningFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareVisualization,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ViewMode>(
              segments: const [
                ButtonSegment(
                  value: ViewMode.preview,
                  label: Text('Preview'),
                ),
                ButtonSegment(
                  value: ViewMode.code,
                  label: Text('Code'),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _viewMode = newSelection.first;
                });
              },
            ),
          ),
        ),
      ),
      body: _viewMode == ViewMode.preview ? _buildPreview() : _buildCodeEditor(),
    );
  }

  Widget _buildPreview() {
    if (_webViewController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.window, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Visualizations are not supported on this platform',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return WebViewWidget(controller: _webViewController!);
    }
  }

  Widget _buildCodeEditor() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e1e1e),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _codeController,
                    maxLines: null,
                    expands: true,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintText: 'Edit HTML code...',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                if (_reasoningText.isNotEmpty)
                  AnimatedBuilder(
                    animation: _reasoningFadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _reasoningFadeAnimation.value,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: (1 - _reasoningFadeAnimation.value) * 5,
                            sigmaY: (1 - _reasoningFadeAnimation.value) * 5,
                          ),
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _reasoningText,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editPromptController,
                  decoration: const InputDecoration(
                    hintText: 'Ask Mite to edit the code...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _askMiteToEditCode(),
                ),
              ),
              _isEditingCode
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _askMiteToEditCode,
                    ),
            ],
          ),
        ),
      ],
    );
  }



  Future<void> _askMiteToEditCode() async {
    final prompt = _editPromptController.text.trim();
    if (prompt.isEmpty || _isEditingCode) return;

    setState(() {
      _isEditingCode = true;
      _reasoningText = '';
      _reasoningFadeController.value = 1.0; // Reset fade
    });

    try {
      // Fetch fresh user profile via RPC
      final userProfile = await ProfileService.getCurrentUserProfile();
      debugPrint('VisualizationScreen: Fetched user profile: $userProfile');
      final userInfo = userProfile != null
          ? {
              'display_name': userProfile.displayName,
              'username': userProfile.username,
              'email': userProfile.email,
              'platform': Platform.operatingSystem,
            }
          : {'platform': Platform.operatingSystem};
      debugPrint('VisualizationScreen: User info for Mite: $userInfo');

      final fullPrompt = 'Edit this HTML code as requested. Output ONLY the complete edited HTML code, nothing else.\n\nOriginal code:\n${_codeController.text}\n\nRequest: $prompt';

      final stream = await ZaiService.streamMessage(
        message: fullPrompt,
        conversationHistory: [],
        userInfo: userInfo,
      );

      String editedCode = '';
      bool hasStartedContent = false;

      await for (final chunk in stream) {
        if (chunk.done) {
          break;
        } else if (chunk.type == StreamingTokenType.reasoning && chunk.token != null) {
          setState(() {
            _reasoningText += chunk.token!;
          });
        } else if (chunk.type == StreamingTokenType.content && chunk.token != null) {
          if (!hasStartedContent) {
            hasStartedContent = true;
            _reasoningFadeController.forward(); // Start fading out reasoning
          }
          editedCode += chunk.token!;
          setState(() {
            _codeController.text = editedCode.trim();
          });
        }
      }

      _editPromptController.clear();

      // Save the updated code to conversation history
      if (widget.aiConversationId != null) {
        try {
          final updatedMessage = AiMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: 'Updated visualization code',
            isFromUser: false,
            timestamp: DateTime.now(),
            visualizationCode: editedCode,
          );

          var conversation = await AiChatService.getConversation(widget.aiConversationId!);
          if (conversation != null) {
            conversation.messages.add(updatedMessage);
            await AiChatService.saveConversation(conversation);
          }
        } catch (e) {
          debugPrint('Error saving updated code to history: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code updated by Mite!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit code: $e')),
      );
    } finally {
      setState(() {
        _isEditingCode = false;
      });
    }
  }

  void _onCodeChanged() {
    if (_webViewController != null) {
      _webViewController!.loadHtmlString(_codeController.text);
    }
  }
}