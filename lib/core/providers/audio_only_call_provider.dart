import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/audio_only_webrtc_service.dart';

class AudioOnlyCallProvider with ChangeNotifier {
  final AudioOnlyWebRTCService _audioOnlyWebRTCService = AudioOnlyWebRTCService();

  WebRTCCall? _currentCall;
  WebRTCCall? get currentCall => _currentCall;
  MediaStream? get localStream => _audioOnlyWebRTCService.localStream;
  MediaStream? get remoteStream => _audioOnlyWebRTCService.remoteStream;
  Stream<WebRTCCall?> get callStream => _audioOnlyWebRTCService.callStream;
  Stream<CallState> get callStateStream => _audioOnlyWebRTCService.callStateStream;
  Stream<String> get errorStream => _audioOnlyWebRTCService.errorStream;
  Stream<Map<String, dynamic>> get incomingCallStream => _audioOnlyWebRTCService.incomingCallStream;

  bool _isMuted = false;
  bool _isSpeakerOn = false;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  StreamSubscription<WebRTCCall?>? _callSubscription;

  AudioOnlyCallProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint('AudioOnlyCallProvider: Initializing audio-only WebRTC service...');
    await _audioOnlyWebRTCService.initialize();

    // Listen to call stream to update currentCall and notify listeners
    _callSubscription = _audioOnlyWebRTCService.callStream.listen((call) {
      _currentCall = call;
      notifyListeners();
    });

    debugPrint('AudioOnlyCallProvider: Audio-only WebRTC service initialized successfully');
  }

  Future<void> startCall(String receiverId, {String? conversationId}) async {
    await _audioOnlyWebRTCService.startCall(receiverId, conversationId: conversationId);
    notifyListeners();
  }

  Future<void> answerCall(String callId) async {
    await _audioOnlyWebRTCService.answerCall(callId);
    notifyListeners();
  }

  Future<void> endCall({String? conversationId}) async {
    await _audioOnlyWebRTCService.endCall(conversationId: conversationId);
    _isMuted = false;
    _isSpeakerOn = false;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _audioOnlyWebRTCService.toggleMute(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _audioOnlyWebRTCService.toggleSpeaker(_isSpeakerOn);
    notifyListeners();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _audioOnlyWebRTCService.dispose();
    super.dispose();
  }
}