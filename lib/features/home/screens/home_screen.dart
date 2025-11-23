import 'dart:async';
import 'dart:io';
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../core/providers/audio_only_call_provider.dart';
import '../../../shared/repositories/conversation_service.dart';
import '../../../shared/repositories/ai_chat_service.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/ai_conversation.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/models/user.dart' as app_user;
import '../../../shared/widgets/ai_speed_dial.dart';
import '../../settings/screens/settings_screen.dart';
import '../../chat/widgets/conversation_tile.dart';
import '../../chat/widgets/new_conversation_dialog.dart';

// -----------------------------------------------------------------------------
// HELPER: GLASS CONTAINER (Kept only for Nav Bar / specific highlights)
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
  final VoidCallback? onTap;

  const _GlassContainer({
    required this.child,
    this.blur = 12,
    this.opacity = 0.08,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.border,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface.withOpacity(opacity),
        borderRadius: borderRadius ?? BorderRadius.circular(0), // Default to 0 for edge-to-edge
        border: border,
      ),
      child: child,
    );

    final content = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: container,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// -----------------------------------------------------------------------------
// MAIN SCREEN
// -----------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
  int _selectedIndex = 0;
  final bool _isExtended = false;
  List<Conversation> _conversations = [];
  List<AiConversation> _aiConversations = [];

  bool _isLoading = true;
  
  // Animation for page transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final RouteObserver<ModalRoute<void>> _routeObserver = RouteObserver<ModalRoute<void>>();
   StreamSubscription? _conversationsSubscription;
   StreamSubscription? _conversationsTableSubscription;
   StreamSubscription? _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    ));

    _fadeController.forward();
    _loadConversations();
    _startConversationsSubscription();
    _startConversationsTableSubscription();

    // Delay incoming call subscription to ensure CallProvider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startIncomingCallSubscription();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context) != null) {
      _routeObserver.subscribe(this, ModalRoute.of(context)!);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    _conversationsSubscription?.cancel();
    _conversationsTableSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadConversations();
  }

  void _startConversationsSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _conversationsSubscription = Supabase.instance.client
        .from('participants')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('user_id', userId)
        .listen((data) {
          if (mounted) _loadConversations();
        }, onError: (error) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _startConversationsSubscription();
          });
        });
  }

  void _startConversationsTableSubscription() {
    _conversationsTableSubscription = Supabase.instance.client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
          if (mounted) {
            _loadConversations();
          }
        });
  }

  void _startIncomingCallSubscription() {
    debugPrint('🏠 HomeScreen: Setting up incoming call subscription');
    try {
      final callProvider = context.read<AudioOnlyCallProvider>();
      debugPrint('🏠 HomeScreen: Got AudioOnlyCallProvider: $callProvider');

      _incomingCallSubscription = callProvider.incomingCallStream.listen((callData) {
        debugPrint('🏠 HomeScreen: 📞 INCOMING CALL STREAM EMITTED: $callData');
        if (mounted && callData.isNotEmpty) {
          debugPrint('🏠 HomeScreen: Navigating to incoming call screen');
          // Navigate to incoming call screen
          context.go('/incoming-call?callId=${callData['callId']}&callerId=${callData['callerId']}');
        } else {
          debugPrint('🏠 HomeScreen: Not navigating - mounted: $mounted, callData empty: ${callData.isEmpty}');
        }
      });

      debugPrint('🏠 HomeScreen: Incoming call subscription set up successfully');
    } catch (e) {
      debugPrint('🏠 HomeScreen: Error setting up incoming call subscription: $e');
    }
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        _conversations = await ConversationService.getUserConversations();
        _aiConversations = await AiChatService.getConversations();
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMitePromptDialog(Conversation conversation, List<app_user.User> participants) {
    final TextEditingController promptController = TextEditingController();
    final TextEditingController messageLimitController = TextEditingController(text: '20');
    List<File> attachedImages = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: Text('Mite AI Options', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: promptController,
                      decoration: InputDecoration(
                        labelText: 'Prompt for Mite AI',
                        hintText: 'Enter your prompt...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageLimitController,
                      decoration: InputDecoration(
                        labelText: 'Message Limit',
                        hintText: 'e.g., 20',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    if (attachedImages.isNotEmpty) ...[
                      Text(
                        'Attached Images:',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: attachedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              height: 80,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(attachedImages[index], fit: BoxFit.cover, width: 80, height: 80),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => attachedImages.removeAt(index)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final result = await FilePickerService.pickImage();
                          if (result != null && result.files.isNotEmpty) {
                            final file = File(result.files.first.path!);
                            if (FilePickerService.isValidFileSize(file)) {
                              setState(() => attachedImages.add(file));
                            }
                          }
                        } catch (e) {
                          debugPrint('Error picking image: $e');
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Attach Image'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Send to Mite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SCAFFOLD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      // Clean background color (removed blobs)
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBody: true, // Allows content to scroll behind the translucent navbar

      // Desktop Navigation
      body: Row(
        children: [
          if (!isMobile) _buildDesktopNavRail(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSelectedScreen(),
            ),
          ),
        ],
      ),

      // Mobile Navigation (Slim, Edge-to-Edge)
      bottomNavigationBar: isMobile
          ? _SlimGlassBottomNavBar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) => setState(() => _selectedIndex = index),
            )
          : null,

      // Mobile FABs positioned above bottom nav
      floatingActionButton: isMobile ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 0: // Chats
        return FloatingActionButton(
          onPressed: _showNewConversationDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 2,
          child: const Icon(Icons.add_comment_rounded),
        );
      case 1: // AI
        return AiSpeedDial(
          onNewChatPressed: () async {
            final newConversation = AiConversation(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: 'New Chat',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              messages: const [],
            );
            await AiChatService.saveConversation(newConversation);
            if (!context.mounted) return;
            context.go('/chat?aiConversationId=${newConversation.id}');
          },
          onVisualizationPressed: () => context.go('/html-visualization'),
        );
      default:
        return null;
    }
  }

  Widget _buildDesktopNavRail() {
    return NavigationRail(
      extended: _isExtended,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: Text('Chats'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome_rounded),
          label: Text('AI'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: Text('People'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profile'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: Text('Settings'),
        ),
      ],
    );
  }

  Widget _buildSelectedScreen() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bottomPadding = isMobile ? MediaQuery.of(context).padding.bottom + 80.0 : 0.0;

    switch (_selectedIndex) {
      case 0: return _buildChatsScreen(bottomPadding);
      case 1: return _buildAiScreen(bottomPadding);
      case 2: return _buildPeopleScreen(bottomPadding);
      case 3: return ProfileScreen(bottomPadding: bottomPadding);
      case 4: return SettingsScreen(bottomPadding: bottomPadding);
      default: return _buildChatsScreen(bottomPadding);
    }
  }

  // ---------------------------------------------------------------------------
  // SCREEN CONTENT BUILDERS (Edge-to-Edge)
  // ---------------------------------------------------------------------------

  // --- Chats Screen ---
  Widget _buildChatsScreen(double bottomPadding) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildGlassAppBar('Messages', [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {},
        ),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState(Icons.chat_bubble_outline_rounded, 'No conversations yet', 'Start chatting to see messages here.')
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    // Remove horizontal padding for edge-to-edge
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 80, // Indent to align with text start, skipping avatar
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return FutureBuilder<List<app_user.User>>(
                        future: ConversationService.getConversationParticipants(conversation.id),
                        builder: (context, snapshot) {
                          final participants = snapshot.data ?? [];
                          // No wrappers here, just the tile directly
                          return ConversationTile(
                            conversation: conversation,
                            participants: participants,
                            onTap: () => context.go('/chat?conversationId=${conversation.id}'),
                            onLongPress: () => _showConversationActions(conversation, participants),
                            onLongPressForMite: () => _showMitePromptDialog(conversation, participants),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  // --- AI Screen ---
  Widget _buildAiScreen(double bottomPadding) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildGlassAppBar('AI Assistant', [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {},
        ),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _aiConversations.isEmpty
              ? _buildEmptyState(Icons.auto_awesome_outlined, 'No AI chats yet', 'Start a conversation with our AI.')
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    itemCount: _aiConversations.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 80,
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                    itemBuilder: (context, index) {
                      return _buildAiConversationTile(_aiConversations[index]);
                    },
                  ),
                ),
    );
  }

  // --- People Screen ---
  Widget _buildPeopleScreen(double bottomPadding) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildGlassAppBar('People', [
        IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
      ]),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: _buildEmptyState(Icons.people_outline_rounded, 'No people found', 'Connect with friends to see them here.'),
      ),
    );
  }

  // --- Helper Widgets ---

  PreferredSizeWidget _buildGlassAppBar(String title, List<Widget>? actions) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 22, // Slightly smaller for cleanliness
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      centerTitle: false,
      actions: actions,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2), height: 1),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // Edge-to-Edge AI Tile
  Widget _buildAiConversationTile(AiConversation aiConversation) {
    final lastMessage = aiConversation.messages.isNotEmpty
        ? aiConversation.messages.last
        : null;

    return ListTile(
      onTap: () => context.go('/chat?aiConversationId=${aiConversation.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
      ),
      title: Text(
        aiConversation.title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        lastMessage?.content ?? 'Start chatting with AI',
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: lastMessage != null
          ? Text(
              _formatTime(lastMessage.timestamp),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            )
          : null,
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  void _showConversationActions(Conversation conversation, List<app_user.User> participants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actions'),
        content: const Text('Conversation options would go here.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showNewConversationDialog() {
    showDialog(context: context, builder: (context) => const NewConversationDialog());
  }
}

// -----------------------------------------------------------------------------
// SLIM GLASS NAV BAR
// -----------------------------------------------------------------------------

class _SlimGlassBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _SlimGlassBottomNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 80, // Slim standard height (incl bottom padding)
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SlimNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                isSelected: selectedIndex == 0,
                onTap: () => onItemSelected(0),
              ),
              _SlimNavItem(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome_rounded,
                label: 'AI',
                isSelected: selectedIndex == 1,
                onTap: () => onItemSelected(1),
              ),
              _SlimNavItem(
                icon: Icons.people_outline_rounded,
                selectedIcon: Icons.people_rounded,
                label: 'People',
                isSelected: selectedIndex == 2,
                onTap: () => onItemSelected(2),
              ),
              _SlimNavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: selectedIndex == 3,
                onTap: () => onItemSelected(3),
              ),
              _SlimNavItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: selectedIndex == 4,
                onTap: () => onItemSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlimNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlimNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
