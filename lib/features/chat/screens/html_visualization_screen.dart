import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/zai_service.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/models/ai_conversation.dart';
import '../../../shared/repositories/ai_chat_service.dart';
import '../screens/visualization_screen.dart';

class AnimatedText extends StatefulWidget {
  const AnimatedText({super.key});

  @override
  State<AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText> {
  final List<String> _texts = [
    'Hold on...',
    'Processing...',
    'Almost there...',
    'Generating...',
    'Creating magic...',
  ];

  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _texts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        _texts[_currentIndex],
        key: ValueKey<String>(_texts[_currentIndex]),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PulsingCircle extends StatefulWidget {
  final double size;

  const _PulsingCircle({this.size = 16});

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
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
            width: widget.size,
            height: widget.size,
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

class HtmlVisualizationScreen extends StatefulWidget {
  const HtmlVisualizationScreen({super.key});

  @override
  State<HtmlVisualizationScreen> createState() => _HtmlVisualizationScreenState();
}

class _HtmlVisualizationScreenState extends State<HtmlVisualizationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<AiMessage> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamingHtml = '';
  String _streamingReasoning = '';
  String _finalHtml = '';
  String? _conversationId;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

   late AnimationController _scaleController;
   late Animation<double> _scaleAnimation;

   late AnimationController _slideController;
   late Animation<double> _slideAnimation;

   late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    // Main fade animation
    _fadeController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Scale animation for elements
    _scaleController = AnimationController(
      duration: AppConstants.shortAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Slide animation for transitions
    _slideController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    // Create curved animation for ease out effect
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );

    // Glow animation for input focus effect
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Add focus listener for glow animation
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _glowController.repeat();
      } else {
        _glowController.stop();
        _glowController.reset();
      }
      setState(() {});
    });

    // Initialize conversation
    _initializeConversation();

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
     _scaleController.dispose();
     _slideController.dispose();
     _glowController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    _conversationId = 'html_visualizations'; // Fixed ID for all visualizations
    var conversation = await AiChatService.getConversation(_conversationId!);
    if (conversation == null) {
      conversation = AiConversation(
        id: _conversationId!,
        title: 'HTML Visualizations',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      await AiChatService.saveConversation(conversation);
    }
    // Load existing messages
    _messages = conversation.messages;
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

      setState(() {
      _isLoading = true;
      _isStreaming = true;
      _streamingHtml = '';
      _streamingReasoning = '';
      _finalHtml = '';
    });

    try {
      // Get user info
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userInfo = {
        'display_name': userProvider.currentUser?.displayName ?? userProvider.currentUser?.email ?? 'User',
        'username': userProvider.currentUser?.username,
        'email': userProvider.currentUser?.email,
        'platform': 'mobile',
      };

      // Custom system prompt for HTML-only responses
      final customSystemPrompt = '''
You are an HTML expert. Your task is to generate ONLY valid HTML code that creates beautiful, interactive content based on the user's request.

IMPORTANT RULES:
- Return ONLY HTML code, no explanations, no markdown, no text outside of HTML tags
- Start directly with <!DOCTYPE html> or <html>
- Include all necessary CSS and JavaScript within the HTML
- Use modern web technologies and CDNs as needed
- Make content responsive and mobile-friendly
- Include smooth animations and transitions where appropriate
- Use beautiful colors and modern design
- Ensure the HTML is complete and runnable

CONTENT TYPES:
- If the user wants a game, create an interactive game
- If the user wants a visualization, create data visualizations
- If the user wants a simulation, create an interactive simulation
- If the user wants any interactive content, make it engaging and fun
- Adapt to whatever the user requests - games, visualizations, tools, etc.

UI COMPONENTS:
- For UI components (buttons, forms, cards, etc.), use a UI library CDN like Tailwind CSS
- Do not create your own UI styling - always use established UI libraries
- For interactive elements, use appropriate JavaScript libraries

The user will describe what they want. Generate the complete HTML code that fulfills their request exactly.
''';

      // Use streaming for real-time HTML generation
      final stream = await ZaiService.streamMessage(
        message: message,
        conversationHistory: _messages.map((msg) => {
          'role': msg.isFromUser ? 'user' : 'assistant',
          'content': msg.content,
        }).toList(),
        userInfo: userInfo,
        customSystemPrompt: customSystemPrompt,
      );

      await for (final chunk in stream) {
        if (chunk.done) {
          setState(() {
            _isStreaming = false;
            _finalHtml = _streamingHtml;
          });

          // Add messages to history
          final userMessage = AiMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: message,
            isFromUser: true,
            timestamp: DateTime.now(),
          );

          final aiMessage = AiMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: 'Here\'s your visualization!',
            isFromUser: false,
            timestamp: DateTime.now(),
            reasoning_content: _streamingReasoning.isNotEmpty ? _streamingReasoning : null,
            visualizationCode: _finalHtml,
          );

          _messages.add(userMessage);
          _messages.add(aiMessage);

          // Save to persistent storage
          await _saveToPersistentStorage();

          // Navigate to VisualizationScreen after a short delay to show final result
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => VisualizationScreen(
                    htmlCode: _finalHtml,
                    title: 'AI Visualization',
                  ),
                ),
              ).then((_) {
                // Reset the screen when returning
                if (context.mounted) {
                  setState(() {
                    _isLoading = false;
                    _isStreaming = false;
                    _streamingHtml = '';
                    _finalHtml = '';
                    _messageController.clear();
                  });
                }
              });
            }
          });
          break;
        } else {
          // Accumulate tokens based on type
          if (chunk.type == StreamingTokenType.content && chunk.token != null) {
            setState(() {
              _streamingHtml += chunk.token!;
            });
          } else if (chunk.type == StreamingTokenType.reasoning && chunk.token != null) {
            setState(() {
              _streamingReasoning += chunk.token!;
            });
          }
        }
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _isStreaming = false;
        _streamingHtml = '';
        _finalHtml = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating visualization: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visualization',
          style: AppTextStyles.headline2.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.go('/home'),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [


                // Main content area with scale animation
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppConstants.mediumAnimation,
                    switchInCurve: Curves.elasticOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                     child: _isStreaming
                         ? Container(
                             key: const ValueKey('streaming'),
                             child: _buildStreamingPreview(),
                           )
                         : _isLoading
                             ? Container(
                                 key: const ValueKey('loading'),
                                 child: Center(
                                   child: Column(
                                     mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Subtitle above input
              Text(
                'Describe your idea and watch it come to life',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
                                       AnimatedText(),
                                       const SizedBox(height: 16),
                                       Text(
                                         'Generating your visualization...',
                                         style: AppTextStyles.bodyMedium.copyWith(
                                           color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                               )
                             : _buildInputDisplay(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        return Column(
          children: [
            // Enhanced header with streaming indicator
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _PulsingCircle(size: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Creating your visualization',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Watch as the code comes to life...',
                          style: AppTextStyles.caption.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Reasoning content (if any)
            if (_streamingReasoning.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                constraints: const BoxConstraints(maxHeight: 150), // Fixed height
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'AI Reasoning',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _streamingReasoning,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Live HTML preview and code - only show after generation is complete
            if (!_isStreaming) ...[
              const SizedBox(height: 16),
              Expanded(
                child: isWideScreen
                    ? Row(
                        children: [
                          // Live preview
                          Expanded(
                            flex: 3,
                            child: _buildPreviewPanel(),
                          ),
                          const SizedBox(width: 16),
                          // Code view
                          Expanded(
                            flex: 2,
                            child: _buildCodePanel(),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // Live preview
                          Expanded(
                            flex: 2,
                            child: _buildPreviewPanel(),
                          ),
                          const SizedBox(height: 16),
                          // Code view
                          Expanded(
                            flex: 1,
                            child: _buildCodePanel(),
                          ),
                        ],
                      ),
              ),
            ],

            // Enhanced progress indicator
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_streamingHtml.length} characters',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Generating...',
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Preview header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Live Preview',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Preview content
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: WebViewWidget(
                controller: WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.unrestricted)
                  ..loadHtmlString(_getWrappedHtml(_streamingHtml)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodePanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Code header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Generated Code',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _streamingHtml.isEmpty
                    ? '// Your HTML code will appear here as it\'s generated...\n// Watch the magic happen! ✨'
                    : _streamingHtml,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getWrappedHtml(String htmlContent) {
    if (htmlContent.trim().isEmpty) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .loading {
      text-align: center;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
  </style>
</head>
<body>
  <div class="loading">
    <h2>🎨 Creating your visualization...</h2>
    <p>Watch as the magic happens!</p>
  </div>
</body>
</html>
''';
    }

    // If HTML doesn't have proper structure, wrap it
    String processedHtml = htmlContent;
    if (!processedHtml.trim().toLowerCase().startsWith('<!doctype html>') &&
        !processedHtml.trim().toLowerCase().startsWith('<html')) {
      processedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 20px; }
  </style>
</head>
<body>
  $processedHtml
</body>
</html>
''';
    }

    return processedHtml;
  }

  Widget _buildInputDisplay() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: AnimatedOpacity(
          opacity: _scaleAnimation.value,
          duration: AppConstants.mediumAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clean icon
              Icon(
                Icons.auto_awesome,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
              const SizedBox(height: 16),

              // Simple title
              Text(
                'Create Something Amazing',
                style: AppTextStyles.headline1.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Clean subtitle
              Text(
                'Describe your idea and watch it come to life',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Quick inspiration chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickChip('Game'),
                  _buildQuickChip('Chart'),
                  _buildQuickChip('Animation'),
                ],
              ),

              const SizedBox(height: 24),

              // Input field with spinning glow
              AnimatedBuilder(
                animation: _glowController,
                builder: (_, child) {
                  final isFocused = _focusNode.hasFocus;
                  final rotation = _glowController.value * 2 * math.pi;

                  return CustomPaint(
                    painter: _SpinningGlowPainter(
                      active: isFocused,
                      rotation: rotation,
                      primaryColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFocused
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          width: isFocused ? 2 : 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: 3,
                        minLines: 2,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., "Create an interactive solar system"',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Clean button
              SizedBox(
                width: 220,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Create',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Recent creations (minimal)
              if (_messages.isNotEmpty) ...[
                const SizedBox(height: 40),
                Text(
                  'Recent',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _messages.where((msg) => !msg.isFromUser).length,
                    itemBuilder: (context, index) {
                      final aiMessages = _messages.where((msg) => !msg.isFromUser).toList();
                      final message = aiMessages[index];
                      return _buildCompactCreationCard(message, index);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _messageController.text = 'Create $text';
        });
        _focusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInspirationChip(String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _messageController.text = 'Create $text';
        });
        _focusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getChipIcon(text),
              size: 16,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getChipIcon(String text) {
    switch (text) {
      case 'Interactive Game':
        return Icons.games;
      case 'Data Visualization':
        return Icons.bar_chart;
      case 'Animation Demo':
        return Icons.animation;
      case 'Calculator Tool':
        return Icons.calculate;
      case 'Particle System':
        return Icons.bubble_chart;
      case '3D Scene':
        return Icons.view_in_ar;
      default:
        return Icons.auto_awesome;
    }
  }

  Widget _buildCompactCreationCard(AiMessage message, int index) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VisualizationScreen(
                htmlCode: message.visualizationCode ?? message.content,
                title: 'Creation ${index + 1}',
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.web,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                'Creation ${index + 1}',
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCreationCard(AiMessage message, int index) {
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final delay = index * 150; // Stagger delay
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _scaleController,
            curve: Interval(
              delay / 1000.0,
              1.0,
              curve: Curves.elasticOut,
            ),
          ),
        );

        return Transform.scale(
          scale: animation.value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        child: InkWell(
          onTap: () {
            // Navigate to view this creation
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => VisualizationScreen(
                  htmlCode: message.content,
                  title: 'Recent Creation',
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Creation ${index + 1}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    _getCreationPreview(message.content),
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(message.timestamp),
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCreationPreview(String htmlContent) {
    // Extract a brief preview from the HTML content
    final cleanText = htmlContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (cleanText.length > 80) {
      return '${cleanText.substring(0, 80)}...';
    }
    return cleanText.isEmpty ? 'Interactive visualization' : cleanText;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _SpinningGlowPainter extends CustomPainter {
  final bool active;
  final double rotation;
  final Color primaryColor;

  _SpinningGlowPainter({
    required this.active,
    required this.rotation,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;

    final rect = Offset.zero & size;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(rotation),
      colors: [
        primaryColor.withOpacity(0.0),
        primaryColor.withOpacity(0.7),
        primaryColor.withOpacity(0.9),
        primaryColor.withOpacity(0.7),
        primaryColor.withOpacity(0.0),
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(16),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinningGlowPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.active != active ||
        oldDelegate.primaryColor != primaryColor;
  }
}