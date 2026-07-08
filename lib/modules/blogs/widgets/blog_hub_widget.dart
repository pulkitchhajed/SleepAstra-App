import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../models/blog_model.dart';
import '../services/blog_service.dart';
import '../screens/blog_list_screen.dart';
import '../screens/blog_detail_screen.dart';
import '../../paywall/providers/subscription_provider.dart';
import '../../../core/router/app_router.dart';

class BlogHubWidget extends StatelessWidget {
  final bool isLight;

  const BlogHubWidget({super.key, required this.isLight});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BlogModel>>(
      stream: BlogService.watchBlogs(),
      builder: (context, snapshot) {
        // Hide entire section while loading or if empty
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final blogs = snapshot.data ?? [];
        if (blogs.isEmpty) return const SizedBox.shrink();

        final displayBlogs = blogs.take(3).toList();
        final isPremium = context.watch<SubscriptionProvider>().isPremium;

        final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
        final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
        final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
        final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header ────────────────────────────────────────
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
                      const SizedBox(width: 10),
                      const Icon(Icons.auto_stories_rounded,
                          color: AppTheme.primaryIndigo, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Blogs & Stories',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BlogListScreen()),
                    ),
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
            ),

            // ── Horizontal Cards ──────────────────────────────────────
            SizedBox(
              height: 255,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                itemCount: displayBlogs.length,
                itemBuilder: (context, i) {
                  final b = displayBlogs[i];
                  final isLocked = !isPremium && i >= 2;

                  return _BlogCardItem(
                    blog: b,
                    isLocked: isLocked,
                    isLight: isLight,
                    index: i,
                    textPrimary: textPrimary,
                    textSec: textSec,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlogCardItem extends StatefulWidget {
  final BlogModel blog;
  final bool isLocked;
  final bool isLight;
  final int index;
  final Color textPrimary;
  final Color textSec;

  const _BlogCardItem({
    required this.blog,
    required this.isLocked,
    required this.isLight,
    required this.index,
    required this.textPrimary,
    required this.textSec,
  });

  @override
  State<_BlogCardItem> createState() => _BlogCardItemState();
}

class _BlogCardItemState extends State<_BlogCardItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (widget.isLocked) {
          Navigator.pushNamed(context, AppRouter.paywall);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BlogDetailScreen(blog: widget.blog)),
          );
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Full-size immersive thumbnail ──
              Container(
                height: 150,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isLight ? 0.12 : 0.35),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isLight ? 0.06 : 0.15),
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
                      widget.blog.coverImageUrl.isNotEmpty
                          ? Image.network(
                              widget.blog.coverImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderCover(widget.index),
                            )
                          : _placeholderCover(widget.index),
                      // Gradient overlay at bottom for readability
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 50,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Category badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            widget.blog.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Lock overlay
                      if (widget.isLocked)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 32),
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
                        widget.blog.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 11, color: widget.textSec),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.blog.readTimeMinutes} min read',
                            style: TextStyle(color: widget.textSec, fontSize: 11),
                          ),
                          const Spacer(),
                          Icon(Icons.favorite_rounded, size: 11, color: AppTheme.error.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text('${widget.blog.likes.length}', style: TextStyle(color: widget.textSec, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover(int index) {
    final gradients = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
    ];
    final icons = [
      Icons.bedtime_rounded,
      Icons.self_improvement_rounded,
      Icons.health_and_safety_rounded,
    ];
    final gradient = gradients[index % gradients.length];
    final icon = icons[index % icons.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 48),
      ),
    );
  }
}
