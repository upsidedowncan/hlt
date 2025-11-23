import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/message.dart';
import '../../shared/repositories/message_service.dart';

class FileUploadService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<String?> uploadFile(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();

      final response = await _client.storage
          .from('messages')
          .uploadBinary(fileName, bytes);

      if (response.isNotEmpty) {
        return _client.storage
            .from('messages')
            .getPublicUrl(fileName);
      }

      return null;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  static Future<Message?> sendFileMessage({
    required String conversationId,
    required File file,
    required String fileName,
    required MessageType messageType,
  }) async {
    try {
      final fileUrl = await uploadFile(file, fileName);

      if (fileUrl != null) {
        return await MessageService.sendMessage(
          conversationId: conversationId,
          content: fileUrl,
          type: messageType,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error sending file message: $e');
      return null;
    }
  }

  static Future<Message?> sendImageMessage({
    required String conversationId,
    required File imageFile,
  }) async {
    final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
    return await sendFileMessage(
      conversationId: conversationId,
      file: imageFile,
      fileName: fileName,
      messageType: MessageType.image,
    );
  }

  static Future<Message?> sendDocumentMessage({
    required String conversationId,
    required File documentFile,
  }) async {
    final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}_${documentFile.path.split('/').last}';
    return await sendFileMessage(
      conversationId: conversationId,
      file: documentFile,
      fileName: fileName,
      messageType: MessageType.file,
    );
  }

  static Future<Message?> sendVideoMessage({
    required String conversationId,
    required File videoFile,
  }) async {
    final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}_${videoFile.path.split('/').last}';
    return await sendFileMessage(
      conversationId: conversationId,
      file: videoFile,
      fileName: fileName,
      messageType: MessageType.video,
    );
  }

  static Future<Message?> sendAudioMessage({
    required String conversationId,
    required File audioFile,
  }) async {
    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}_${audioFile.path.split('/').last}';
    return await sendFileMessage(
      conversationId: conversationId,
      file: audioFile,
      fileName: fileName,
      messageType: MessageType.audio,
    );
  }

  static String generateFileName(String originalPath, String prefix) {
    final extension = originalPath.split('.').last;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }
}