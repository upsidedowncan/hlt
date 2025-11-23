import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/audio_only_call_provider.dart';
import '../../profile/widgets/profile_avatar.dart';
import '../../../shared/models/user.dart' as app_user;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/repositories/profile_service.dart';
import '../../../shared/repositories/message_service.dart';
import '../../../shared/repositories/conversation_service.dart';
import '../../../shared/models/message.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  app_user.User? _caller;
  late AnimationController _ringAnimationController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('📞 IncomingCallScreen: Created with callId=${widget.callId}, callerId=${widget.callerId}');
    _loadCallerInfo();
    _setupRingAnimation();
  }

  @override
  void dispose() {
    _ringAnimationController.dispose();
    super.dispose();
  }

  Future<void> _saveDeclinedCallEvent() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Find the conversation between caller and receiver
      final conversation = await ConversationService.findOrCreateConversation(
        widget.callerId,
        'Chat',
      );

      if (conversation != null) {
        await MessageService.sendCallEventMessage(
          conversationId: conversation.id,
          callId: widget.callId,
          callerId: widget.callerId,
          receiverId: currentUserId,
          eventType: CallEventType.declined,
          duration: 0,
        );
      }
    } catch (e) {
      debugPrint('Error saving declined call event: $e');
    }
  }

  String _getCurrentUserId() {
    return context.read<AudioOnlyCallProvider>().currentCall?.receiverId ?? '';
  }

  Future<void> _loadCallerInfo() async {
    try {
      _caller = await ProfileService.getUserProfile(widget.callerId);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading caller info: $e');
      // Fallback to basic user info
      _caller = app_user.User(
        id: widget.callerId,
        email: 'caller@example.com',
        displayName: 'Caller',
        username: 'caller',
      );
    }
  }

  void _setupRingAnimation() {
    _ringAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _ringAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated avatar
              AnimatedBuilder(
                animation: _ringAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _ringAnimation.value,
                    child: ProfileAvatar(
                      avatarUrl: _caller?.avatarUrl,
                      displayName: _caller?.displayName ?? 'Unknown',
                      size: 120,
                      showBorder: true,
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Caller name
              Text(
                _caller?.displayName ?? 'Unknown Caller',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Call type
              Text(
                'Audio Call',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 8),

              // Incoming call text
              Text(
                'Incoming call...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 64),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline button
                  _ActionButton(
                    icon: Icons.call_end,
                    label: 'Decline',
                    color: Colors.red,
                    onPressed: () async {
                      // Save declined call event
                      await _saveDeclinedCallEvent();
                      context.read<AudioOnlyCallProvider>().endCall();
                      if (mounted) {
                        context.go('/home');
                      }
                    },
                  ),

                  // Accept button
                  _ActionButton(
                    icon: Icons.call,
                    label: 'Accept',
                    color: Colors.green,
                    onPressed: () async {
                      await context.read<AudioOnlyCallProvider>().answerCall(widget.callId);
                      if (mounted) {
                        context.go('/call?callId=${widget.callId}');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 32),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}