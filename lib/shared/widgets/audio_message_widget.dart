import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final bool isFromMe;
  final DateTime timestamp;

  const AudioMessageWidget({
    super.key,
    required this.audioUrl,
    required this.isFromMe,
    required this.timestamp,
  });

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudioPlayer() async {
    try {
      setState(() => _isLoading = true);

      // Handle both local files and remote URLs
      if (widget.audioUrl.startsWith('http')) {
        await _audioPlayer.setSourceUrl(widget.audioUrl);
      } else {
        // Local file
        final file = File(widget.audioUrl);
        if (await file.exists()) {
          await _audioPlayer.setSourceDeviceFile(widget.audioUrl);
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
          return;
        }
      }

      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration);
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            _isLoading = false;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });

      // Pre-load the audio by briefly starting and stopping playback
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setPlaybackRate(1.0);

      // Trigger audio loading by starting and immediately pausing
      try {
        await _audioPlayer.resume();
        await Future.delayed(const Duration(milliseconds: 100));
        await _audioPlayer.pause();
      } catch (e) {
        // If resume/pause fails, that's okay - the audio might still work
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_hasError || _isLoading) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        MouseRegion(
          cursor: _hasError ? MouseCursor.defer : SystemMouseCursors.click,
          child: InkWell(
            onTap: _hasError ? null : _togglePlayback,
            borderRadius: BorderRadius.circular(18),
            splashColor: widget.isFromMe
                ? theme.colorScheme.onPrimary.withValues(alpha: 0.3)
                : theme.colorScheme.primary.withValues(alpha: 0.3),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isFromMe
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _hasError
                  ? Icon(
                      Icons.error,
                      size: 18,
                      color: widget.isFromMe
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                    )
                  : _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isFromMe
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 18,
                          color: widget.isFromMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                        ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Progress bar and duration
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
               // Progress bar
               SliderTheme(
                 data: SliderThemeData(
                   trackHeight: 3,
                   thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                   overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                   activeTrackColor: widget.isFromMe
                       ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                       : theme.colorScheme.primary,
                   inactiveTrackColor: widget.isFromMe
                       ? theme.colorScheme.onPrimary.withValues(alpha: 0.3)
                       : theme.colorScheme.outline.withValues(alpha: 0.3),
                   thumbColor: widget.isFromMe
                       ? theme.colorScheme.onPrimary
                       : theme.colorScheme.primary,
                   overlayColor: widget.isFromMe
                       ? theme.colorScheme.onPrimary.withValues(alpha: 0.2)
                       : theme.colorScheme.primary.withValues(alpha: 0.2),
                 ),
                 child: Slider(
                   value: _duration.inSeconds > 0
                       ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                       : 0.0,
                   max: 1.0,
                   onChanged: _duration.inSeconds > 0 && !_hasError
                       ? (value) async {
                           final position = Duration(
                             seconds: (value * _duration.inSeconds).round(),
                           );
                           await _audioPlayer.seek(position);
                         }
                       : null,
                 ),
               ),

              // Time display
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isFromMe
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}