import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/providers/audio_only_call_provider.dart';
import '../../../core/services/audio_only_webrtc_service.dart';
import '../../../core/utils/audio_helper.dart';
import '../../profile/widgets/profile_avatar.dart';
import '../../../shared/models/user.dart' as app_user;
import '../../../shared/repositories/profile_service.dart';

class CallScreen extends StatefulWidget {
  final String? receiverId;
  final String? callId;
  final String? conversationId;

  const CallScreen({super.key, this.receiverId, this.callId, this.conversationId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  app_user.User? _receiver;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  StreamSubscription<String>? _errorSubscription;
  RTCVideoRenderer? _remoteRenderer;
  RTCVideoRenderer? _localRenderer;
  bool _renderersAttached = false;

  @override
  void initState() {
    super.initState();
    debugPrint('CallScreen: Initialized with receiverId: ${widget.receiverId}, callId: ${widget.callId}');
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _initRenderers();
    await _loadReceiverInfo();
    _setupErrorHandling();
    await _startCallIfNeeded();
  }

  Future<void> _initRenderers() async {
    _remoteRenderer = RTCVideoRenderer();
    _localRenderer = RTCVideoRenderer();

    // Initialize renderers (critical for audio playback!)
    await _remoteRenderer!.initialize();
    await _localRenderer!.initialize();

    debugPrint('🎵 Audio renderers initialized and ready for stream attachment');
  }

  Future<void> _loadReceiverInfo() async {
    if (widget.receiverId != null) {
      try {
        _receiver = await ProfileService.getUserProfile(widget.receiverId!);
        debugPrint('CallScreen: Loaded receiver: ${_receiver?.displayName}');
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Error loading receiver info: $e');
        _receiver = app_user.User(
          id: widget.receiverId!,
          email: 'user@example.com',
          displayName: 'User',
          username: 'user',
        );
        if (mounted) setState(() {});
      }
    }
  }

  void _setupErrorHandling() {
    _errorSubscription = context.read<AudioOnlyCallProvider>().errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _startCallIfNeeded() async {
    if (widget.receiverId != null && widget.callId == null) {
      debugPrint('📞 Starting outgoing audio-only call to ${widget.receiverId}');
      await context.read<AudioOnlyCallProvider>().startCall(
        widget.receiverId!,
        conversationId: widget.conversationId,
      );
    }
  }

  void _attachStreamsToRenderers(AudioOnlyCallProvider callProvider) {
    // Only attach once and when streams are available
    if (_renderersAttached) return;

    bool attached = false;

    // Attach remote stream to renderer (CRITICAL FOR AUDIO PLAYBACK!)
    if (_remoteRenderer != null &&
        callProvider.remoteStream != null &&
        _remoteRenderer!.srcObject == null) {
      _remoteRenderer!.srcObject = callProvider.remoteStream;
      debugPrint('🔊 ATTACHED REMOTE STREAM TO RENDERER - AUDIO SHOULD PLAY!');
      debugPrint('🔊 REMOTE STREAM: id=${callProvider.remoteStream?.id}, audio_tracks=${callProvider.remoteStream?.getAudioTracks().length}');
      debugPrint('🔊 RENDERER: srcObject set to stream ${callProvider.remoteStream?.id}');
      attached = true;
    }

    // Attach local stream to renderer (for echo cancellation and proper audio processing)
    if (_localRenderer != null &&
        callProvider.localStream != null &&
        _localRenderer!.srcObject == null) {
      _localRenderer!.srcObject = callProvider.localStream;
      debugPrint('🎤 ATTACHED LOCAL STREAM TO RENDERER - ECHO CANCELLATION ACTIVE');
      debugPrint('🎤 LOCAL STREAM: id=${callProvider.localStream?.id}, audio_tracks=${callProvider.localStream?.getAudioTracks().length}');
      attached = true;
    }

    if (attached &&
        callProvider.remoteStream != null &&
        callProvider.localStream != null) {
      _renderersAttached = true;
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel(); // Cancel any existing timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
    debugPrint('⏰ CallScreen timer started');
  }

  Future<void> _setupAudioForPlatform() async {
    try {
      // Platform-specific audio setup
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms: For better audio quality in calls, set to voice communication mode
        await AudioHelper.setSpeakerphoneOn(false); // Start with earpiece mode
        debugPrint('🔊 Mobile: Audio routing set for voice communication');
      } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // Desktop platforms: Audio works through default system output
        debugPrint('🔊 Desktop: Using system default audio output');
      } else {
        // Web/other platforms
        debugPrint('🔊 Web/Other: Audio routing handled by browser/system');
      }

      debugPrint('✅ Audio setup complete - call should have working audio!');
    } catch (e) {
      debugPrint('⚠️ Audio setup failed (non-critical): $e');
      debugPrint('ℹ️ Audio may still work through default system settings');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioOnlyCallProvider>(
      builder: (context, callProvider, child) {
        final call = callProvider.currentCall;
        final callState = call?.state ?? CallState.idle;

        // Start timer when call becomes connected
        if (callState == CallState.connected && _callTimer == null) {
          _startCallTimer();
          // Platform-aware audio routing
          _setupAudioForPlatform();
        }

        // Attach streams to renderers
        _attachStreamsToRenderers(callProvider);

        // Auto-navigate away when call ends
        if (callState == CallState.ended) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/home');
            }
          });
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Stack(
            children: [
              // CRITICAL: These RTCVideoView widgets MUST be in the widget tree
              // for audio to play, even though we're hiding them for audio-only calls!

              // Remote audio renderer (hidden but necessary for audio playback)
              if (_remoteRenderer != null)
                Positioned(
                  top: -1000, // Hide off-screen
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: RTCVideoView(
                      _remoteRenderer!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    ),
                  ),
                ),

              // Local audio renderer (hidden but necessary)
              if (_localRenderer != null)
                Positioned(
                  top: -1000, // Hide off-screen
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: RTCVideoView(
                      _localRenderer!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      mirror: true,
                    ),
                  ),
                ),

              // Actual UI
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: _CallDisplay(
                        receiver: _receiver,
                        callState: callState,
                        callDuration: _callDuration,
                        formatDuration: _formatDuration,
                      ),
                    ),
                    _CallToolbar(
                      callState: callState,
                      isMuted: callProvider.isMuted,
                      isSpeakerOn: callProvider.isSpeakerOn,
                      onToggleMute: () => callProvider.toggleMute(),
                      onToggleSpeaker: () => callProvider.toggleSpeaker(),
                      onEndCall: () {
                        callProvider.endCall(conversationId: widget.conversationId);
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) context.go('/home');
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    debugPrint('🧹 CallScreen: Disposing...');
    _callTimer?.cancel();
    _errorSubscription?.cancel();

    // Clean up renderers
    _remoteRenderer?.srcObject = null;
    _localRenderer?.srcObject = null;

    // Dispose renderers properly to prevent audio issues
    try {
      _remoteRenderer?.dispose();
      _localRenderer?.dispose();
    } catch (e) {
      debugPrint('Error disposing renderers: $e');
    }

    _remoteRenderer = null;
    _localRenderer = null;

    super.dispose();
  }
}

// _CallDisplay widget (same as before)
class _CallDisplay extends StatelessWidget {
  final app_user.User? receiver;
  final CallState callState;
  final Duration callDuration;
  final String Function(Duration) formatDuration;

  const _CallDisplay({
    required this.receiver,
    required this.callState,
    required this.callDuration,
    required this.formatDuration,
  });

  String _getStatusText(CallState state) {
    switch (state) {
      case CallState.calling:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connected:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          ProfileAvatar(
            avatarUrl: receiver?.avatarUrl,
            displayName: receiver?.displayName ?? 'Unknown',
            size: 120,
            showBorder: true,
          ),

          const SizedBox(height: 32),

          // Name
          Text(
            receiver?.displayName ?? 'Unknown User',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Call status
          Text(
            _getStatusText(callState),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 8),

          // Call duration (only show when connected)
          if (callState == CallState.connected)
            Text(
              formatDuration(callDuration),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),

          // Connection quality indicator
          if (callState == CallState.connected) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// _CallToolbar widget (same as before)
class _CallToolbar extends StatelessWidget {
  final CallState callState;
  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  const _CallToolbar({
    required this.callState,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: theme.colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button (only show when connected)
          if (callState == CallState.connected)
            _ToolbarIconButton(
              icon: isMuted ? Icons.mic_off : Icons.mic,
              label: isMuted ? 'Unmute' : 'Mute',
              color: isMuted ? Colors.red : theme.colorScheme.primary,
              onPressed: onToggleMute,
            )
          else
            const SizedBox(width: 72),

          // End call button (always visible)
          _EndCallToolbarButton(onPressed: onEndCall),

          // Speaker button (only show when connected)
          if (callState == CallState.connected)
            _ToolbarIconButton(
              icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: isSpeakerOn ? 'Speaker' : 'Earpiece',
              color: theme.colorScheme.primary,
              onPressed: onToggleSpeaker,
            )
          else
            const SizedBox(width: 72),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 24),
            onPressed: onPressed,
            tooltip: label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EndCallToolbarButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EndCallToolbarButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
      child: IconButton(
        icon: const Icon(Icons.call_end, color: Colors.white, size: 28),
        onPressed: onPressed,
        tooltip: 'End Call',
      ),
    );
  }
}
