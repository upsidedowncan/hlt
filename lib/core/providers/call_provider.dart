import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';

class CallProvider with ChangeNotifier {
  final WebRTCService _webRTCService = WebRTCService();

  WebRTCCall? _currentCall;
  WebRTCCall? get currentCall => _currentCall;
  MediaStream? get localStream => _webRTCService.localStream;
  MediaStream? get remoteStream => _webRTCService.remoteStream;
  Stream<WebRTCCall?> get callStream => _webRTCService.callStream;
  Stream<CallState> get callStateStream => _webRTCService.callStateStream;
  Stream<String> get errorStream => _webRTCService.errorStream;
  Stream<Map<String, dynamic>> get incomingCallStream => _webRTCService.incomingCallStream;

  bool _isMuted = false;
  bool _isSpeakerOn = false;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  StreamSubscription<WebRTCCall?>? _callSubscription;

  CallProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint('CallProvider: Initializing WebRTC service...');
    await _webRTCService.initialize();

    // Listen to call stream to update currentCall and notify listeners
    _callSubscription = _webRTCService.callStream.listen((call) {
      _currentCall = call;
      notifyListeners();
    });

    debugPrint('CallProvider: WebRTC service initialized successfully');
  }

  Future<void> startCall(String receiverId, {String? conversationId}) async {
    await _webRTCService.startCall(receiverId, conversationId: conversationId);
    notifyListeners();
  }

  Future<void> answerCall(String callId) async {
    await _webRTCService.answerCall(callId);
    notifyListeners();
  }

  Future<void> endCall({String? conversationId}) async {
    await _webRTCService.endCall(conversationId: conversationId);
    _isMuted = false;
    _isSpeakerOn = false;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _webRTCService.toggleMute(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _webRTCService.toggleSpeaker(_isSpeakerOn);
    notifyListeners();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _webRTCService.dispose();
    super.dispose();
  }
}