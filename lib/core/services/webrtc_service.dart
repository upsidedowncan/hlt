import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/audio_helper.dart';
import '../../shared/models/message.dart';
import '../../shared/repositories/message_service.dart';
import '../../shared/repositories/conversation_service.dart';

enum CallState { idle, calling, ringing, connected, ended }

enum CallType { audio }

class WebRTCCall {
  final String callId;
  final String callerId;
  final String receiverId;
  final CallType type;
  final DateTime startedAt;
  CallState state;
  Map<String, dynamic>? offer; // Store the offer for incoming calls

  WebRTCCall({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.startedAt,
    this.state = CallState.idle,
    this.offer,
  });

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'type': type.toString(),
      'startedAt': startedAt.toIso8601String(),
      'state': state.toString(),
    };
  }

  factory WebRTCCall.fromMap(Map<String, dynamic> map) {
    return WebRTCCall(
      callId: map['callId'],
      callerId: map['callerId'],
      receiverId: map['receiverId'],
      type: CallType.audio,
      startedAt: DateTime.parse(map['startedAt']),
      state: CallState.values.firstWhere(
        (e) => e.toString() == map['state'],
        orElse: () => CallState.idle,
      ),
    );
  }
}

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentCallId;
  WebRTCCall? _currentCall;

  // Add renderers for audio playback
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  final StreamController<WebRTCCall?> _callController = StreamController<WebRTCCall?>.broadcast();
  final StreamController<CallState> _callStateController = StreamController<CallState>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  
  // NEW: Stream controller for remote stream updates
  final StreamController<MediaStream?> _remoteStreamController = StreamController<MediaStream?>.broadcast();

  Stream<WebRTCCall?> get callStream => _callController.stream;
  Stream<CallState> get callStateStream => _callStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get incomingCallStream => _incomingCallController.stream;
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  WebRTCCall? get currentCall => _currentCall;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  RealtimeChannel? _signalingChannel;
  Timer? _missedCallTimer;
  DateTime? _callStartTime;

  Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize audio session for WebRTC calls
    await AudioHelper.initializeWebRTCAudio();

    // Initialize renderers
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    debugPrint('✅ Audio renderers initialized');

    await _initializeWebRTC();
    await _setupIncomingCallSubscription();
  }

  Future<void> _initializeWebRTC() async {
    try {
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection?.onIceCandidate = (candidate) {
        Future.microtask(() => _onIceCandidate(candidate));
      };

      _peerConnection?.onTrack = (event) {
        Future.microtask(() => _onTrack(event));
      };

      _peerConnection?.onConnectionState = (state) {
        Future.microtask(() => _onConnectionState(state));
      };

      _peerConnection?.onIceConnectionState = (state) {
        Future.microtask(() => _onIceConnectionState(state));
      };
    } catch (e) {
      _errorController.add('Failed to initialize WebRTC: ${e.toString()}');
    }
  }

  Future<void> _setupIncomingCallSubscription() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('Cannot set up subscription: no authenticated user');
        return;
      }

      debugPrint('Setting up real-time subscription for user: $currentUserId');

      try {
        await Supabase.instance.client.from('webrtc_signals').select('id').limit(1);
        debugPrint('✅ webrtc_signals table exists');
      } catch (e) {
        debugPrint('❌ webrtc_signals table does not exist or is not accessible: $e');
        debugPrint('Please run the SQL setup script to create the webrtc_signals table');
        return;
      }

      // Check for any existing offer messages for this user
      try {
        final existingOffers = await Supabase.instance.client
            .from('webrtc_signals')
            .select('*')
            .eq('receiver_id', currentUserId)
            .eq('type', 'offer')
            .order('created_at', ascending: false)
            .limit(5);

        debugPrint('🔍 Existing offer messages for user $currentUserId: $existingOffers');
        if (existingOffers.isNotEmpty) {
          debugPrint('⚠️ Found existing offer messages that may not have been processed!');
        }
      } catch (e) {
        debugPrint('❌ Error checking for existing offers: $e');
      }

      final channel = Supabase.instance.client
          .channel('webrtc_signaling_$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'webrtc_signals',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: currentUserId,
            ),
             callback: (payload) async {
               debugPrint('📨 Received signaling message: ${payload.newRecord}');
               final record = payload.newRecord;
               final type = record['type'];
               final receiverId = record['receiver_id'];
               final senderId = record['sender_id'];
               debugPrint('📨 Message type: $type, sender: $senderId, receiver: $receiverId, current user: $currentUserId');
               if (type == 'answer') {
                 debugPrint('🎯 ANSWER MESSAGE RECEIVED! Processing...');
               } else if (type == 'offer') {
                 debugPrint('🎯 OFFER MESSAGE RECEIVED! Processing...');
               }
               // Use Future.microtask to ensure we're on the main thread
               await Future.microtask(() => _handleSignalingMessage(payload));
             },
          );

      channel.subscribe();
      debugPrint('✅ Successfully subscribed to webrtc_signaling_$currentUserId');
    } catch (e) {
      debugPrint('❌ Error setting up incoming call subscription: $e');
    }
  }

  Future<void> startCall(String receiverId, {String? conversationId}) async {
    try {
      final callerId = Supabase.instance.client.auth.currentUser?.id;
      if (callerId == null) throw Exception('User not authenticated');

      _currentCallId = '${callerId}_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';
      _currentCall = WebRTCCall(
        callId: _currentCallId!,
        callerId: callerId,
        receiverId: receiverId,
        type: CallType.audio,
        startedAt: DateTime.now(),
        state: CallState.calling,
      );

      _callController.add(_currentCall);
      _callStateController.add(CallState.calling);

      if (_peerConnection == null) {
        await _initializeWebRTC();
      }

      // Initialize audio for the call
      await AudioHelper.initializeCallAudio();

      await _ensureMainThread();

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      debugPrint('🎤 Local stream created: ${_localStream != null}');
      if (_localStream != null) {
        debugPrint('🎤 Local audio tracks: ${_localStream!.getAudioTracks().length}');
        _localStream!.getAudioTracks().forEach((track) {
          debugPrint('🎤 Audio track: enabled=${track.enabled}, muted=${track.muted}, id=${track.id}');
        });

        // Set local stream to renderer for monitoring (optional, usually muted)
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _localStream;
          debugPrint('🎤 Set local stream to renderer');
        }
      } else {
        debugPrint('❌ Failed to get local audio stream!');
      }

      if (_localStream != null && _peerConnection != null) {
        // Only add audio tracks for audio-only calls
        for (var track in _localStream!.getAudioTracks()) {
          if (track.enabled) {
            _peerConnection!.addTrack(track, _localStream!);
            debugPrint('🎤 Added local audio track: ${track.id} to peer connection');
          }
        }
        debugPrint('🎤 Added local audio tracks to peer connection');

        final offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);

        await _setupSignalingChannel();

        await _sendSignalingMessage('offer', {
          'callId': _currentCallId,
          'callerId': callerId,
          'receiverId': receiverId,
          'offer': offer.toMap(),
        });

        _startMissedCallTimer(conversationId: conversationId);
      } else {
        throw Exception('Failed to initialize media stream or peer connection');
      }
    } catch (e) {
      _errorController.add('Failed to start call: ${e.toString()}');
      await endCall(conversationId: conversationId);
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      debugPrint('📞 Starting answerCall for callId: $callId');
      debugPrint('📞 Current call: $_currentCall');

      if (_peerConnection == null) await _initializeWebRTC();

      // Initialize audio for the call
      await AudioHelper.initializeCallAudio();

      await _ensureMainThread();

      // Set remote description with the offer
      if (_currentCall?.offer != null) {
        final offer = RTCSessionDescription(
          _currentCall!.offer!['sdp'],
          _currentCall!.offer!['type'],
        );
        await _peerConnection?.setRemoteDescription(offer);
        debugPrint('✅ Set remote description with offer');
      } else {
        throw Exception('No offer available to answer');
      }

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      debugPrint('🎤 Answer call - Local stream created: ${_localStream != null}');
      if (_localStream != null) {
        debugPrint('🎤 Answer call - Local audio tracks: ${_localStream!.getAudioTracks().length}');
        _localStream!.getAudioTracks().forEach((track) {
          debugPrint('🎤 Answer call - Audio track: enabled=${track.enabled}, muted=${track.muted}');
        });

        // Set local stream to renderer
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _localStream;
          debugPrint('🎤 Set local stream to renderer');
        }
      }

      if (_localStream != null && _peerConnection != null) {
        // Only add audio tracks for audio-only calls
        for (var track in _localStream!.getAudioTracks()) {
          if (track.enabled) {
            _peerConnection!.addTrack(track, _localStream!);
            debugPrint('🎤 Answer call - Added local audio track: ${track.id} to peer connection');
          }
        }
        debugPrint('🎤 Answer call - Added local audio tracks to peer connection');

        // Create answer
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        // Send answer back to caller
        await _sendSignalingMessage('answer', {
          'callId': callId,
          'callerId': _currentCall!.callerId,
          'receiverId': _currentCall!.callerId,  // Send answer to the caller
          'answer': answer.toMap(),
        });

        debugPrint('✅ Created and sent answer');
      }

      _currentCallId = callId;
      _currentCall?.state = CallState.connected;
      _callController.add(_currentCall);
      _callStateController.add(CallState.connected);

      await _saveCallEvent(CallEventType.answered);
      debugPrint('📞 Answer call completed successfully');
    } catch (e) {
      debugPrint('❌ Failed to answer call: $e');
      _errorController.add('Failed to answer call: ${e.toString()}');
      await endCall();
    }
  }

  Future<void> endCall({String? conversationId}) async {
    try {
      int duration = 0;
      if (_callStartTime != null) {
        duration = DateTime.now().difference(_callStartTime!).inSeconds;
      }

      if (_currentCallId != null) {
        // For end messages, we need to determine the receiver
        // If we have a current call, use the other participant
        // Otherwise, this might be an incoming call that was never fully established
        String? receiverId;
        if (_currentCall != null) {
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          receiverId = _currentCall!.callerId == currentUserId
              ? _currentCall!.receiverId
              : _currentCall!.callerId;
        }

        if (receiverId != null) {
          await _sendSignalingMessage('end', {
            'callId': _currentCallId,
            'receiverId': receiverId,
          });
        } else {
          debugPrint('⚠️ Cannot send end message: no receiver ID available');
        }
      }

      if (_currentCall?.state == CallState.connected) {
        await _saveCallEvent(CallEventType.ended, duration: duration, conversationId: conversationId);
      }

      _cancelMissedCallTimer();
      await _cleanup();

      // Reset audio after ending the call
      await AudioHelper.resetAudio();

      _currentCall?.state = CallState.ended;
      _callController.add(_currentCall);
      _callStateController.add(CallState.ended);

      Future.delayed(const Duration(seconds: 2), () {
        _currentCall = null;
        _currentCallId = null;
        _callStartTime = null;
        _callController.add(null);
        _callStateController.add(CallState.idle);
      });
    } catch (e) {
      _errorController.add('Error ending call: ${e.toString()}');
    }
  }

  Future<void> _cleanup() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.getTracks().forEach((track) => track.stop());

    // Clean up renderers
    _localRenderer?.srcObject = null;
    _remoteRenderer?.srcObject = null;

    await _peerConnection?.close();
    await _signalingChannel?.unsubscribe();

    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _signalingChannel = null;

    // Notify UI that remote stream is gone
    _remoteStreamController.add(null);
  }

  Future<void> _setupSignalingChannel() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _signalingChannel = Supabase.instance.client.channel('webrtc_call_${_currentCallId}');
    _signalingChannel?.subscribe();
  }

  Future<void> _sendSignalingMessage(String type, Map<String, dynamic> data) async {
    try {
      final senderId = Supabase.instance.client.auth.currentUser?.id;
      final receiverId = data['receiverId'] ?? _currentCall?.receiverId;
      final callId = data['callId'] ?? _currentCallId;

      debugPrint('📤 Sending $type message: sender=$senderId, receiver=$receiverId, callId=$callId');

      final insertData = {
        'type': type,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'call_id': callId,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('webrtc_signals').insert(insertData);

      debugPrint('✅ Successfully sent $type message');


    } catch (e) {
      debugPrint('❌ Failed to send signaling message: $e');
      _errorController.add('Failed to send signaling message: ${e.toString()}');
    }
  }

  void _handleSignalingMessage(PostgresChangePayload payload) {
    debugPrint('🎯 _handleSignalingMessage called with payload: ${payload.newRecord}');
    try {
      final record = payload.newRecord;
      final dataRaw = record['data'];
      Map<String, dynamic> data;

      if (dataRaw is String) {
        data = jsonDecode(dataRaw) as Map<String, dynamic>;
      } else if (dataRaw is Map<String, dynamic>) {
        data = dataRaw;
      } else {
        debugPrint('❌ Data is neither string nor map: $dataRaw');
        return;
      }
      final type = record['type'] as String;

      debugPrint('🔄 Processing signaling message type: "$type"');

      switch (type) {
        case 'offer':
          debugPrint('📞 Processing offer message with data: $data');
          _handleIncomingCall(data);
          break;
        case 'answer':
          debugPrint('📞 Processing answer message');
          _handleAnswer(data);
          break;
        case 'ice_candidate':
          // ICE candidates are very verbose, only log occasionally
          _handleIceCandidate(data);
          break;
        case 'end':
          debugPrint('📞 Processing end message');
          endCall();
          break;
        default:
          debugPrint('⚠️ Unknown message type: $type with data: $data');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling signaling message: $e');
      _errorController.add('Error handling signaling message: ${e.toString()}');
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    debugPrint('📞 WebRTCService: Handling incoming call: $data');

    // Set the current call info for incoming calls
    _currentCallId = data['callId'];
    _currentCall = WebRTCCall(
      callId: data['callId'],
      callerId: data['callerId'],
      receiverId: data['receiverId'],
      type: CallType.audio,
      startedAt: DateTime.now(),
      state: CallState.ringing,
      offer: data['offer'], // Store the offer
    );

    _incomingCallController.add({
      'callId': data['callId'],
      'callerId': data['callerId'],
      'receiverId': data['receiverId'],
      'offer': data['offer'],
    });
    debugPrint('📞 WebRTCService: Incoming call data sent to stream');
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      debugPrint('📞 Handling answer message: $data');
      debugPrint('📞 Current call before answer: $_currentCall');

      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );

      await _peerConnection?.setRemoteDescription(answer);
      debugPrint('✅ Set remote description with answer');

      _currentCall?.state = CallState.connected;
      _callController.add(_currentCall);
      _callStateController.add(CallState.connected);
      debugPrint('✅ Call state changed to connected');
      debugPrint('📞 Current call after answer: $_currentCall');

      // Cancel the missed call timer since call was answered
      _cancelMissedCallTimer();
    } catch (e) {
      debugPrint('❌ Failed to handle answer: $e');
      _errorController.add('Failed to handle answer: ${e.toString()}');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      _errorController.add('Failed to handle ICE candidate: ${e.toString()}');
    }
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    if (_currentCallId != null) {
      _sendSignalingMessage('ice_candidate', {
        'callId': _currentCallId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    }
  }

  void _onTrack(RTCTrackEvent event) {
    debugPrint('🎵 WebRTC: Received track: ${event.track.kind}, enabled: ${event.track.enabled}, streams: ${event.streams.length}');
    if (event.track.kind == 'audio') {
      _remoteStream = event.streams[0];
      debugPrint('🎵 WebRTC: Set remote stream with ${event.streams[0].getAudioTracks().length} audio tracks');
      debugPrint('🎵 WebRTC: Remote stream audio tracks: ${event.streams[0].getAudioTracks().map((t) => 'enabled:${t.enabled}')}');

      // Enable all audio tracks to ensure they are playing
      for (var track in _remoteStream!.getAudioTracks()) {
        if (!track.enabled) {
          track.enabled = true;
          debugPrint('🔊 Enabled remote audio track: ${track.id}');
        }
      }

      // CRITICAL FIX: Set the remote stream to the renderer to actually play the audio!
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = _remoteStream;
        debugPrint('🔊 AUDIO FIX: Set remote stream to renderer - audio should now play!');
        debugPrint('🔊 AUDIO DEBUG: Renderer srcObject set to: ${_remoteRenderer!.srcObject?.id}');
      } else {
        debugPrint('❌ AUDIO ERROR: Remote renderer is null!');
      }

      // Notify listeners about the remote stream
      _remoteStreamController.add(_remoteStream);
    }
  }

  void _onConnectionState(RTCPeerConnectionState state) {
    debugPrint('🔗 WebRTC Connection state: $state');
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        debugPrint('🔗 WebRTC: Connection established!');
        _currentCall?.state = CallState.connected;
        _callController.add(_currentCall);
        _callStateController.add(CallState.connected);

        // Start call timer when connection is established
        if (_callStartTime == null) {
          _callStartTime = DateTime.now();
          debugPrint('⏰ Call timer started');
        }

        // Ensure remote audio tracks are enabled
        _remoteStream?.getAudioTracks().forEach((track) {
          if (!track.enabled) {
            track.enabled = true;
            debugPrint('🎵 Enabled remote audio track: ${track.id}');
          }
        });
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        debugPrint('🔗 WebRTC: Connection failed/disconnected');
        endCall();
        break;
      default:
        break;
    }
  }

  void _onIceConnectionState(RTCIceConnectionState state) {
    debugPrint('🧊 ICE Connection state: $state');
    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
      debugPrint('🧊 ICE: Connected!');
    }
  }

  Future<void> toggleMute(bool mute) async {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !mute;
    });
  }

  Future<void> toggleSpeaker(bool speaker) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms support speakerphone toggle
        await AudioHelper.setSpeakerphoneOn(speaker);
        debugPrint('🔊 Mobile: Speakerphone set to: $speaker');
      } else {
        // Desktop platforms don't have speakerphone control
        debugPrint('🔊 Desktop: Speakerphone control not available on this platform');
      }
    } catch (e) {
      debugPrint('⚠️ Speaker toggle failed: $e');
    }
  }

  Future<void> _saveCallEvent(CallEventType eventType, {int duration = 0, String? conversationId}) async {
    try {
      if (_currentCallId == null || _currentCall == null) return;

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      String targetConversationId;
      if (conversationId != null) {
        targetConversationId = conversationId;
      } else {
        final otherUserId = _currentCall!.callerId == currentUserId
            ? _currentCall!.receiverId
            : _currentCall!.callerId;

        final conversation = await ConversationService.findOrCreateConversation(
          otherUserId,
          'Chat',
        );

        if (conversation == null) return;
        targetConversationId = conversation.id;
      }

      await MessageService.sendCallEventMessage(
        conversationId: targetConversationId,
        callId: _currentCallId!,
        callerId: _currentCall!.callerId,
        receiverId: _currentCall!.receiverId,
        eventType: eventType,
        duration: duration,
      );

      debugPrint('Call event saved: $eventType for call $_currentCallId in conversation $targetConversationId');
    } catch (e) {
      debugPrint('Error saving call event: $e');
    }
  }

  void _startMissedCallTimer({String? conversationId}) {
    _missedCallTimer?.cancel();

    _missedCallTimer = Timer(const Duration(seconds: 30), () {
      if (_currentCall?.state == CallState.ringing) {
        _saveCallEvent(CallEventType.missed, conversationId: conversationId);
        endCall(conversationId: conversationId);
      }
    });
  }

  void _cancelMissedCallTimer() {
    _missedCallTimer?.cancel();
    _missedCallTimer = null;
  }

  Future<void> _ensureMainThread() async {
    await Future.delayed(Duration.zero);
  }

  // Debug method to test signaling
  Future<void> testSignaling(String testReceiverId) async {
    debugPrint('🧪 Testing signaling by sending test offer to $testReceiverId');
    final testCallId = 'test_call_${DateTime.now().millisecondsSinceEpoch}';
    await _sendSignalingMessage('offer', {
      'callId': testCallId,
      'callerId': Supabase.instance.client.auth.currentUser?.id ?? 'test_caller',
      'receiverId': testReceiverId,
      'offer': {'type': 'offer', 'sdp': 'test_sdp'},
    });
  }

  // Debug method to check table and existing messages
  Future<void> debugTableStatus() async {
    try {
      debugPrint('🔍 Checking webrtc_signals table status...');

      // Check if table exists
      final testQuery = await Supabase.instance.client.from('webrtc_signals').select('id').limit(1);
      debugPrint('✅ Table exists, test query result: $testQuery');

      // Check for any messages
      final allMessages = await Supabase.instance.client
          .from('webrtc_signals')
          .select('*')
          .order('created_at', ascending: false)
          .limit(10);

      debugPrint('📋 Recent messages in table: $allMessages');

      // Check current user messages
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final userMessages = await Supabase.instance.client
            .from('webrtc_signals')
            .select('*')
            .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
            .order('created_at', ascending: false)
            .limit(5);

        debugPrint('👤 Messages for current user ($currentUserId): $userMessages');
      }
    } catch (e) {
      debugPrint('❌ Error checking table status: $e');
    }
  }

  // Debug method to check audio devices and status
  Future<void> debugAudioStatus() async {
    try {
      debugPrint('🔊 AUDIO DEBUG: Checking audio status on ${Platform.operatingSystem}...');

      // Check available audio devices
      final devices = await navigator.mediaDevices.enumerateDevices();
      final audioInputs = devices.where((d) => d.kind == 'audioinput');
      final audioOutputs = devices.where((d) => d.kind == 'audiooutput');

      debugPrint('🎤 Audio Input Devices: ${audioInputs.length}');
      audioInputs.forEach((device) {
        debugPrint('  - ${device.label} (${device.deviceId})');
      });

      debugPrint('🔊 Audio Output Devices: ${audioOutputs.length}');
      audioOutputs.forEach((device) {
        debugPrint('  - ${device.label} (${device.deviceId})');
      });

      // Check local stream status
      debugPrint('🎤 Local Stream: ${_localStream != null}');
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        debugPrint('🎤 Local Audio Tracks: ${audioTracks.length}');
        audioTracks.forEach((track) {
          debugPrint('  - ${track.id}: enabled=${track.enabled}, muted=${track.muted}');
        });
      }

      // Check remote stream status
      debugPrint('🎵 Remote Stream: ${_remoteStream != null}');
      if (_remoteStream != null) {
        final audioTracks = _remoteStream!.getAudioTracks();
        debugPrint('🎵 Remote Audio Tracks: ${audioTracks.length}');
        audioTracks.forEach((track) {
          debugPrint('  - ${track.id}: enabled=${track.enabled}, muted=${track.muted}');
        });
      }

      // Check renderers
      debugPrint('📺 Local Renderer: ${_localRenderer != null}');
      debugPrint('📺 Remote Renderer: ${_remoteRenderer != null}');

      // Platform-specific notes
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('📱 Mobile: Speakerphone should be active');
      } else {
        debugPrint('🖥️ Desktop: Using system audio output');
      }

    } catch (e) {
      debugPrint('❌ Error checking audio status: $e');
    }
  }

  void dispose() {
    _cleanup();
    _callController.close();
    _callStateController.close();
    _errorController.close();
    _incomingCallController.close();
    _remoteStreamController.close();

    // Dispose renderers
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _localRenderer = null;
    _remoteRenderer = null;

    // Reset audio to normal mode on disposal
    AudioHelper.resetAudio();
  }
}
