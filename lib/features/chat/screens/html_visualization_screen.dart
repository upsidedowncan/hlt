import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// -----------------------------------------------------------------------------
// UI HELPER COMPONENTS
// -----------------------------------------------------------------------------

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Border? border;

  const _GlassContainer({
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: border ??
                Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  width: 1,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: colorScheme.surface),
            // Top Right Blob
            Positioned(
              top: -100 + (_controller.value * 50),
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Left Blob
            Positioned(
              bottom: -50 - (_controller.value * 30),
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.tertiary.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class AnimatedText extends StatefulWidget {
  const AnimatedText({super.key});

  @override
  State<AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText> {
  final List<String> _texts = [
    'Weaving code...',
    'Designing interface...',
    'Compiling assets...',
    'Polishing pixels...',
    'Almost ready...',
  ];

  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
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
    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
              child: child,
            ),
          );
        },
        child: Text(
          _texts[_currentIndex],
          key: ValueKey<String>(_texts[_currentIndex]),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: _GlassContainer(
        opacity: 0.5,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN SCREEN
// -----------------------------------------------------------------------------

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

  // Animation Controllers
  late AnimationController _fadeController;
  
  // Controller for the continuous rotation of the glow
  late AnimationController _glowRotationController; 
  
  // Controller for the smooth fade in/out of the focus border
  late AnimationController _focusFadeController;    

  @override
  void initState() {
    super.initState();

    // 1. Main entry fade
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // 2. Continuous rotation
    _glowRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // 3. Smooth opacity transition for glow
    _focusFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Smooth 0.5s transition
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Start rotating and fade in the border
        _glowRotationController.repeat();
        _focusFadeController.forward();
      } else {
        // Fade out the border slowly
        _focusFadeController.reverse();
        // We don't stop rotation immediately so the fade out looks smooth while still spinning
      }
      setState(() {});
    });

    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _glowRotationController.dispose();
    _focusFadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    _conversationId = 'html_visualizations';
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
    if (mounted) {
      setState(() {
        _messages = conversation!.messages;
      });
    }
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

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _isStreaming = true;
      _streamingHtml = '';
      _streamingReasoning = '';
      _finalHtml = '';
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userInfo = {
        'display_name': userProvider.currentUser?.displayName ?? 'User',
      };

      final customSystemPrompt = '''
You are an HTML/JS Creative Expert. Your task is to generate ONLY valid HTML code.

IMPORTANT RULES:
- Return ONLY HTML code. No markdown ticks, no explanations before/after.
- Start with <!DOCTYPE html>.
- Include all CSS and JS inside the HTML file.
- Use Tailwind CSS via CDN for styling: <script src="https://cdn.tailwindcss.com"></script>
- Make content responsive, mobile-friendly, and professionally designed.
- Use beautiful colors, smooth animations, and modern UI principles.
''';

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

          final userMessage = AiMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: message,
            isFromUser: true,
            timestamp: DateTime.now(),
          );

          final aiMessage = AiMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: 'Visualization generated',
            isFromUser: false,
            timestamp: DateTime.now(),
            reasoning_content: _streamingReasoning.isNotEmpty ? _streamingReasoning : null,
            visualizationCode: _finalHtml,
          );

          _messages.add(userMessage);
          _messages.add(aiMessage);
          await _saveToPersistentStorage();

          if (mounted) {
            // Small delay to show completion before navigating
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) {
               Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => VisualizationScreen(
                    htmlCode: _finalHtml,
                    title: 'Generated Result',
                  ),
                ),
              ).then((_) {
                if (mounted) {
                  setState(() {
                    // Reset state when returning
                    _isLoading = false;
                    _isStreaming = false;
                    _streamingHtml = '';
                    _finalHtml = '';
                    _messageController.clear();
                  });
                }
              });
            }
          }
          break;
        } else {
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _setText(String text) {
    setState(() {
      _messageController.text = text;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          'Design Studio',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Stack(
        children: [
          // 1. Animated Ambient Background
          const _AmbientBackground(),

          // 2. Main Content Area
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isStreaming
                  ? _buildStreamingView()
                  : _isLoading
                      ? _buildLoadingView()
                      : _buildInputView(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW: INPUT / DASHBOARD
  // ---------------------------------------------------------------------------
  Widget _buildInputView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Hero
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'What shall we create?',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Describe a game, a chart, or a simulation.\nOur AI architect will build it instantly.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Input Field with Smooth Glow
              AnimatedBuilder(
                animation: Listenable.merge([_glowRotationController, _focusFadeController]),
                builder: (_, child) {
                  return CustomPaint(
                    painter: _SpinningGlowPainter(
                      opacity: _focusFadeController.value,
                      rotation: _glowRotationController.value * 2 * math.pi,
                      primaryColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: _GlassContainer(
                      opacity: 0.6,
                      borderRadius: BorderRadius.circular(32), // Slightly more rounded
                      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4), // Adjusted padding
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // Centered alignment
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              maxLines: 4,
                              minLines: 1,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ex: "Solar system"',
                                hintStyle: GoogleFonts.inter(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Button is now directly in the Row, vertically centered
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              fixedSize: const Size(44, 44), // Consistent circular size
                            ),
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.arrow_upward_rounded, size: 24),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Suggestions
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(
                    label: 'Interactive Chart',
                    icon: Icons.pie_chart_rounded,
                    onTap: () => _setText('Create an interactive pie chart for budget allocation'),
                  ),
                  _SuggestionChip(
                    label: 'Physics Game',
                    icon: Icons.sports_esports_rounded,
                    onTap: () => _setText('Create a simple physics game with bouncing balls'),
                  ),
                  _SuggestionChip(
                    label: 'Calculator',
                    icon: Icons.calculate_rounded,
                    onTap: () => _setText('Design a modern neumorphic calculator'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW: LOADING
  // ---------------------------------------------------------------------------
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Rotating outer ring
              RotationTransition(
                turns: _glowRotationController,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0),
                        Theme.of(context).colorScheme.primary,
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Inner circle background
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const AnimatedText(),
          const SizedBox(height: 8),
          Text(
            'This might take a moment',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW: STREAMING / CODE PREVIEW
  // ---------------------------------------------------------------------------
  Widget _buildStreamingView() {
    return Column(
      children: [
        // Status Header
        Container(
          margin: const EdgeInsets.all(16),
          child: _GlassContainer(
            opacity: 0.7,
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generating Logic',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_streamingHtml.length} bytes written',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Mock Browser/IDE Content Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Dark Header
                  Container(
                    height: 40,
                    color: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            _macDot(Colors.red[400]!),
                            const SizedBox(width: 6),
                            _macDot(Colors.amber[400]!),
                            const SizedBox(width: 6),
                            _macDot(Colors.green[400]!),
                          ],
                        ),
                        const Expanded(child: SizedBox()),
                        Text(
                          'index.html',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                  // Code View
                  Expanded(
                    child: Container(
                      color: const Color(0xFF252526),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          _streamingHtml,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: const Color(0xFFD4D4D4),
                            height: 1.5,
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
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _macDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PAINTER
// -----------------------------------------------------------------------------

class _SpinningGlowPainter extends CustomPainter {
  final double opacity; // Controls the fade in/out of the glow
  final double rotation;
  final Color primaryColor;

  _SpinningGlowPainter({
    required this.opacity,
    required this.rotation,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Optimization: If completely invisible, don't draw
    if (opacity == 0.0) return;

    final rect = Offset.zero & size;

    // 1. Subtle Outer Glow (Fades with opacity)
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.3 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      paint,
    );

    // 2. Rotating Gradient Border
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(rotation),
      colors: [
        primaryColor.withOpacity(0.0),
        primaryColor.withOpacity(1.0 * opacity), // Peak opacity controlled by animation
        primaryColor.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final borderPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinningGlowPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.opacity != opacity ||
        oldDelegate.primaryColor != primaryColor;
  }
}
