import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../models/audio_track_model.dart';
import '../services/audio_track_service.dart';
import '../../paywall/providers/subscription_provider.dart';
import '../../../core/router/app_router.dart';

class AudioListScreen extends StatefulWidget {
  final String? category;
  
  const AudioListScreen({super.key, this.category});

  @override
  State<AudioListScreen> createState() => _AudioListScreenState();
}

class _AudioListScreenState extends State<AudioListScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioTrackModel? _activeAudio;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _stopWholeThing() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _activeAudio = null;
    });
  }

  void _playTrack(AudioTrackModel track) async {
    if (_isLoading) return;

    if (_activeAudio?.id == track.id) {
      try {
        if (_isPlaying) {
          _audioPlayer.pause();
          setState(() => _isPlaying = false);
        } else {
          _audioPlayer.play();
          setState(() => _isPlaying = true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to play/pause audio.')));
      }
      return;
    }

    setState(() {
      _activeAudio = track;
      _isPlaying = true;
      _isLoading = false;
    });

    try {
      final audioSource = AudioSource.uri(Uri.parse(track.audioUrl));
      _audioPlayer.setAudioSource(audioSource);
      _audioPlayer.setLoopMode(track.loop ? LoopMode.one : LoopMode.off);
      _audioPlayer.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeAudio = null;
        _isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load audio. Check your connection.')));
    }
  }

  Widget _buildMiniPlayer() {
    if (_activeAudio == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryIndigo,
            _isPlaying ? const Color(0xFF4F46E5) : AppTheme.primaryIndigo,
          ],
        ),
        boxShadow: _isPlaying
            ? [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                )
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_activeAudio!.title, 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Now Playing', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                ],
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
              )
            else ...[
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 36),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                    setState(() => _isPlaying = false);
                  } else {
                    _audioPlayer.play();
                    setState(() => _isPlaying = true);
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _stopWholeThing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLight = themeProvider.isDarkMode == false;
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final bgColor = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final borderColor = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          widget.category ?? 'Audio Library',
          style: GoogleFonts.outfit(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<AudioTrackModel>>(
            stream: AudioTrackService().getAudioTracks(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
              }

              // Filter by category if provided
              final tracks = widget.category != null 
                  ? (snapshot.data ?? []).where((t) => t.category == widget.category).toList()
                  : snapshot.data ?? [];

              if (tracks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.audiotrack_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No audio tracks available yet.', style: TextStyle(color: textSec, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(20, 16, 20, _activeAudio != null ? 120 : 32),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  // Let's just lock after first 3 for non-premium
                  final isLocked = !isPremium && index >= 3;
                  final isActive = _activeAudio?.id == track.id;

                  return GestureDetector(
                    onTap: () {
                      if (isLocked) {
                        Navigator.pushNamed(context, AppRouter.paywall);
                      } else {
                        _playTrack(track);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? AppTheme.primaryIndigo : borderColor,
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  track.thumbnailUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(track.thumbnailUrl, fit: BoxFit.cover, width: 60, height: 60),
                                        )
                                      : const Center(
                                          child: Icon(Icons.audiotrack_rounded, color: AppTheme.primaryIndigo, size: 28),
                                        ),
                                  if (isLocked)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 24),
                                        ),
                                      ),
                                    )
                                  else if (isActive)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryIndigo.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: _isLoading 
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    style: GoogleFonts.outfit(
                                      color: textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        track.category,
                                        style: TextStyle(color: AppTheme.primaryIndigo, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('•', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Text(
                                        track.duration,
                                        style: TextStyle(color: textSec, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          // Bottom Sticky Player
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMiniPlayer(),
          ),
        ],
      ),
    );
  }
}
