import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/audio_helper.dart';

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

class AudioOnlyWebRTCService {
  static final AudioOnlyWebRTCService _instance = AudioOnlyWebRTCService._internal();
  factory AudioOnlyWebRTCService() => _instance;
  AudioOnlyWebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentCallId;
  WebRTCCall? _currentCall;

  // Audio-only renderers
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  final StreamController<WebRTCCall?> _callController = StreamController<WebRTCCall?>.broadcast();
  final StreamController<CallState> _callStateController = StreamController<CallState>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
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
    await _initializeAudioSession();
    await _initializeRenderers();
    await _initializeWebRTC();
    await _setupIncomingCallSubscription();
  }

  Future<void> _initializeAudioSession() async {
    // Initialize platform-specific audio configuration before any WebRTC operations
    await AudioHelper.initializeWebRTCAudio();
    debugPrint('✅ Audio session initialized for WebRTC calls');
  }

  Future<void> _initializeRenderers() async {
    // Initialize audio-only renderers
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    debugPrint('✅ Audio renderers initialized');
  }

  Future<void> _initializeWebRTC() async {
    try {
      // WebRTC configuration optimized for audio-only calls
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          // Add TURN server if needed for NAT traversal
        ],
        'sdpSemantics': 'unified-plan',
      };

      // Audio-only constraints that ensure proper negotiation
      final offerConstraints = <String, dynamic>{
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false, // Explicitly disable video
        },
        'optional': [],
      };

      _peerConnection = await createPeerConnection(configuration, offerConstraints);

      _peerConnection?.onIceCandidate = (candidate) => _onIceCandidate(candidate);
      _peerConnection?.onTrack = (event) => _onTrack(event);
      _peerConnection?.onConnectionState = (state) => _onConnectionState(state);
      _peerConnection?.onIceConnectionState = (state) => _onIceConnectionState(state);
      _peerConnection?.onSignalingState = (state) => _onSignalingState(state);
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

      _currentCallId = '${callerId}_to_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';
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

      // Ensure audio session is properly configured before starting call
      await AudioHelper.initializeCallAudio();

      // Get audio-only stream
      _localStream = await _getAudioStream();
      if (_localStream != null) {
        debugPrint('🎤 Local audio stream created with ${_localStream!.getAudioTracks().length} tracks');
        
        // Add audio tracks to peer connection
        await _addLocalAudioTracks();
        
        // Set local renderer for echo cancellation and proper audio processing
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _localStream;
          debugPrint('🎤 Local stream set to renderer');
        }
      }

      // Create offer and set local description
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false, // Explicitly for audio-only
      });
      await _peerConnection!.setLocalDescription(offer);

      // Setup signaling channel and send offer
      await _setupSignalingChannel();
      await _sendSignalingMessage('offer', {
        'callId': _currentCallId,
        'callerId': callerId,
        'receiverId': receiverId,
        'offer': offer.toMap(),
      });

      // Start missed call timer
      _startMissedCallTimer(conversationId: conversationId);
    } catch (e) {
      debugPrint('❌ Error starting call: $e');
      _errorController.add('Failed to start call: ${e.toString()}');
      await _cleanupCall();
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      debugPrint('📞 Answering call: $callId');

      if (_peerConnection == null) await _initializeWebRTC();

      // Initialize audio for the call
      await AudioHelper.initializeCallAudio();

      // Set remote description with the received offer
      if (_currentCall?.offer != null) {
        final offer = RTCSessionDescription(
          _currentCall!.offer!['sdp'],
          _currentCall!.offer!['type'],
        );
        await _peerConnection?.setRemoteDescription(offer);
        debugPrint('✅ Set remote description with received offer');
      } else {
        throw Exception('No offer available to answer');
      }

      // Get local audio stream
      _localStream = await _getAudioStream();
      if (_localStream != null) {
        debugPrint('🎤 Answer call - Local audio stream created');
        
        // Add audio tracks to peer connection
        await _addLocalAudioTracks();
        
        // Set local renderer for echo cancellation
        if (_localRenderer != null) {
          _localRenderer!.srcObject = _localStream;
          debugPrint('🎤 Answer call - Local stream set to renderer');
        }
      }

      // Create and send answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer back to caller
      await _sendSignalingMessage('answer', {
        'callId': callId,
        'callerId': _currentCall!.callerId,
        'receiverId': _currentCall!.callerId,  // Send answer to the caller
        'answer': answer.toMap(),
      });

      // Update call state
      _currentCallId = callId;
      _currentCall?.state = CallState.connected;
      _callController.add(_currentCall);
      _callStateController.add(CallState.connected);

      debugPrint('📞 Call answered successfully');
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

      // Notify remote party about call end
      if (_currentCallId != null) {
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
        }
      }

      // Save call event if the call was connected
      if (_currentCall?.state == CallState.connected) {
        // Save call event logic here if needed
      }

      // Cleanup and reset audio
      await _cleanupCall();
      await AudioHelper.resetAudio();

      debugPrint('📞 Call ended successfully');
    } catch (e) {
      _errorController.add('Error ending call: ${e.toString()}');
    }
  }

  Future<void> _cleanupCall() async {
    _cancelMissedCallTimer();
    await _cleanup();
    
    _currentCall?.state = CallState.ended;
    _callController.add(_currentCall);
    _callStateController.add(CallState.ended);

    // Reset call state after delay
    Future.delayed(const Duration(seconds: 2), () {
      _currentCall = null;
      _currentCallId = null;
      _callStartTime = null;
      _callController.add(null);
      _callStateController.add(CallState.idle);
    });
  }

  Future<void> _cleanup() async {
    // Stop all tracks to prevent audio issues
    _localStream?.getAudioTracks().forEach((track) {
      if (track.enabled) {
        track.stop();
      }
    });
    _remoteStream?.getAudioTracks().forEach((track) {
      if (track.enabled) {
        track.stop();
      }
    });

    // Clean up renderers
    _localRenderer?.srcObject = null;
    _remoteRenderer?.srcObject = null;

    // Close peer connection
    await _peerConnection?.close();
    await _signalingChannel?.unsubscribe();

    // Clear references
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _signalingChannel = null;

    // Notify that remote stream is gone
    _remoteStreamController.add(null);
  }

  Future<MediaStream> _getAudioStream() async {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false, // Explicitly disable video for audio-only
    };

    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> _addLocalAudioTracks() async {
    if (_localStream != null && _peerConnection != null) {
      for (var track in _localStream!.getAudioTracks()) {
        if (track.enabled) {
          await _peerConnection!.addTrack(track, _localStream!);
          debugPrint('🎤 Added local audio track: ${track.id} to peer connection');
        }
      }
    }
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
      final record = payload.newRecord!;
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
    debugPrint('📞 Handling incoming call: $data');

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

    debugPrint('📞 Incoming call data sent to stream');
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      debugPrint('📞 Handling answer message: $data');

      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );

      await _peerConnection?.setRemoteDescription(answer);
      debugPrint('✅ Set remote description with answer');

      _currentCall?.state = CallState.connected;
      _callController.add(_currentCall);
      _callStateController.add(CallState.connected);

      // Cancel the missed call timer since call was answered
      _cancelMissedCallTimer();

      // Start call timer when connection is established
      if (_callStartTime == null) {
        _callStartTime = DateTime.now();
        debugPrint('⏰ Call timer started');
      }

      debugPrint('📞 Call state changed to connected');
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

      // Enable all audio tracks to ensure they play
      for (var track in _remoteStream!.getAudioTracks()) {
        if (!track.enabled) {
          track.enabled = true;
          debugPrint('🔊 Enabled remote audio track: ${track.id}');
        }
      }

      // CRITICAL: Set the remote stream to the renderer for audio playback
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = _remoteStream;
        debugPrint('🔊 AUDIO: Remote stream set to renderer - audio should play!');
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

        // Enable remote audio tracks on connection
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

  void _onSignalingState(RTCSignalingState state) {
    debugPrint('💬 Signaling state: $state');
  }

  Future<void> toggleMute(bool mute) async {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !mute;
    });
  }

  Future<void> toggleSpeaker(bool speaker) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await AudioHelper.setSpeakerphoneOn(speaker);
        debugPrint('🔊 Mobile: Speakerphone set to: $speaker');
      } else {
        debugPrint('🔊 Desktop: Speakerphone control not available on this platform');
      }
    } catch (e) {
      debugPrint('⚠️ Speaker toggle failed: $e');
    }
  }

  void _startMissedCallTimer({String? conversationId}) {
    _missedCallTimer?.cancel();

    _missedCallTimer = Timer(const Duration(seconds: 30), () {
      if (_currentCall?.state == CallState.ringing) {
        // Handle missed call logic here if needed
        endCall(conversationId: conversationId);
      }
    });
  }

  void _cancelMissedCallTimer() {
    _missedCallTimer?.cancel();
    _missedCallTimer = null;
  }

  // Debug method to check audio status
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
          debugPrint('  - ${track.id}: enabled=${track.enabled}');
        });
      }

      // Check remote stream status
      debugPrint('🎵 Remote Stream: ${_remoteStream != null}');
      if (_remoteStream != null) {
        final audioTracks = _remoteStream!.getAudioTracks();
        debugPrint('🎵 Remote Audio Tracks: ${audioTracks.length}');
        audioTracks.forEach((track) {
          debugPrint('  - ${track.id}: enabled=${track.enabled}');
        });
      }

      // Check renderers
      debugPrint('📺 Local Renderer: ${_localRenderer != null}');
      debugPrint('📺 Remote Renderer: ${_remoteRenderer != null}');

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

    // Dispose renderers properly
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _localRenderer = null;
    _remoteRenderer = null;
    
    // Reset audio to normal mode
    AudioHelper.resetAudio();
  }
}