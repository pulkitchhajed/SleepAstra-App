import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../core/utils/audio_tracks.dart';
import '../modules/videos/models/video_model.dart';
import '../modules/videos/services/video_service.dart';
import '../modules/videos/screens/video_list_screen.dart';
import '../modules/videos/screens/video_player_screen.dart';
import '../modules/blogs/widgets/blog_hub_widget.dart';
import '../modules/paywall/providers/subscription_provider.dart';
import '../core/router/app_router.dart';
import '../modules/audio/models/audio_track_model.dart';
import '../modules/audio/services/audio_track_service.dart';
import '../modules/blogs/models/blog_model.dart';
import '../modules/admin/models/wellness_zone_model.dart';
import '../modules/admin/services/wellness_zone_service.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});
  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  AudioTrackModel? _activeAudio;
  bool _isPlaying = false;
  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _selectedCategoryIndex = 0;
  List<String> get _categories => ['All Zones', ..._zones.map((z) => z.name)];

  List<WellnessZoneModel> _zones = [];
  StreamSubscription? _zonesSub;

  @override
  void initState() {
    super.initState();
    _zonesSub = WellnessZoneService.watchZones().listen((zones) {
      if (mounted) setState(() => _zones = zones);
    });
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
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

    final snackbarMessenger = ScaffoldMessenger.of(context);
    try {
      final audioSource = AudioSource.uri(Uri.parse(track.audioUrl));
      _audioPlayer.setAudioSource(audioSource);
      _audioPlayer.setLoopMode(track.loop ? LoopMode.one : LoopMode.off);
      _audioPlayer.play();
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _activeAudio = null;
        _isPlaying = false;
      });
      snackbarMessenger.showSnackBar(const SnackBar(content: Text('Failed to load audio. Check your connection.')));
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
    final isPremium = context.watch<SubscriptionProvider>().isPremium;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(isLight).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08, end: 0, curve: Curves.easeOut),
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
                            gradient: isSelected ? const LinearGradient(colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)]) : null,
                            color: !isSelected ? (isLight ? AppTheme.surfaceLight : AppTheme.surface) : null,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : (isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(color: AppTheme.primaryIndigo.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
                            ] : null,
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
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedCategoryIndex == 0) ...[
                          BlogHubWidget(isLight: isLight).animate().fadeIn(delay: 150.ms, duration: 350.ms),
                          const SizedBox(height: 32),

                          // ── Dynamic Zones from Admin ─────────────────────
                          ..._zones.map((zone) => _buildDynamicZoneSection(zone, isLight)).toList(),
                        ] else if (_selectedCategoryIndex > 0 && _selectedCategoryIndex - 1 < _zones.length) ...[
                           _buildDynamicZoneSection(_zones[_selectedCategoryIndex - 1], isLight),
                        ],

                        // Premium Banner
                        if (!isPremium)
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
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryIndigo.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
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
                        ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
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
                  if (_activeAudio != null)
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

  
  // ── Header Widget ────────────────────────────────────────────────────────
  Widget _buildHeader(bool isLight) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: isLight ? 0.6 : 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.5),
        child: AspectRatio(
          aspectRatio: 3.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/wellness_hub_banner.png',
                fit: BoxFit.cover,
              ),
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.spa_rounded, color: Color(0xFF8B5CF6), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Wellness Hub',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E1B4B),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        'Your guide to a calmer, healthier you',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isLight ? const Color(0xFF1E1B4B) : const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                boxShadow: [
                  BoxShadow(
                    color: ex.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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

  Widget _buildSectionTitle(String title, bool isLight, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (title != 'Recommended for you')
            GestureDetector(
              onTap: onSeeAll ?? () {
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
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryIndigo.withValues(alpha: 0.15), const Color(0xFF818CF8).withValues(alpha: 0.15)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.2)),
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
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTheme.primaryIndigo, AppTheme.accentTeal],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Wellness Videos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoListScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryIndigo.withValues(alpha: 0.15), const Color(0xFF818CF8).withValues(alpha: 0.15)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 295,
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
              final allVideos = List<VideoModel>.from(videos)..shuffle();
              final displayVideos = allVideos.take(5).toList();
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
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            video: v,
                            playlist: allVideos,
                            startIndex: allVideos.indexOf(v),
                          ),
                        ));
                      }
                    },
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Full-size immersive thumbnail ──
                          Container(
                            height: 210,
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
                                      ? Image.network(v.thumbnailUrl, fit: BoxFit.cover, cacheWidth: 400)
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



  // ── Mock Yoga Sessions ────────────────────────────────────────────────────
  static const _yogaSessions = [
    _YogaSession('Morning Flow', 'Energising', '20 Min', 'Beginner', Color(0xFF2DD4BF), Icons.wb_sunny_rounded),
    _YogaSession('Bedtime Stretch', 'Wind Down', '15 Min', 'All Levels', Color(0xFF818CF8), Icons.bedtime_rounded),
    _YogaSession('Stress Relief', 'Restorative', '30 Min', 'Intermediate', Color(0xFF8B5CF6), Icons.favorite_rounded),
    _YogaSession('Breathwork Yoga', 'Pranayama', '25 Min', 'Advanced', Color(0xFFF97316), Icons.air_rounded),
    _YogaSession('Yoga Nidra', 'Deep Sleep', '40 Min', 'All Levels', Color(0xFF6366F1), Icons.hotel_rounded),
  ];

  // ── Dynamic Zone Section (Admin-created) ─────────────────────────────────
  Widget _buildDynamicZoneSection(WellnessZoneModel zone, bool isLight) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchZoneItems(zone),
      builder: (context, snapshot) {
        // While loading, show nothing (no empty placeholder)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data ?? [];
        // If zone has no content, hide it entirely — it will never appear
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              zone.name,
              isLight,
              onSeeAll: () {
                if (zone.contentTypes.contains('video')) {
                  Navigator.pushNamed(context, AppRouter.videoLibrary);
                } else if (zone.contentTypes.contains('audio')) {
                  Navigator.pushNamed(context, AppRouter.audioLibrary, arguments: zone.name);
                } else if (zone.contentTypes.contains('blog')) {
                  // If we had a router for BlogListScreen, we'd use it here.
                  // For now, videoLibrary is the main entry for Admin access.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Blog Hub coming soon')),
                  );
                } else {
                  Navigator.pushNamed(context, AppRouter.videoLibrary);
                }
              },
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            SizedBox(
              height: 295,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final type = item['type'] as String;
                  final title = item['title'] as String;
                  final thumbnailUrl = item['thumbnailUrl'] as String? ?? '';
                  final Color accentColor = type == 'video'
                      ? const Color(0xFF6366F1)
                      : type == 'blog'
                          ? const Color(0xFF2DD4BF)
                          : const Color(0xFF8B5CF6);
                  final IconData typeIcon = type == 'video'
                      ? Icons.play_circle_rounded
                      : type == 'blog'
                          ? Icons.article_rounded
                          : Icons.audiotrack_rounded;

                  return GestureDetector(
                    onTap: () {
                      if (type == 'video' && item['data'] is VideoModel) {
                        // Build playlist from all video items in this zone
                        final zoneVideos = items
                            .where((it) => it['type'] == 'video' && it['data'] is VideoModel)
                            .map((it) => it['data'] as VideoModel)
                            .toList()
                            ..shuffle();
                        final tappedVideo = item['data'] as VideoModel;
                        final startIdx = zoneVideos.indexWhere((v) => v.id == tappedVideo.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => VideoPlayerScreen(
                            video: tappedVideo,
                            playlist: zoneVideos,
                            startIndex: startIdx < 0 ? 0 : startIdx,
                          )),
                        );
                      } else if (type == 'audio' && item['data'] is AudioTrackModel) {
                        final tappedAudio = item['data'] as AudioTrackModel;
                        _playTrack(tappedAudio);
                      }
                    },
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Thumbnail ──
                          Container(
                            height: 210,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  thumbnailUrl.isNotEmpty
                                      ? Image.network(thumbnailUrl, fit: BoxFit.cover, cacheWidth: 400)
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.15),
                                          ),
                                          child: Icon(typeIcon, color: accentColor, size: 40),
                                        ),
                                  // Gradient overlay
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
                                  // Play / type icon
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white54, width: 1.5),
                                      ),
                                      child: Icon(typeIcon, color: Colors.white, size: 26),
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
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    type.toUpperCase(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 350.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchZoneItems(WellnessZoneModel zone) async {
    final List<Map<String, dynamic>> results = [];
    final db = FirebaseFirestore.instance;

    if (zone.contentTypes.contains('video')) {
      try {
        final snap = await db.collection('videos').where('category', isEqualTo: zone.name).limit(10).get();
        for (final doc in snap.docs) {
          final model = VideoModel.fromJson(doc.id, doc.data());
          results.add({'type': 'video', 'title': model.title, 'thumbnailUrl': model.thumbnailUrl, 'data': model});
        }
      } catch (_) {}
    }

    if (zone.contentTypes.contains('audio')) {
      try {
        final snap = await db.collection('audio_tracks').where('category', isEqualTo: zone.name).limit(10).get();
        for (final doc in snap.docs) {
          final model = AudioTrackModel.fromJson(doc.id, doc.data());
          results.add({'type': 'audio', 'title': model.title, 'thumbnailUrl': model.thumbnailUrl, 'data': model});
        }
      } catch (_) {}
    }

    if (zone.contentTypes.contains('blog')) {
      try {
        final snap = await db.collection('blogs').where('category', isEqualTo: zone.name).limit(10).get();
        for (final doc in snap.docs) {
          final model = BlogModel.fromJson(doc.id, doc.data());
          results.add({'type': 'blog', 'title': model.title, 'thumbnailUrl': model.coverImageUrl, 'data': model});
        }
      } catch (_) {}
    }

    return results;
  }

  Widget _buildYogaSection(bool isLight) {
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _yogaSessions.length,
        itemBuilder: (context, index) {
          final session = _yogaSessions[index];
          final isLocked = index >= 2 && !(context.watch<SubscriptionProvider>().isPremium);

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                Navigator.pushNamed(context, AppRouter.paywall);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Starting: ${session.title}'),
                    backgroundColor: session.color,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              width: 155,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    session.color.withValues(alpha: isLight ? 0.15 : 0.25),
                    session.color.withValues(alpha: isLight ? 0.05 : 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: session.color.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: session.color.withValues(alpha: isLight ? 0.15 : 0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon in circle
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: session.color.withValues(alpha: isLight ? 0.2 : 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(session.icon, color: session.color, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          session.title,
                          maxLines: 2,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.subtitle,
                          style: TextStyle(fontSize: 11, color: textSec),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: session.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                session.level,
                                style: TextStyle(fontSize: 9, color: session.color, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Duration badge top-right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: session.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.duration,
                        style: TextStyle(fontSize: 9, color: session.color, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  // Lock overlay
                  if (isLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 28),
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
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryIndigo,
            _isPlaying ? const Color(0xFF4F46E5) : AppTheme.primaryIndigo,
          ],
        ),
        border: Border(
          top: BorderSide(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder).withValues(alpha: 0.5)),
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
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_activeAudio!.title, 
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


}

// _Track class removed — SleepTrack from core/utils/audio_tracks.dart is used instead.
// Wellness filter uses SleepTrack.type field for category matching.


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

class _YogaSession {
  final String title;
  final String subtitle;
  final String duration;
  final String level;
  final Color color;
  final IconData icon;
  const _YogaSession(this.title, this.subtitle, this.duration, this.level, this.color, this.icon);
}
