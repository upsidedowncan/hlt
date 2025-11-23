import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/file_picker_service.dart';
import 'audio_message_widget.dart';

class FileMessageWidget extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final bool isFromMe;
  final DateTime timestamp;

  const FileMessageWidget({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.isFromMe,
    required this.timestamp,
  });

  String get _fileType => FilePickerService.getFileTypeFromPath(fileName);

  IconData get _fileIcon {
    switch (_fileType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'text':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (_fileType) {
      case 'image':
        return Colors.blue;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.purple;
      case 'pdf':
        return Colors.red.shade700;
      case 'document':
        return Colors.blue.shade700;
      case 'text':
        return Colors.green;
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  Widget _buildImagePreview(BuildContext context) {
    final heroTag = 'image_${fileUrl.hashCode}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFullScreenImage(context, heroTag),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
              maxHeight: 200,
            ),
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: fileUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String heroTag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenImageViewer(
          imageUrl: fileUrl,
          heroTag: heroTag,
          fileName: fileName,
        ),
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getFileIconColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _fileIcon,
              color: _getFileIconColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _fileType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
           IconButton(
             onPressed: () async {
               try {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Downloading...')),
                 );

                 final response = await http.get(Uri.parse(fileUrl));
                 if (response.statusCode == 200) {
                   final directory = await getApplicationDocumentsDirectory();
                   final fileName = this.fileName.isNotEmpty ? this.fileName : 'downloaded_file';
                   final file = File('${directory.path}/$fileName');
                   await file.writeAsBytes(response.bodyBytes);

                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('File downloaded to ${file.path}')),
                   );
                 } else {
                   throw Exception('Failed to download');
                 }
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Failed to download file')),
                 );
               }
             },
             icon: Icon(
               Icons.download,
               color: Theme.of(context).colorScheme.primary,
             ),
             tooltip: 'Download file',
           ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fileType == 'image') return _buildImagePreview(context);
    if (_fileType == 'audio') return AudioMessageWidget(audioUrl: fileUrl, isFromMe: isFromMe, timestamp: timestamp);
    return _buildFilePreview(context);
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String fileName;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.fileName,
  });

  Future<void> _downloadImage(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = this.fileName.isNotEmpty ? this.fileName : 'downloaded_image.jpg';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image downloaded to ${file.path}')),
        );
      } else {
        throw Exception('Failed to download');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadImage(context),
            tooltip: 'Download image',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black,
          child: Center(
            child: Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}