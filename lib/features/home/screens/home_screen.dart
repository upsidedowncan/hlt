import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Kept if you use it elsewhere
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
// import '../../../core/providers/user_provider.dart'; // Uncomment if needed
import '../../../shared/repositories/conversation_service.dart';
// import '../../../shared/repositories/message_service.dart'; // Uncomment if needed
import '../../../shared/repositories/ai_chat_service.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/ai_conversation.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../shared/models/user.dart' as app_user;
import '../../../shared/widgets/ai_speed_dial.dart';

// import '../../profile/widgets/profile_avatar.dart'; // Uncomment if needed
import '../../chat/widgets/conversation_tile.dart';
import '../../chat/widgets/new_conversation_dialog.dart';

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
  final String _aiSearchQuery = ''; // Made final to silence warning, remove final if you implement search

  // Note: This getter was unused in the original code, kept for reference
  List<AiConversation> get _filteredAiConversations {
    if (_aiSearchQuery.isEmpty) return _aiConversations;
    return _aiConversations.where((conv) =>
      conv.title.toLowerCase().contains(_aiSearchQuery.toLowerCase()) ||
      (conv.messages.isNotEmpty && conv.messages.last.content.toLowerCase().contains(_aiSearchQuery.toLowerCase()))
    ).toList();
  }

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final RouteObserver<ModalRoute<void>> _routeObserver = RouteObserver<ModalRoute<void>>();
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _conversationsTableSubscription;

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
      curve: Curves.easeIn,
    ));

    _fadeController.forward();
    _loadConversations();
    _startConversationsSubscription();
    _startConversationsTableSubscription();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    _conversationsSubscription?.cancel();
    _conversationsTableSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the user returns to this screen
    _loadConversations();
  }

  void _startConversationsSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('Starting conversations real-time subscription for user: $userId');

    _conversationsSubscription = Supabase.instance.client
        .from('participants')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('user_id', userId)
        .listen((data) {
          debugPrint('Participants changed (${data.length} records), reloading conversations');
          if (mounted) {
            _loadConversations();
          }
        }, onError: (error) {
          debugPrint('Conversations subscription error: $error');
          // Try to restart subscription on error
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              debugPrint('Restarting conversations subscription after error');
              _startConversationsSubscription();
            }
          });
        }, onDone: () {
          debugPrint('Conversations subscription ended');
        });
  }

  void _startConversationsTableSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('Starting conversations table real-time subscription');

    _conversationsTableSubscription = Supabase.instance.client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .listen((data) {
          debugPrint('Conversations table changed (${data.length} records), reloading conversations');
          if (mounted) {
            _loadConversations();
          }
        }, onError: (error) {
          debugPrint('Conversations table subscription error: $error');
        }, onDone: () {
          debugPrint('Conversations table subscription ended');
        });
  }

  void _showMitePromptDialog(Conversation conversation, List<app_user.User> participants) {
    // Initialize controllers and state variables for the dialog
    final TextEditingController promptController = TextEditingController();
    final TextEditingController messageLimitController = TextEditingController(text: '20');
    List<File> attachedImages = [];

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder so we can setState inside the dialog (e.g. updating attached images)
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Mite AI Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: promptController,
                      decoration: const InputDecoration(
                        labelText: 'Prompt for Mite AI',
                        hintText: 'Enter your prompt...',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageLimitController,
                      decoration: const InputDecoration(
                        labelText: 'Message Limit',
                        hintText: 'e.g., 20',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    if (attachedImages.isNotEmpty) ...[
                      Text(
                        'Attached Images:',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
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
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(attachedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          attachedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
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
                              setState(() {
                                attachedImages.add(file);
                              });
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('File size too large. Maximum 10MB allowed.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('Error picking image: $e');
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Attach Image'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement sending to Mite AI
                    // Use promptController.text, messageLimitController.text, attachedImages
                    Navigator.of(context).pop();
                  },
                  child: const Text('Send to Mite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Scaffold(
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildSelectedScreen(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
          shadowColor: Theme.of(context).shadowColor,
          elevation: 4,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.chat_outlined,
                color: _selectedIndex == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.chat,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Chats',
              tooltip: 'View your chat conversations',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.smart_toy_outlined,
                color: _selectedIndex == 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.smart_toy,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'AI',
              tooltip: 'Chat with AI assistants',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.people_outline,
                color: _selectedIndex == 2
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.people,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'People',
              tooltip: 'Connect with people',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: _selectedIndex == 3
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Profile',
              tooltip: 'View your profile',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.settings_outlined,
                color: _selectedIndex == 4
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Settings',
              tooltip: 'App settings and preferences',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: NavigationRail(
              extended: _isExtended,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              backgroundColor: Colors.transparent,
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.primary,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedLabelTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              minWidth: 72,
              groupAlignment: -1.0,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_outlined),
                  selectedIcon: Icon(Icons.chat),
                  label: Text('Chats'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy),
                  label: Text('AI'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('People'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSelectedScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatsScreen();
      case 1:
        return _buildAiScreen();
      case 2:
        return _buildPeopleScreen();
      case 3:
        return const ProfileScreen();
      case 4:
        return const SettingsScreen();
      default:
        return _buildChatsScreen();
    }
  }

  Widget _buildChatsScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats',
          style: AppTextStyles.headline2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: AppColors.messageBubble,
                      ),
                      AppSpacing.verticalLarge,
                      Text(
                        'No conversations yet',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      AppSpacing.verticalSmall,
                      Text(
                        'Start a conversation to see it here',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshConversations,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return FutureBuilder<List<app_user.User>>(
                        future: ConversationService.getConversationParticipants(conversation.id),
                        builder: (context, snapshot) {
                          final participants = snapshot.data ?? [];
                          return ConversationTile(
                            conversation: conversation,
                            participants: participants,
                            onTap: () {
                              context.go('/chat?conversationId=${conversation.id}');
                            },
                            onLongPress: () => _showConversationActions(conversation, participants),
                            onLongPressForMite: () => _showMitePromptDialog(conversation, participants),
                          );
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAiScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Conversations',
          style: AppTextStyles.headline2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _aiConversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 80,
                        color: AppColors.messageBubble,
                      ),
                      AppSpacing.verticalLarge,
                      Text(
                        'No AI conversations yet',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      AppSpacing.verticalSmall,
                      Text(
                        'Start chatting with AI to see conversations here',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshConversations,
                  child: ListView.builder(
                    itemCount: _aiConversations.length,
                    itemBuilder: (context, index) {
                      final aiConversation = _aiConversations[index];
                      return _buildAiConversationTile(aiConversation);
                    },
                  ),
                ),
      floatingActionButton: AiSpeedDial(
        onNewChatPressed: () async {
          // Create a new AI conversation
          final newConversation = AiConversation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'New Chat ${DateTime.now().toString().substring(0, 16)}',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            messages: const [],
          );

          await AiChatService.saveConversation(newConversation);

          if (!context.mounted) return;

          context.go('/chat?aiConversationId=${newConversation.id}');
        },
        onVisualizationPressed: () => context.go('/html-visualization'),
      ),
    );
  }

  Widget _buildPeopleScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'People',
          style: AppTextStyles.headline2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // TODO: Implement add people
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.messageBubble,
            ),
            AppSpacing.verticalLarge,
            Text(
              'No people found',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            AppSpacing.verticalSmall,
            Text(
              'Connect with people to start chatting',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiConversationTile(AiConversation aiConversation) {
    final lastMessage = aiConversation.messages.isNotEmpty
        ? aiConversation.messages.last
        : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(
          Icons.smart_toy,
          color: Colors.white,
        ),
      ),
      title: Text(
        aiConversation.title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: lastMessage != null
          ? Text(
              lastMessage.content.length > 50
                  ? '${lastMessage.content.substring(0, 50)}...'
                  : lastMessage.content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              'Start chatting with AI',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
      trailing: lastMessage != null
          ? Text(
              _formatTime(lastMessage.timestamp),
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            )
          : null,
      onTap: () {
        // Navigate to AI chat
        context.go('/chat?aiConversationId=${aiConversation.id}');
      },
    );
  }

  String _formatTime(DateTime timestamp) {
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
      return '${timestamp.day}/${timestamp.month}';
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

  // Unused helper methods preserved from original
  // String? _getConversationAvatar(Conversation conversation, List<app_user.User> participants) {
  //   if (participants.isNotEmpty) {
  //     return participants.first.avatarUrl;
  //   }
  //   return null;
  // }

  // String _getConversationName(Conversation conversation, List<app_user.User> participants) {
  //   if (conversation.name != null && conversation.name!.isNotEmpty) {
  //     return conversation.name!;
  //   }
  //   if (participants.isNotEmpty) {
  //     return participants.map((p) => p.displayName).join(', ');
  //   }
  //   return 'Unknown Conversation';
  // }

  void _onDestinationSelected(int index) {
    if (_selectedIndex != index) {
      // Add a subtle animation when switching screens
      _fadeController.reset();
      setState(() => _selectedIndex = index);
      _fadeController.forward();
    }
  }

  Future<void> _refreshConversations() async {
    await _loadConversations();
  }

  void _showConversationActions(Conversation conversation, List<app_user.User> participants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conversation Actions'),
        content: const Text('What would you like to do with this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }
}
