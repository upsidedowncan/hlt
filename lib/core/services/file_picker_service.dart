import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class FilePickerService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android API 30+, use photos permission for images
      // For older versions, use storage permission
      final sdkInt = await _getAndroidSdkVersion();
      if (sdkInt >= 30) {
        // Android 11+ (API 30+)
        final photosStatus = await Permission.photos.request();
        final videosStatus = await Permission.videos.request();
        return photosStatus.isGranted && videosStatus.isGranted;
      } else {
        // Android 10 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // iOS doesn't need explicit storage permission for file picker
  }

  static Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkVersion();
      if (sdkInt >= 30) {
        // Android 11+ (API 30+)
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        return photosStatus.isGranted && videosStatus.isGranted;
      } else {
        // Android 10 and below
        final status = await Permission.storage.status;
        return status.isGranted;
      }
    }
    return true;
  }

  static Future<int> _getAndroidSdkVersion() async {
    // This is a simplified way - in a real app you'd use device_info_plus
    // For now, we'll assume Android 11+ for testing
    return 30; // Assume Android 11+ for proper permission handling
  }



  static Future<FilePickerResult?> pickImage() async {
    return await pickFile(type: FileType.image);
  }

  static Future<FilePickerResult?> pickDocument() async {
    return await pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
  }

  static Future<FilePickerResult?> pickMedia() async {
    return await pickFile(type: FileType.media);
  }

  static Future<FilePickerResult?> pickFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
    bool allowMultiple = false,
  }) async {
    try {
      debugPrint('Checking storage permission...');
      if (!await hasStoragePermission()) {
        debugPrint('Requesting storage permission...');
        final granted = await requestStoragePermission();
        debugPrint('Permission granted: $granted');
        if (!granted) return null;
      }

      debugPrint('Launching file picker with type: $type');
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: false, // We'll read the file separately
        withReadStream: false,
      );
      debugPrint('File picker returned: $result');

      return result;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  static Future<FilePickerResult?> pickAnyFile() async {
    return await pickFile(type: FileType.any);
  }

  static String getFileTypeFromPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
        return 'audio';
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'document';
      case 'txt':
        return 'text';
      default:
        return 'file';
    }
  }

  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static bool isValidFileSize(File file, {int maxSizeInMB = 10}) {
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return file.lengthSync() <= maxSizeInBytes;
  }
}