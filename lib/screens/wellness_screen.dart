import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../modules/videos/models/video_model.dart';
import '../modules/videos/services/video_service.dart';
import '../modules/videos/screens/video_list_screen.dart';
import '../modules/videos/screens/video_player_screen.dart';
import '../modules/blogs/models/blog_model.dart';
import '../modules/blogs/services/blog_service.dart';
import '../modules/blogs/screens/blog_list_screen.dart';
import '../modules/blogs/screens/blog_detail_screen.dart';
import '../modules/blogs/widgets/blog_hub_widget.dart';
import '../modules/paywall/providers/subscription_provider.dart';
import '../core/router/app_router.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});
  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  int? _activeTimer;
  int? _activeTrackIndex;
  bool _isPlaying = false;
  bool _isLoading = false;
  Timer? _sleepTimer;
  bool _isTimerActive = false;
  bool _isTimerPaused = false;
  int _timerRemainingSeconds = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['For You', 'Meditation', 'Sleep Sounds', 'Breathwork', 'Music'];

  static const _tracks = [
    _Track('Brown Noise', 'Ambient', '10 Min', Icons.waves, Color(0xFF5D4037), 'https://archive.org/download/WhiteBrownNoise/BrownNoise.ogg', 'Sleep Sounds'),
    _Track('Soft Rain', 'Nature', '15 Min', Icons.water_drop, Color(0xFF4FC3F7), 'https://archive.org/download/RelaxingRainAndLoudThunderFreeFieldRecordingOfNatureSoundsForSleepOrMeditation/soft.ogg', 'Sleep Sounds'),
    _Track('Waterfalls', 'Nature', '20 Min', Icons.pool, Color(0xFF00796B), 'https://archive.org/download/WhiteBrownNoise/VirtualWaterfalls.ogg', 'Sleep Sounds'),
    _Track('Guided Meditation', 'Voices', '10 Min', Icons.self_improvement, Color(0xFF8E24AA), 'https://archive.org/download/swmp167/SWMP167.mp3', 'Meditation'),
    _Track('Calm Piano', 'Music', '30 Min', Icons.music_note, Color(0xFF3949AB), 'https://archive.org/download/DreamlandByMikeHuber/16%20The%20End%20Of%20The%20Day%20Revox.mp3', 'Music'),
    _Track('Instrumental Sleep', 'Music', '45 Min', Icons.spa, Color(0xFF43A047), 'https://archive.org/download/sunflowertracks/sunflowertracks.mp3', 'Music'),
    _Track('Forest Night', 'Nature', '60 Min', Icons.forest, Color(0xFF1B5E20), 'https://archive.org/download/QuietForestNightSoundEffects/Quiet%20Forest%20Night.mp3', 'Sleep Sounds'),
    _Track('Ocean Waves', 'Nature', '15 Min', Icons.waves, Color(0xFF0277BD), 'https://archive.org/download/OceanWaves_447/OceanWaves.mp3', 'Sleep Sounds'),
    _Track('White Noise', 'Ambient', '30 Min', Icons.blur_on, Color(0xFF9E9E9E), 'https://archive.org/download/WhiteNoise10Min/WhiteNoise.mp3', 'Sleep Sounds'),
    _Track('Binaural Beats', 'Healing', '20 Min', Icons.headphones, Color(0xFF512DA8), 'https://archive.org/download/binaural-beats-sleep/binaural.mp3', 'Meditation'),
  ];

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_activeTimer == null) return;
    setState(() {
      _isTimerActive = true;
      if (!_isTimerPaused || _timerRemainingSeconds == 0) {
        _timerRemainingSeconds = _activeTimer! * 60;
      }
      _isTimerPaused = false;
    });

    _sleepTimer?.cancel();
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerRemainingSeconds > 0) {
        setState(() {
          _timerRemainingSeconds--;
        });
      } else {
        _stopWholeThing();
      }
    });
  }

  void _pauseTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _isTimerPaused = true;
    });
  }

  void _stopWholeThing() {
    _sleepTimer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _isTimerActive = false;
      _isTimerPaused = false;
      _isPlaying = false;
      _activeTrackIndex = null;
      _activeTimer = null;
      _timerRemainingSeconds = 0;
    });
  }

  String get _formattedTime {
    final m = _timerRemainingSeconds ~/ 60;
    final s = _timerRemainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _playTrack(int index) async {
    if (_isLoading) return;
    if (_activeTrackIndex == index) {
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
    } else {
      // Show loading immediately — don't await the network fetch
      setState(() {
        _activeTrackIndex = index;
        _isLoading = true;
        _isPlaying = false;
      });

      final snackbarMessenger = ScaffoldMessenger.of(context);
      try {
        // Set URL without awaiting — this returns as soon as buffering starts
        final audioSource = AudioSource.uri(Uri.parse(_tracks[index].url));
        await _audioPlayer.setAudioSource(audioSource);
        _audioPlayer.setLoopMode(LoopMode.one);

        // Listen for when buffering is ready, then play
        _audioPlayer.processingStateStream.firstWhere(
          (s) => s == ProcessingState.ready || s == ProcessingState.completed,
        ).then((_) {
          if (mounted && _activeTrackIndex == index) {
            _audioPlayer.play();
            setState(() {
              _isPlaying = true;
              _isLoading = false;
            });
          }
        });

        // Safety: also clear loading if there's an error
      } catch (e) {
        if (!context.mounted) return;
        setState(() {
          _isLoading = false;
          _activeTrackIndex = null;
        });
        snackbarMessenger.showSnackBar(const SnackBar(content: Text('Failed to load audio. Check your connection.')));
      }
    }
  }

  void _showBreathingExercise(BuildContext context, BreathExercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BreathingExerciseSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLight = themeProvider.isDarkMode == false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wellness Hub',
                          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Find your calm before bed',
                          style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category Chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategoryIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryIndigo : (isLight ? AppTheme.surfaceLight : AppTheme.surface),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryIndigo : (isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _categories[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 150), // space for mini player + timer
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedCategoryIndex == 0) ...[
                          _buildSectionTitle('Recommended for you', isLight),
                          _buildHorizontalList(
                            tracks: [_tracks[3], _tracks[0], _tracks[4]],
                            indices: [3, 0, 4],
                            isLight: isLight,
                            isLarge: true,
                          ),
                          const SizedBox(height: 32),

                          _buildVideoHubSection(isLight),
                          const SizedBox(height: 32),

                          BlogHubWidget(isLight: isLight),
                          const SizedBox(height: 32),
                        ],

                        if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) ...[
                          _buildSectionTitle('Meditation', isLight),
                          _buildHorizontalList(
                            tracks: _tracks.where((t) => t.category == 'Meditation').toList(),
                            indices: _tracks.asMap().entries.where((e) => e.value.category == 'Meditation').map((e) => e.key).toList(),
                            isLight: isLight,
                          ),
                          const SizedBox(height: 32),
                        ],

                        if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) ...[
                          _buildSectionTitle('Sleep Sounds', isLight),
                          _buildHorizontalList(
                            tracks: _tracks.where((t) => t.category == 'Sleep Sounds').toList(),
                            indices: _tracks.asMap().entries.where((e) => e.value.category == 'Sleep Sounds').map((e) => e.key).toList(),
                            isLight: isLight,
                          ),
                          const SizedBox(height: 32),
                        ],

                        
                        if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) ...[
                          _buildSectionTitle('Breathwork', isLight),
                          _buildBreathworkSection(isLight),
                          const SizedBox(height: 32),
                        ],
                        if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 4) ...[
                          _buildSectionTitle('Music', isLight),
                          _buildHorizontalList(
                            tracks: _tracks.where((t) => t.category == 'Music').toList(),
                            indices: _tracks.asMap().entries.where((e) => e.value.category == 'Music').map((e) => e.key).toList(),
                            isLight: isLight,
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Premium Banner
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Unlock Premium', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                      const SizedBox(height: 8),
                                      const Text('Get access to all sleep sounds and guided meditations.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Upgrade', style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Sticky Player & Timer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                children: [
                  if (_activeTrackIndex != null)
                    _buildMiniPlayer(),
                  // _buildSleepTimer(isLight), // Hidden for now
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  // Breathwork exercises data
  static const _breathworkExercises = [
    BreathExercise('4-7-8 Breathing', 'Anxiety Relief', Icons.air, Color(0xFF2DD4BF), '19 Min', '4-7-8'),
    BreathExercise('Box Breathing', 'Focus & Calm', Icons.crop_square_rounded, Color(0xFF818CF8), '10 Min', '4-4-4-4'),
    BreathExercise('Wim Hof', 'Energy Boost', Icons.whatshot_rounded, Color(0xFFF97316), '15 Min', '30x'),
    BreathExercise('Belly Breathing', 'Deep Relax', Icons.self_improvement, Color(0xFF8B5CF6), '12 Min', 'Diaphragm'),
  ];

  Widget _buildBreathworkSection(bool isLight) {
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _breathworkExercises.length,
        itemBuilder: (context, index) {
          final ex = _breathworkExercises[index];
          return GestureDetector(
            onTap: () => _showBreathingExercise(context, ex),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: ex.color.withValues(alpha: isLight ? 0.1 : 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ex.color.withValues(alpha: 0.25)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ex.icon, color: ex.color, size: 40),
                        const SizedBox(height: 10),
                        Text(ex.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(ex.subtitle,
                          style: TextStyle(fontSize: 11, color: textSec),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ex.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ex.duration,
                        style: TextStyle(fontSize: 9, color: ex.color, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isLight) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
            ),
          ),
          if (title != 'Recommended for you')
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('See all $title coming soon!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryIndigo,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoHubSection(bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wellness Videos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoListScreen())),
                child: const Text(
                  'See All',
                  style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: StreamBuilder<List<VideoModel>>(
            stream: VideoService.watchVideos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
              }
              final videos = snapshot.data ?? [];
              if (videos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('No videos available right now.', style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                );
              }
              final displayVideos = videos.take(5).toList();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                itemCount: displayVideos.length,
                itemBuilder: (context, i) {
                  final v = displayVideos[i];
                  final isPremium = context.watch<SubscriptionProvider>().isPremium;
                  final isLocked = !isPremium && i >= 1;

                  return GestureDetector(
                    onTap: () {
                      if (isLocked) {
                        Navigator.pushNamed(context, AppRouter.paywall);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v)));
                      }
                    },
                    child: SizedBox(
                      width: 210,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Full-size immersive thumbnail ──
                          Container(
                            height: 140,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  v.thumbnailUrl.isNotEmpty
                                      ? Image.network(v.thumbnailUrl, fit: BoxFit.cover)
                                      : Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Icon(Icons.play_circle_rounded, color: Colors.white54, size: 48),
                                        ),
                                  // Dark gradient for play button visibility
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black45],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Play / Lock icon
                                  Center(
                                    child: isLocked
                                        ? Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 28),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white54, width: 1.5),
                                            ),
                                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ── Text below thumbnail ──
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 10, 18, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (v.tags.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      v.tags.first,
                                      style: const TextStyle(color: AppTheme.primaryIndigo, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }



  Widget _buildHorizontalList({
    required List<_Track> tracks,
    required List<int> indices,
    required bool isLight,
    bool isLarge = false,
  }) {
    if (tracks.isEmpty) return const SizedBox();

    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return SizedBox(
      height: isLarge ? 200 : 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final globalIndex = indices[index];
          final isActive = _activeTrackIndex == globalIndex;
          final isPremium = context.watch<SubscriptionProvider>().isPremium;
          final isLocked = !isPremium && globalIndex >= 5;

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                Navigator.pushNamed(context, AppRouter.paywall);
              } else {
                _playTrack(globalIndex);
              }
            },
            child: Container(
              width: isLarge ? 200 : 140,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: track.color.withValues(alpha: isLight ? 0.10 : 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? AppTheme.primaryIndigo
                      : track.color.withValues(alpha: 0.25),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: track.color.withValues(alpha: isLight ? 0.18 : 0.25),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Center icon + title + subtitle
                  Center(
                    child: Opacity(
                      opacity: isLocked ? 0.4 : 1.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(track.icon, color: track.color, size: isLarge ? 48 : 40),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              track.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: isLarge ? 15 : 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(track.artist, style: TextStyle(fontSize: 11, color: textSec)),
                        ],
                      ),
                    ),
                  ),
                  
                  if (isLocked)
                    const Positioned.fill(
                      child: Center(
                        child: Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 28),
                      ),
                    ),
                  // Duration badge — top right (same as Breathwork)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: track.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        track.duration,
                        style: TextStyle(
                          fontSize: 9,
                          color: track.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Active play/pause overlay
                  if (isActive)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white,
                                size: 48,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryIndigo,
        border: Border(
          top: BorderSide(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder).withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _tracks[_activeTrackIndex!].color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_tracks[_activeTrackIndex!].icon, color: _tracks[_activeTrackIndex!].color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tracks[_activeTrackIndex!].title, 
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
    );
  }

  Widget _buildSleepTimer(bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
        border: Border(top: BorderSide(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('⏱️ Sleep Timer',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
              if (_isTimerActive) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4)),
                  ),
                  child: Text(_formattedTime, style: const TextStyle(fontSize: 11, color: AppTheme.accentTeal, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [15, 30, 45, 60].map((t) {
              final active = _activeTimer == t;
              return Expanded(
                child: GestureDetector(
                  onTap: (_isTimerActive || _isTimerPaused) ? null : () => setState(() => _activeTimer = active ? null : t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.accentTeal.withValues(alpha: 0.15) : (isLight ? Colors.black.withValues(alpha: 0.02) : AppTheme.background.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppTheme.accentTeal : (isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder)),
                    ),
                    child: Center(
                      child: Text('${t}m',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: active ? AppTheme.accentTeal : (isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                          )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_activeTimer != null || _isTimerActive || _isPlaying || _isTimerPaused) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_activeTimer != null)
                  Expanded(
                    child: _isTimerActive && !_isTimerPaused
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.2),
                            foregroundColor: AppTheme.accentTeal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _pauseTimer,
                          icon: const Icon(Icons.pause, size: 20),
                          label: const Text('Pause', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _startTimer,
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: Text(_isTimerPaused ? 'Resume' : 'Start', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                  ),
                if (_activeTimer != null && (_isTimerActive || _isPlaying || _isTimerPaused))
                  const SizedBox(width: 12),
                if (_isTimerActive || _isPlaying || _isTimerPaused)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _stopWholeThing,
                      icon: const Icon(Icons.power_settings_new, size: 20),
                      label: const Text('Turn Off', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

class _Track {
  final String title;
  final String artist;
  final String duration;
  final IconData icon;
  final Color color;
  final String url;
  final String category;

  const _Track(this.title, this.artist, this.duration, this.icon, this.color, this.url, this.category);
}


class BreathingExerciseSheet extends StatefulWidget {
  final BreathExercise exercise;
  const BreathingExerciseSheet({super.key, required this.exercise});

  @override
  State<BreathingExerciseSheet> createState() => _BreathingExerciseSheetState();
}

class _BreathingExerciseSheetState extends State<BreathingExerciseSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _instruction = 'Get Ready';
  String _timerText = '';
  
  // Pattern segments: [inhale, hold1, exhale, hold2]
  late List<int> _segments;
  late int _totalDuration;

  @override
  void initState() {
    super.initState();
    _parsePattern();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: _totalDuration));
    
    _controller.addListener(() {
      if (!mounted) return;
      final t = _controller.value * _totalDuration;
      
      int inhaleEnd = _segments[0];
      int hold1End = inhaleEnd + _segments[1];
      int exhaleEnd = hold1End + _segments[2];
      int hold2End = exhaleEnd + _segments[3];

      if (t <= inhaleEnd) {
        setState(() {
          _instruction = 'Inhale';
          _timerText = (inhaleEnd - t.floor()).toString();
        });
      } else if (t <= hold1End) {
        setState(() {
          _instruction = 'Hold';
          _timerText = (hold1End - t.floor()).toString();
        });
      } else if (t <= exhaleEnd) {
        setState(() {
          _instruction = 'Exhale';
          _timerText = (exhaleEnd - t.floor()).toString();
        });
      } else {
        setState(() {
          _instruction = 'Hold';
          _timerText = (hold2End - t.floor()).toString();
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) _controller.repeat();
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _controller.forward();
    });
  }

  void _parsePattern() {
    switch (widget.exercise.pattern) {
      case '4-7-8':
        _segments = [4, 7, 8, 0];
        break;
      case '4-4-4-4':
        _segments = [4, 4, 4, 4];
        break;
      case '30x': // quick inhales
        _segments = [2, 0, 2, 0];
        break;
      case 'Diaphragm':
        _segments = [4, 0, 6, 0];
        break;
      default:
        _segments = [4, 7, 8, 0];
    }
    _totalDuration = _segments.reduce((a, b) => a + b);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isLight ? AppTheme.backgroundLight : AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.exercise.name, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
          const SizedBox(height: 60),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value * _totalDuration;
              double scale = 1.0;
              
              int inhaleEnd = _segments[0];
              int hold1End = inhaleEnd + _segments[1];
              int exhaleEnd = hold1End + _segments[2];

              if (t <= inhaleEnd) {
                scale = inhaleEnd > 0 ? 1.0 + (t / inhaleEnd) * 0.5 : 1.5; // grows to 1.5
              } else if (t <= hold1End) {
                scale = 1.5; // holds
              } else if (t <= exhaleEnd) {
                scale = _segments[2] > 0 ? 1.5 - ((t - hold1End) / _segments[2]) * 0.5 : 1.0; // shrinks to 1.0
              } else {
                scale = 1.0; // holds
              }
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.exercise.color.withValues(alpha: 0.2),
                    border: Border.all(color: widget.exercise.color, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_instruction, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
                        Text(_timerText, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: widget.exercise.color)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Stop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class BreathExercise {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String duration;
  final String pattern;
  const BreathExercise(this.name, this.subtitle, this.icon, this.color, this.duration, this.pattern);
}
