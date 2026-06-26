import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );
      await _controller.initialize();
      _controller.addListener(_onVideoUpdate);
      setState(() {
        _isInitialized = true;
        _duration = _controller.value.duration;
      });
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    setState(() {
      _position = _controller.value.position;
      if (_controller.value.duration != _duration) {
        _duration = _controller.value.duration;
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
    _autoHideControls();
  }

  void _stopVideo() {
    setState(() {
      _controller.seekTo(Duration.zero);
      _controller.pause();
      _showControls = true;
    });
  }

  void _autoHideControls() {
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Video Player ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: AspectRatio(
              aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isInitialized)
                    VideoPlayer(_controller)
                  else if (_hasError)
                    const Center(
                      child: Icon(Icons.error_outline,
                          color: AppTheme.error, size: 48),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
                    ),

                  // Controls overlay
                  if (_isInitialized && _showControls)
                    _ControlsOverlay(
                      controller: _controller,
                      position: _position,
                      duration: _duration,
                      onTogglePlay: _togglePlayPause,
                      onStop: _stopVideo,
                      onBack: () => Navigator.pop(context),
                      formatFn: _format,
                    ),
                ],
              ),
            ),
          ),

          // ── Description Panel ────────────────────────────────────────
          Expanded(
            child: Container(
              color: AppTheme.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.video.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Reactions and Share
                    _buildReactionRow(),
                    const SizedBox(height: 16),

                    // Tags
                    if (widget.video.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: widget.video.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          AppTheme.primaryIndigo.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    color: AppTheme.primaryIndigo,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 20),

                    // Divider
                    Container(
                      height: 1,
                      color: AppTheme.cardBorder,
                    ),
                    const SizedBox(height: 20),

                    // Description
                    const Text(
                      'About this video',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.video.description,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionRow() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // We would ideally listen to a stream for real-time updates, but for simplicity we rely on local state or the initial video object.
    // Let's wrap this in a StreamBuilder to get real-time reaction counts.
    return StreamBuilder<List<VideoModel>>(
      stream: VideoService.watchVideos(),
      builder: (context, snapshot) {
        final videos = snapshot.data ?? [];
        final currentVideo = videos.firstWhere((v) => v.id == widget.video.id, orElse: () => widget.video);
        
        final isLiked = uid != null && currentVideo.likes.contains(uid);
        final isUseful = uid != null && currentVideo.useful.contains(uid);
        final likesCount = currentVideo.likes.length;
        final usefulCount = currentVideo.useful.length;

        return Row(
          children: [
            _reactionButton(
              icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              label: likesCount > 0 ? '$likesCount' : 'Like',
              isActive: isLiked,
              onTap: () => VideoService.toggleReaction(currentVideo.id, 'likes'),
            ),
            const SizedBox(width: 12),
            _reactionButton(
              icon: isUseful ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              label: usefulCount > 0 ? '$usefulCount' : 'Useful',
              isActive: isUseful,
              onTap: () => VideoService.toggleReaction(currentVideo.id, 'useful'),
            ),
            const Spacer(),
            _reactionButton(
              icon: Icons.share_rounded,
              label: 'Share',
              isActive: false,
              onTap: () {
                final text = "Check out this wellness video on SnoreClinics!\n\n"
                    "${currentVideo.title}\n"
                    "Watch here: https://snoreclinics.com/video?id=${currentVideo.id}\n\n"
                    "Don't have the app? Install it to improve your sleep health today!";
                Share.share(text);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _reactionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryIndigo.withValues(alpha: 0.15) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryIndigo.withValues(alpha: 0.5) : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? AppTheme.primaryIndigo : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Controls Overlay ──────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final Duration position;
  final Duration duration;
  final VoidCallback onTogglePlay;
  final VoidCallback onStop;
  final VoidCallback onBack;
  final String Function(Duration) formatFn;

  const _ControlsOverlay({
    required this.controller,
    required this.position,
    required this.duration,
    required this.onTogglePlay,
    required this.onStop,
    required this.onBack,
    required this.formatFn,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      color: Colors.black45,
      child: Column(
        children: [
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 22),
                    onPressed: onBack,
                  ),
                ],
              ),
            ),
          ),
          // Center controls
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onStop,
                    child: const Icon(
                      Icons.stop_circle_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: onTogglePlay,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        key: ValueKey(controller.value.isPlaying),
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Seek bar + time
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppTheme.primaryIndigo,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: AppTheme.primaryIndigo.withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      final target = Duration(
                        milliseconds:
                            (v * duration.inMilliseconds).round(),
                      );
                      controller.seekTo(target);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatFn(position),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    Text(formatFn(duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
