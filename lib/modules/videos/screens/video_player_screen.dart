import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  final List<VideoModel>? playlist;
  final int? startIndex;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.playlist,
    this.startIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController _pageController;
  late List<VideoModel> _videos;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _videos = widget.playlist ?? [widget.video];
    _currentIndex = widget.startIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _VideoPage(
                video: _videos[index],
                isActive: _currentIndex == index,
              );
            },
          ),
          // Back Button (top-left)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                  // Shuffle button
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 26),
                    tooltip: 'Shuffle',
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                    onPressed: () {
                      final shuffled = List<VideoModel>.from(_videos)..shuffle();
                      setState(() {
                        _videos = shuffled;
                        _currentIndex = 0;
                      });
                      _pageController.jumpToPage(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔀 Playlist shuffled!'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.primaryIndigo,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Swipe-up hint (shown when more videos exist)
          if (_videos.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white.withValues(alpha: 0.6), size: 28),
                  Text(
                    'Swipe up for next',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final VideoModel video;
  final bool isActive;

  const _VideoPage({required this.video, required this.isActive});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.addListener(_onVideoUpdate);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isActive) {
          _controller.play();
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isActive && !oldWidget.isActive) {
        _controller.play();
      } else if (!widget.isActive && oldWidget.isActive) {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 40, left: 12, right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
          // Video Layer
          if (_isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else if (_hasError)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                  SizedBox(height: 12),
                  Text('Failed to load video', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            )
          else
            Stack(
              fit: StackFit.expand,
              children: [
                if (widget.video.thumbnailUrl.isNotEmpty)
                  Image.network(widget.video.thumbnailUrl, fit: BoxFit.cover),
                Container(color: Colors.black45),
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo)),
              ],
            ),

          // Play/Pause Icon overlay (transient)
          if (_isInitialized && !_controller.value.isPlaying)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 80),
              ),
            ),

          if (_isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white70)),

          // Gradient overlay for text readability
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Content overlay (Text on left, buttons on right)
          Positioned(
            left: 16,
            right: 16,
            bottom: 30, // Above progress bar
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left side details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.video.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.video.tags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: widget.video.tags.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right side action buttons
                _buildActionButtons(),
              ],
            ),
          ),

          // Progress Bar
          if (_isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.primaryIndigo,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
      ),
    ))));
  }

  Widget _buildActionButtons() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<VideoModel>>(
      stream: VideoService.watchVideos(),
      builder: (context, snapshot) {
        final videos = snapshot.data ?? [];
        final currentVideo = videos.firstWhere((v) => v.id == widget.video.id, orElse: () => widget.video);
        
        final isLiked = uid != null && currentVideo.likes.contains(uid);
        final isUseful = uid != null && currentVideo.useful.contains(uid);
        final likesCount = currentVideo.likes.length;
        final usefulCount = currentVideo.useful.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(
              icon: isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              label: _formatCount(likesCount),
              color: isLiked ? Colors.redAccent : Colors.white,
              onTap: () => VideoService.toggleReaction(currentVideo.id, 'likes'),
            ),
            const SizedBox(height: 20),
            _actionButton(
              icon: isUseful ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              label: _formatCount(usefulCount),
              color: isUseful ? AppTheme.primaryGold : Colors.white,
              onTap: () => VideoService.toggleReaction(currentVideo.id, 'useful'),
            ),
            const SizedBox(height: 20),
            _actionButton(
              icon: Icons.share_rounded,
              label: 'Share',
              color: Colors.white,
              onTap: () {
                final text = "Check out this wellness video on SnoreClinics!\n\n"
                    "${currentVideo.title}\n"
                    "Watch here: https://snoreclinics.com/video?id=${currentVideo.id}";
                Share.share(text);
              },
            ),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
