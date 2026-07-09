import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SnoreAudioPlayer extends StatefulWidget {
  final String? audioUrl;
  final String? localPath;
  final DateTime? recordedTime;

  const SnoreAudioPlayer({
    super.key,
    this.audioUrl,
    this.localPath,
    this.recordedTime,
  });

  @override
  State<SnoreAudioPlayer> createState() => _SnoreAudioPlayerState();
}

class _SnoreAudioPlayerState extends State<SnoreAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoaded = false;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.localPath != null && File(widget.localPath!).existsSync()) {
        final duration = await _player.setFilePath(widget.localPath!);
        setState(() {
          _duration = duration ?? Duration.zero;
          _isLoaded = true;
        });
      } else if (widget.audioUrl != null) {
        final duration = await _player.setUrl(widget.audioUrl!);
        setState(() {
          _duration = duration ?? Duration.zero;
          _isLoaded = true;
        });
      } else {
        setState(() {
          _hasError = true;
        });
        return;
      }

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _player.seek(Duration.zero);
              _player.pause();
            }
          });
        }
      });

      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading snore audio: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _formatDuration(Duration d) {
    String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink(); // Hide if no audio or error
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Colors.indigoAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Snore Recording',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (widget.recordedTime != null)
                  Text(
                    TimeOfDay.fromDateTime(widget.recordedTime!).format(context),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isLoaded)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: Colors.indigoAccent,
                    ),
                    onPressed: _togglePlay,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Slider(
                          value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                          min: 0.0,
                          max: _duration.inMilliseconds.toDouble(),
                          onChanged: (value) {
                            _player.seek(Duration(milliseconds: value.toInt()));
                          },
                          activeColor: Colors.indigoAccent,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position), style: const TextStyle(fontSize: 12)),
                            Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              'Note: Snore audio highlights are automatically deleted after 7 days to save space.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
