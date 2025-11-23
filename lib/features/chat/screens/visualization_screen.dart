import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Code Editor & Highlighting
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/xml.dart'; // Import XML/HTML language definition
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/repositories/conversation_service.dart';
import '../../../shared/repositories/profile_service.dart';
import '../../../core/services/zai_service.dart';
import '../../../shared/models/ai_message.dart';
import '../../../shared/repositories/ai_chat_service.dart';

enum ViewMode { preview, code }

// -----------------------------------------------------------------------------
// HELPER: GLASS CONTAINER
// -----------------------------------------------------------------------------
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;

  const _GlassContainer({
    required this.child,
    this.blur = 15,
    this.opacity = 0.08,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface.withOpacity(opacity),
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        border: border ??
            Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              width: 1,
            ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN SCREEN
// -----------------------------------------------------------------------------

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
  
  // State
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = true;
  late final String _processedHtml;
  ViewMode _viewMode = ViewMode.preview;
  
  // Controllers
  late CodeController _codeController;
  late TextEditingController _editPromptController;
  WebViewController? _webViewController;
  
  // Editing State
  bool _isEditingCode = false;
  String _reasoningText = '';
  late AnimationController _reasoningFadeController;
  late Animation<double> _reasoningFadeAnimation;
  String? _selectedText;

  @override
  void initState() {
    super.initState();

    // 1. Process HTML
    String fullHtml = widget.htmlCode;
    if (!fullHtml.trim().toLowerCase().startsWith('<!doctype html>') &&
        !fullHtml.trim().toLowerCase().startsWith('<html')) {
      fullHtml = _wrapHtml(widget.htmlCode);
    }
    _processedHtml = fullHtml;

    // 2. Initialize Code Controller with Syntax Highlighting
    _codeController = CodeController(
      text: widget.htmlCode,
      language: xml, // FIX 3: Apply HTML/XML syntax highlighting
    );
    _codeController.addListener(_onCodeChanged);
    _editPromptController = TextEditingController();

    // 3. Animations
    _reasoningFadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _reasoningFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _reasoningFadeController, curve: Curves.easeOut),
    );

    // 4. Webview Init
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadHtmlString(_processedHtml);
    }

    _loadConversations();
  }

  String _wrapHtml(String content) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body { margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; background-color: #ffffff; font-family: -apple-system, sans-serif; }
    * { box-sizing: border-box; }
    .animate-fade-in { animation: fadeIn 0.8s ease-in-out; }
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
  </style>
</head>
<body>
  <div class="animate-fade-in">$content</div>
</body>
</html>
    ''';
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await ConversationService.getUserConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoadingConversations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConversations = false);
      }
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 130), 
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _viewMode == ViewMode.preview 
                ? _buildPreview() 
                : _buildCodeEditor(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildGlassAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(130),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Row 1: Nav & Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          onPressed: _shareVisualization,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Row 2: Segmented Control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ViewMode>(
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Theme.of(context).colorScheme.primaryContainer;
                            }
                            return Colors.transparent;
                          }),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: ViewMode.preview,
                            label: Text('Preview'),
                            icon: Icon(Icons.visibility_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: ViewMode.code,
                            label: Text('Code'),
                            icon: Icon(Icons.code, size: 16),
                          ),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (newSelection) {
                          setState(() => _viewMode = newSelection.first);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW MODES
  // ---------------------------------------------------------------------------

  Widget _buildPreview() {
    if (_webViewController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.desktop_access_disabled_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Preview not supported on this platform',
              style: GoogleFonts.inter(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: WebViewWidget(controller: _webViewController!),
    );
  }

  Widget _buildCodeEditor() {
    final settings = Provider.of<AppSettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme mapping
    final themes = {
      'auto': isDark ? monokaiSublimeTheme : githubTheme,
      'github': githubTheme,
      'monokai': monokaiSublimeTheme,
      'vs': vsTheme,
      'atom-one-dark': atomOneDarkTheme,
    };
    final codeTheme = themes[settings.codeHighlightTheme] ?? (isDark ? atomOneDarkTheme : githubTheme);
    final bgColor = codeTheme['root']?.backgroundColor ?? (isDark ? const Color(0xFF1e1e1e) : Colors.white);

    return Stack(
      children: [
        // 1. Editor Area
        Column(
          children: [
            Expanded(
              child: Container(
                color: bgColor,
                child: CodeTheme(
                  data: CodeThemeData(styles: codeTheme),
                  child: SingleChildScrollView(
                    child: SelectionArea(
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedText = (selection != null && selection.plainText.isNotEmpty) 
                              ? selection.plainText 
                              : null;
                        });
                      },
                      child: CodeField(
                        controller: _codeController,
                        readOnly: true, // Edited via AI
                        textStyle: GoogleFonts.jetBrainsMono(fontSize: 12),
                        // FIX 2: Increased gutter width and alignment to prevent wrapping
                        gutterStyle: GutterStyle(
                          textStyle: GoogleFonts.jetBrainsMono(fontSize: 12, color: Colors.grey),
                          width: 60, // Wider gutter
                          margin: 4,
                          textAlign: TextAlign.right, // Align numbers to right
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Space for the bottom floating bar
            const SizedBox(height: 100),
          ],
        ),

        // 2. Reasoning Overlay (Glass)
        if (_reasoningText.isNotEmpty)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _reasoningFadeAnimation,
              builder: (context, child) {
                if (_reasoningFadeAnimation.value <= 0.01) return const SizedBox();
                
                return Opacity(
                  opacity: _reasoningFadeAnimation.value,
                  child: Center(
                    child: _GlassContainer(
                      color: Colors.black.withOpacity(0.6),
                      blur: 10,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "AI Architect is analyzing...",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _reasoningText,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 3. Floating Input Bar
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildFloatingInputBar(),
        ),
      ],
    );
  }

  Widget _buildFloatingInputBar() {
    final hasSelection = _selectedText != null;

    return _GlassContainer(
      opacity: 0.9,
      blur: 20,
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      border: Border.all(
        color: hasSelection ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        width: hasSelection ? 1.5 : 1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSelection)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_quote_rounded, size: 12, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Editing selection',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedText = null),
                    child: Icon(Icons.close, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _editPromptController,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hasSelection 
                        ? 'How should Mite change this selection?' 
                        : 'Ask Mite to edit the code...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14, 
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _performAgentEdit(),
                ),
              ),
              const SizedBox(width: 8),
              
              // FIX 1: Fixed container size to prevent shrinking during loading state
              SizedBox(
                width: 40,
                height: 40,
                child: _isEditingCode
                  ? Center(
                      child: SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                      ),
                    )
                  : IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        fixedSize: const Size(36, 36),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      onPressed: _performAgentEdit,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIC & ACTIONS
  // ---------------------------------------------------------------------------

  void _shareVisualization() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _GlassContainer(
          opacity: 0.95,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                'Share to Conversation',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isLoadingConversations)
                const Center(child: CircularProgressIndicator())
              else if (_conversations.isEmpty)
                Text('No conversations available', style: GoogleFonts.inter(color: Colors.grey))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            (conversation.name ?? 'U')[0].toUpperCase(),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(conversation.name ?? 'Untitled', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        subtitle: Text('${conversation.participantIds.length} participants', style: GoogleFonts.inter(fontSize: 12)),
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
      final formattedMessage = '[HLT_VISUALIZATION]${_codeController.text}[/HLT_VISUALIZATION]';
      final messageData = {
        'conversation_id': conversation.id,
        'content': formattedMessage,
        'sender_id': Supabase.instance.client.auth.currentUser?.id,
        'message_type': 'text',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('messages').insert(messageData);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shared to ${conversation.name ?? 'conversation'}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  void _onCodeChanged() {
    if (_webViewController != null) {
      _webViewController!.loadHtmlString(_codeController.text);
    }
  }

  // --- FIX 4: AGENT MODE (Smart Patching) ---
  
  Future<void> _performAgentEdit() async {
    final prompt = _editPromptController.text.trim();
    if (prompt.isEmpty || _isEditingCode) return;

    setState(() {
      _isEditingCode = true;
      _reasoningText = '';
      _reasoningFadeController.value = 1.0;
    });

    try {
      final userProfile = await ProfileService.getCurrentUserProfile();
      final userInfo = userProfile != null
          ? {'display_name': userProfile.displayName}
          : {'platform': Platform.operatingSystem};

      String fullPrompt;
      bool isPartialEdit = _selectedText != null;

      if (isPartialEdit) {
        // Simple direct replacement for selected text
        fullPrompt = '''
You are a coding assistant. 
Request: $prompt
Target Code Selection:
${_selectedText}

Output ONLY the new code to replace the selection with. No markdown, no explanations.
''';
      } else {
        // Agent Logic: Search and Replace for whole file
        fullPrompt = '''
You are a smart code patching agent. 
The user wants to edit this HTML file.
Request: $prompt

Current Code:
${_codeController.text}

INSTRUCTIONS:
Do NOT rewrite the whole file. 
Return a JSON ARRAY of edits. Format:
[
  {
    "search": "exact string to find in the original code",
    "replace": "new string to replace it with"
  }
]
- The "search" string must match the existing code EXACTLY (including whitespace) to work.
- Make the "search" block large enough to be unique, but small enough to match reliably.
- Return ONLY the JSON array.
''';
      }

      final stream = await ZaiService.streamMessage(
        message: fullPrompt,
        conversationHistory: [],
        userInfo: userInfo,
      );

      String responseBuffer = '';
      bool hasStartedContent = false;

      await for (final chunk in stream) {
        if (chunk.done) break;
        
        if (chunk.type == StreamingTokenType.reasoning && chunk.token != null) {
          setState(() => _reasoningText += chunk.token!);
        } else if (chunk.type == StreamingTokenType.content && chunk.token != null) {
          if (!hasStartedContent) {
            hasStartedContent = true;
            _reasoningFadeController.forward();
          }
          responseBuffer += chunk.token!;
        }
      }

      // Apply Edits
      if (isPartialEdit) {
        _applyPartialEdit(responseBuffer.trim());
      } else {
        _applyAgentPatches(responseBuffer);
      }

      _editPromptController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code updated!')));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isEditingCode = false);
    }
  }

  void _applyPartialEdit(String newCode) {
    if (_selectedText == null) return;
    
    // Clean up potential markdown from AI (e.g., ```html ... ```)
    String cleanCode = newCode.replaceAll(RegExp(r'^```\w*\n|```$'), '');

    final currentCode = _codeController.text;
    final start = currentCode.indexOf(_selectedText!);
    if (start != -1) {
      final end = start + _selectedText!.length;
      final updatedFullCode = currentCode.substring(0, start) + cleanCode + currentCode.substring(end);
      _codeController.text = updatedFullCode;
      _selectedText = null; 
    }
  }

  void _applyAgentPatches(String jsonResponse) {
    try {
      // 1. Clean response to find JSON array
      final jsonStart = jsonResponse.indexOf('[');
      final jsonEnd = jsonResponse.lastIndexOf(']');
      
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception("Could not parse AI response as JSON patches.");
      }

      final jsonString = jsonResponse.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> patches = jsonDecode(jsonString);

      String currentCode = _codeController.text;
      int successCount = 0;

      // 2. Apply patches sequentially
      for (var patch in patches) {
        final search = patch['search'] as String;
        final replace = patch['replace'] as String;

        if (currentCode.contains(search)) {
          currentCode = currentCode.replaceFirst(search, replace);
          successCount++;
        } else {
          // Fallback: Try a whitespace-insensitive match if exact match fails
          // (Simplified logic here: just logging failure)
          debugPrint("Agent Edit: Could not find code block: $search");
        }
      }

      if (successCount > 0) {
        _codeController.text = currentCode;
      } else {
        throw Exception("AI generated patches but none matched the current code.");
      }

    } catch (e) {
      debugPrint("Agent Patching Failed: $e");
      // Fallback: Ask AI to rewrite the whole file if patching fails (Optional)
    }
  }
}
