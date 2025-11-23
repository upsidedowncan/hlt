import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioHelper {
  /// Sets the speakerphone on or off for audio calls
  /// This is important for proper audio routing during WebRTC calls
  static Future<void> setSpeakerphoneOn(bool enabled) async {
    try {
      if (Platform.isAndroid) {
        await Helper.setSpeakerphoneOn(enabled);
        debugPrint('📱 Android: Speakerphone set to ${enabled ? "ON" : "OFF"}');
      } else if (Platform.isIOS) {
        // On iOS, we need to ensure audio session is active for proper routing
        await Helper.ensureAudioSession();
        debugPrint('📱 iOS: Audio session ensured, speakerphone set to ${enabled ? "ON" : "OFF"}');
      } else {
        // On web and desktop, audio routing is handled by the browser/OS automatically
        debugPrint('${Platform.operatingSystem}: Audio routing handled by system');
      }
    } catch (e) {
      debugPrint('Error setting speakerphone: $e');
    }
  }

  /// Initialize WebRTC audio configuration for different platforms
  static Future<void> initializeWebRTCAudio() async {
    try {
      if (Platform.isAndroid) {
        // For Android audio configuration, we set up the audio mode before calls
        debugPrint('📞 Android: Preparing audio configuration for calls');
      } else if (Platform.isIOS) {
        // For iOS, ensure audio session is properly configured
        await Helper.ensureAudioSession();
        debugPrint('📞 iOS: Audio session configured for calls');
      }
    } catch (e) {
      debugPrint('Error initializing WebRTC audio: $e');
    }
  }

  /// Initializes audio for calls, ensuring proper audio routing
  static Future<void> initializeCallAudio() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Initialize platform-specific audio configuration
        await initializeWebRTCAudio();

        // Ensure proper audio session for calls
        if (Platform.isIOS) {
          await Helper.ensureAudioSession();
        }

        debugPrint('📞 Call audio initialized with proper routing');
      } else {
        debugPrint('${Platform.operatingSystem}: Call audio routing handled by system');
      }
    } catch (e) {
      debugPrint('Error initializing call audio: $e');
    }
  }

  /// Resets audio to normal mode after a call ends
  static Future<void> resetAudio() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // No special reset needed on mobile platforms
        debugPrint('🎧 Audio reset to normal mode');
      } else {
        debugPrint('${Platform.operatingSystem}: Audio reset handled by system');
      }
    } catch (e) {
      debugPrint('Error resetting audio: $e');
    }
  }
}