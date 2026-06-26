import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:snore_clinics/core/providers/auth_provider.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';
import 'video_player_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../paywall/providers/subscription_provider.dart';
import '../../../core/router/app_router.dart';

class VideoListScreen extends StatelessWidget {
  const VideoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.background,
            automaticallyImplyLeading: false,
            actions: [
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                    ),
                    icon: const Icon(Icons.shield_rounded,
                        color: AppTheme.primaryGold, size: 18),
                    label: const Text(
                      'Admin',
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF9C91FF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.play_circle_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video Library',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Wellness videos curated for you',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Video Grid ───────────────────────────────────────────────
          StreamBuilder<List<VideoModel>>(
            stream: VideoService.watchVideos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
                  ),
                );
              }

              final videos = snapshot.data ?? [];

              if (videos.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library_outlined,
                            color: AppTheme.textSecondary, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No videos available yet.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminDashboardScreen()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Go to Admin Dashboard'),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(220, 48)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _VideoCard(video: videos[i], index: i),
                    childCount: videos.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.70,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Video Card ────────────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final VideoModel video;
  final int index;
  const _VideoCard({required this.video, required this.index});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final isLocked = !isPremium && index >= 1;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          Navigator.pushNamed(context, AppRouter.paywall);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-size immersive thumbnail ──
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
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
                    video.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                          )
                        : _thumbPlaceholder(),
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
                    // Play / Lock icon
                    Center(
                      child: isLocked
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 24),
                            )
                          : Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white54, width: 1.5),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Text below thumbnail ──
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  if (video.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      video.tags.take(2).join(' · '),
                      style: const TextStyle(
                        color: AppTheme.primaryIndigo,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.video_collection_rounded, color: Colors.white54, size: 36),
      );
}
