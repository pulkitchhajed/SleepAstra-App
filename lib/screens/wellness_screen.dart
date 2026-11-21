import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../core/providers/audio_player_provider.dart';
import '../modules/videos/models/video_model.dart';
import '../modules/videos/services/video_service.dart';
import '../modules/videos/screens/video_list_screen.dart';
import '../modules/videos/screens/video_player_screen.dart';
import '../modules/blogs/widgets/blog_hub_widget.dart';
import '../modules/paywall/providers/subscription_provider.dart';
import '../core/router/app_router.dart';
import '../modules/audio/models/audio_track_model.dart';
import '../modules/audio/widgets/audio_player_sheet.dart';
import '../modules/blogs/models/blog_model.dart';
import '../modules/blogs/screens/blog_detail_screen.dart';
import '../modules/blogs/screens/blog_list_screen.dart';
import '../modules/admin/models/wellness_zone_model.dart';
import '../modules/admin/services/wellness_zone_service.dart';

class _ZoneData {
  final List<VideoModel> videos;
  final List<AudioTrackModel> audios;
  final List<BlogModel> blogs;
  final bool isLoaded;

  const _ZoneData({
    this.videos = const [],
    this.audios = const [],
    this.blogs = const [],
    this.isLoaded = false,
  });

  bool get isEmpty => videos.isEmpty && audios.isEmpty && blogs.isEmpty;
}

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  /// Global key so external code can call selectZoneByName.
  static final GlobalKey<_WellnessScreenState> globalKey =
      GlobalKey<_WellnessScreenState>();

  /// Navigate to the Wellness tab and jump to the zone whose name or id
  /// matches [zoneTarget]. [zoneTarget] may be:
  ///   - a zone id  (e.g. the part after "zone:")
  ///   - a zone name (case-insensitive match)
  static void navigateToZone(BuildContext context, String zoneTarget) {
    // The MainNavScreen will switch to Wellness tab (index 1); after the frame
    // renders we select the matching zone.
    final state = globalKey.currentState;
    if (state != null) {
      state.selectZoneByTarget(zoneTarget);
    } else {
      // Screen may not be visible yet; store the pending target so initState
      // can apply it once the zones load.
      _WellnessScreenState._pendingZoneTarget = zoneTarget;
    }
  }

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  /// Holds a pending zone target when navigateToZone is called before zones
  /// have loaded (e.g. the tab was not yet mounted).
  static String? _pendingZoneTarget;

  int _selectedCategoryIndex = 0;
  List<String> get _categories => ['All Zones', ..._zones.map((z) => z.name)];

  List<WellnessZoneModel> _zones = [];
  StreamSubscription? _zonesSub;

  final Map<String, _ZoneData> _zoneDataCache = {};
  bool _isInitialLoading = true;

  /// Controller for the category chip list so we can scroll the selected chip into view.
  final ScrollController _chipScrollController = ScrollController();

  /// Controller for the main content scroll so we can reset to top on zone change.
  final ScrollController _contentScrollController = ScrollController();

  /// Selects the zone chip matching [target] (zone id or name, case-insensitive)
  /// and jumps the chip list to that chip.
  void selectZoneByTarget(String target) {
    if (_zones.isEmpty) {
      _pendingZoneTarget = target;
      return;
    }

    final lower = target.toLowerCase().trim();

    // Try matching by id first, then by name
    int zoneListIndex = _zones.indexWhere((z) => z.id.toLowerCase() == lower);
    if (zoneListIndex == -1) {
      zoneListIndex = _zones.indexWhere((z) => z.name.toLowerCase() == lower);
    }
    if (zoneListIndex == -1) {
      // Partial name match (e.g. "sleep" matches "Sleep Sounds")
      zoneListIndex = _zones.indexWhere(
          (z) => z.name.toLowerCase().contains(lower) || lower.contains(z.name.toLowerCase()));
    }

    if (zoneListIndex != -1) {
      // Category index is 1-based (0 = All Zones)
      final chipIndex = zoneListIndex + 1;
      if (mounted) {
        setState(() => _selectedCategoryIndex = chipIndex);
        // Scroll the chip bar so the selected chip is visible, and reset
        // the content scroll to top so the user immediately sees the zone.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Scroll chip list – each chip is roughly 100 px wide incl. margin
          if (_chipScrollController.hasClients) {
            final offset = (chipIndex * 110.0).clamp(
              0.0,
              _chipScrollController.position.maxScrollExtent,
            );
            _chipScrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          // Reset content scroll to top
          if (_contentScrollController.hasClients) {
            _contentScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _zonesSub = WellnessZoneService.watchZones().listen((zones) {
      if (mounted) {
        setState(() => _zones = zones);
        _preloadAllZones(zones);
        // Apply any pending deep-link target once zones are available
        if (_pendingZoneTarget != null) {
          final target = _pendingZoneTarget!;
          _pendingZoneTarget = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectZoneByTarget(target);
          });
        }
      }
    });
  }

  Future<void> _preloadAllZones(List<WellnessZoneModel> zones) async {
    final db = FirebaseFirestore.instance;
    await Future.wait(zones.map((zone) async {
      try {
        final Future<QuerySnapshot<Map<String, dynamic>>?> videoFuture = zone.contentTypes.contains('video')
            ? db.collection('videos').where('category', isEqualTo: zone.name).limit(10).get()
            : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);
        final Future<QuerySnapshot<Map<String, dynamic>>?> audioFuture = zone.contentTypes.contains('audio')
            ? db.collection('audio_tracks').where('category', isEqualTo: zone.name).limit(10).get()
            : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);
        final Future<QuerySnapshot<Map<String, dynamic>>?> blogFuture = zone.contentTypes.contains('blog')
            ? db.collection('blogs').where('category', isEqualTo: zone.name).limit(10).get()
            : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);

        final results = await Future.wait([videoFuture, audioFuture, blogFuture]);
        final videoSnap = results[0];
        final audioSnap = results[1];
        final blogSnap = results[2];

        final videos = (videoSnap?.docs ?? [])
            .map((d) => VideoModel.fromJson(d.id, d.data()))
            .toList();
        final audios = (audioSnap?.docs ?? [])
            .map((d) => AudioTrackModel.fromJson(d.id, d.data()))
            .toList();
        final blogs = (blogSnap?.docs ?? [])
            .map((d) => BlogModel.fromJson(d.id, d.data()))
            .toList();

        _zoneDataCache[zone.id] = _ZoneData(
          videos: videos,
          audios: audios,
          blogs: blogs,
          isLoaded: true,
        );
      } catch (e) {
        _zoneDataCache[zone.id] = const _ZoneData(isLoaded: true);
      }
    }));

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
    _chipScrollController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  /// Tap a track: start global playback then open the full player sheet.
  void _playTrack(AudioTrackModel track, List<AudioTrackModel> playlist) {
    final ap = context.read<AudioPlayerProvider>();
    // If the same track is already loaded, just open the sheet.
    if (ap.activeTrack?.id == track.id) {
      AudioPlayerSheet.show(context);
      return;
    }
    ap.play(track, playlist);
    AudioPlayerSheet.show(context);
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
                    controller: _chipScrollController,
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
                          // Reset content scroll to top on manual chip tap
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_contentScrollController.hasClients) {
                              _contentScrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
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
                    controller: _contentScrollController,
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedCategoryIndex == 0) ...[
                          BlogHubWidget(isLight: isLight).animate().fadeIn(delay: 150.ms, duration: 350.ms),
                          const SizedBox(height: 32),

                          // ── Dynamic Zones from Admin ─────────────────────
                          if (_isInitialLoading && _zoneDataCache.isEmpty)
                            _buildWellnessSkeleton(isLight)
                          else
                            ..._zones.map((zone) => _buildDynamicZone(zone, isLight)).toList(),
                        ] else if (_selectedCategoryIndex > 0 && _selectedCategoryIndex - 1 < _zones.length) ...[
                           _buildDynamicZone(_zones[_selectedCategoryIndex - 1], isLight),
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

            // Bottom Sticky Player removed — GlobalAudioMiniBar in MainNavScreen handles this.
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

  String _getZoneAudioTitle(String zoneName) {
    final trimmed = zoneName.trim();
    final lower = trimmed.toLowerCase();
    if (lower.contains('sound') || lower.contains('audio') || lower.contains('music')) {
      return trimmed;
    }
    return '$trimmed Audio';
  }

  String _getZoneVideoTitle(String zoneName) {
    final trimmed = zoneName.trim();
    final lower = trimmed.toLowerCase();
    if (lower.contains('video') || lower.contains('clip')) {
      return trimmed;
    }
    return '$trimmed Videos';
  }

  String _getZoneBlogTitle(String zoneName) {
    final trimmed = zoneName.trim();
    final lower = trimmed.toLowerCase();
    if (lower.contains('article') || lower.contains('guide') || lower.contains('blog') || lower.contains('story') || lower.contains('stories')) {
      return trimmed;
    }
    if (lower.contains('tip')) {
      return '$trimmed & Guides';
    }
    return '$trimmed Articles & Guides';
  }

  Widget _buildSectionTitle(String title, bool isLight, {VoidCallback? onSeeAll, IconData? icon, String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.primaryIndigo, AppTheme.accentTeal],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                if (icon != null) ...[
                  Icon(icon, color: AppTheme.primaryIndigo, size: 20),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: AppTheme.primaryIndigo,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (title != 'Recommended for you') ...[
            const SizedBox(width: 8),
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
              Expanded(
                child: Row(
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
                    Flexible(
                      child: Text(
                        'Wellness Videos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
  Widget _buildDynamicZone(WellnessZoneModel zone, bool isLight) {
    final data = _zoneDataCache[zone.id];
    if (data == null || !data.isLoaded) {
      return _buildZoneSkeleton(zone, isLight);
    }
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.videos.isNotEmpty) _buildZoneVideosSection(zone, data.videos, isLight),
        if (data.audios.isNotEmpty) _buildZoneAudioSection(zone, data.audios, isLight),
        if (data.blogs.isNotEmpty) _buildZoneBlogsSection(zone, data.blogs, isLight),
      ],
    );
  }

  Widget _buildZoneVideosSection(WellnessZoneModel zone, List<VideoModel> videos, bool isLight) {
    if (videos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          _getZoneVideoTitle(zone.name),
          isLight,
          icon: Icons.video_library_rounded,
          badge: '${videos.length}',
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoListScreen()),
            );
          },
        ).animate().fadeIn(duration: 250.ms),
        SizedBox(
          height: 275,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: videos.length,
            itemBuilder: (context, i) {
              final v = videos[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        video: v,
                        playlist: videos,
                        startIndex: i,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 145,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 195,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
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
                                      child: const Icon(Icons.play_circle_rounded, color: Colors.white54, size: 44),
                                    ),
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black54],
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white70, width: 1.5),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                                ),
                              ),
                              if (v.tags.isNotEmpty)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      v.tags.first,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildZoneAudioSection(WellnessZoneModel zone, List<AudioTrackModel> audios, bool isLight) {
    if (audios.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          _getZoneAudioTitle(zone.name),
          isLight,
          icon: Icons.headphones_rounded,
          badge: '${audios.length}',
          onSeeAll: () {
            Navigator.pushNamed(context, AppRouter.audioLibrary, arguments: zone.name);
          },
        ).animate().fadeIn(duration: 250.ms),
        SizedBox(
          height: 90,
          child: Consumer<AudioPlayerProvider>(
            builder: (context, ap, _) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: audios.length,
                itemBuilder: (context, i) {
                  final track = audios[i];
                  final isActive = ap.activeTrack?.id == track.id;
                  final isCurrentPlaying = isActive && ap.isPlaying;

                  return GestureDetector(
                    onTap: () => _playTrack(track, audios),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 230,
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isActive ? AppTheme.primaryIndigo : (isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                          width: isActive ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isActive
                                ? AppTheme.primaryIndigo.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: isLight ? 0.05 : 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isActive
                                    ? [AppTheme.primaryIndigo, const Color(0xFF818CF8)]
                                    : [const Color(0xFF8B5CF6).withValues(alpha: 0.2), const Color(0xFF6366F1).withValues(alpha: 0.2)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isCurrentPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: isActive ? Colors.white : AppTheme.primaryIndigo,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  track.duration.isNotEmpty ? track.duration : 'Sleep Track',
                                  style: TextStyle(
                                    color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.accentTeal,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isCurrentPlaying ? 'Playing' : 'Paused',
                                        style: const TextStyle(color: AppTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
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
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildZoneBlogsSection(WellnessZoneModel zone, List<BlogModel> blogs, bool isLight) {
    if (blogs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          _getZoneBlogTitle(zone.name),
          isLight,
          icon: Icons.article_rounded,
          badge: '${blogs.length}',
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlogListScreen()),
            );
          },
        ).animate().fadeIn(duration: 250.ms),
        SizedBox(
          height: 215,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: blogs.length,
            itemBuilder: (context, i) {
              final b = blogs[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BlogDetailScreen(blog: b)),
                  );
                },
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 110,
                        width: double.infinity,
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                        child: b.coverImageUrl.isNotEmpty
                            ? Image.network(b.coverImageUrl, fit: BoxFit.cover, cacheWidth: 400)
                            : const Center(
                                child: Icon(Icons.article_rounded, color: AppTheme.primaryIndigo, size: 36),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: AppTheme.primaryIndigo),
                                const SizedBox(width: 4),
                                Text(
                                  '${b.readTimeMinutes} min read',
                                  style: TextStyle(
                                    color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWellnessSkeleton(bool isLight) {
    return Column(
      children: List.generate(2, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 160,
                height: 20,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(3, (i) {
                  return Container(
                    width: 140,
                    height: 180,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      }),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.35, end: 0.85, duration: 800.ms);
  }

  Widget _buildZoneSkeleton(WellnessZoneModel zone, bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 18,
            decoration: BoxDecoration(
              color: isLight ? Colors.black12 : Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(2, (i) {
              return Container(
                width: 140,
                height: 180,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            }),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.35, end: 0.85, duration: 800.ms);
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
