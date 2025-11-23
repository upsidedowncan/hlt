import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecordingService {
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static bool _isRecording = false;
  static String? _currentRecordingPath;

  // Check if we're on a desktop platform where permissions might not be needed
  static bool get _isDesktopPlatform {
    return !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  }

  static Future<bool> requestMicrophonePermission() async {
    if (_isDesktopPlatform) {
      debugPrint('Desktop platform detected, skipping microphone permission request');
      return true;
    }

    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      // Permission handler not available on this platform
      debugPrint('Permission request not available on this platform: $e');
      return true; // Assume granted on platforms without permission handler
    }
  }

  static Future<bool> hasMicrophonePermission() async {
    if (_isDesktopPlatform) {
      debugPrint('Desktop platform detected, assuming microphone permission granted');
      return true;
    }

    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      // Permission handler not available on this platform
      debugPrint('Permission check not available on this platform: $e');
      return true; // Assume granted on platforms without permission handler
    }
  }

  static Future<String?> startRecording() async {
    try {
      // Try to check permissions, but don't fail if not supported (e.g., Linux desktop)
      try {
        if (!await hasMicrophonePermission()) {
          final granted = await requestMicrophonePermission();
          if (!granted) {
            debugPrint('Microphone permission denied');
            return null;
          }
        }
      } catch (e) {
        // Permission handler not available on this platform (e.g., Linux desktop)
        // Continue anyway - desktop apps often don't need explicit permissions
        debugPrint('Permission check not available on this platform, continuing: $e');
      }

      if (_isRecording) return null;

      final directory = await getTemporaryDirectory();
      final extension = _isDesktopPlatform ? 'wav' : 'm4a';
      final fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${directory.path}/$fileName';

      // Try different encoders based on platform support
      RecordConfig config;
      if (_isDesktopPlatform) {
        // Use WAV for better desktop compatibility
        config = const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        );
      } else {
        // Use AAC for mobile platforms
        config = const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );
      }

      await _audioRecorder.start(config, path: filePath);
      _isRecording = true;
      _currentRecordingPath = filePath;

      debugPrint('Voice recording started successfully: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      // Try to clean up if recording failed to start
      _isRecording = false;
      _currentRecordingPath = null;
      return null;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null && await File(path).exists()) {
        return path;
      }

      return _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
      }

      if (_currentRecordingPath != null && await File(_currentRecordingPath!).exists()) {
        await File(_currentRecordingPath!).delete();
      }

      _currentRecordingPath = null;
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  static bool get isRecording => _isRecording;

  static Future<Duration?> getRecordingDuration(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // For AAC files, we can't easily get duration without additional libraries
      // This is a simplified approach - in production, you might want to use a more robust solution
      final fileSize = await file.length();
      // Rough estimation: AAC at 128kbps, 44100Hz
      final estimatedSeconds = (fileSize * 8) / (128000);
      return Duration(seconds: estimatedSeconds.toInt());
    } catch (e) {
      debugPrint('Error getting recording duration: $e');
      return null;
    }
  }

  static Future<void> dispose() async {
    try {
      if (_isRecording) {
        await cancelRecording();
      }
      await _audioRecorder.dispose();
    } catch (e) {
      debugPrint('Error disposing recorder: $e');
    }
  }
}