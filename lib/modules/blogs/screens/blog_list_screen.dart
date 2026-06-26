import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:snore_clinics/core/providers/auth_provider.dart';
import '../models/blog_model.dart';
import '../services/blog_service.dart';
import 'blog_detail_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../paywall/providers/subscription_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/theme_provider.dart';

class BlogListScreen extends StatelessWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSecondary = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: bg,
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
                    icon: const Icon(Icons.shield_rounded, color: AppTheme.primaryGold, size: 18),
                    label: const Text(
                      'Admin',
                      style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.w700),
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
                              colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blogs & Stories',
                              style: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Read, learn, and grow',
                              style: TextStyle(color: textSecondary, fontSize: 13),
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

          // ── Blog List ───────────────────────────────────────────────
          StreamBuilder<List<BlogModel>>(
            stream: BlogService.watchBlogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo)),
                );
              }

              final blogs = snapshot.data ?? [];

              if (blogs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books_outlined, color: textSecondary, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No blogs available yet.',
                          style: TextStyle(color: textSecondary, fontSize: 16),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Go to Admin Dashboard'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _BlogListCard(blog: blogs[i], index: i),
                    ),
                    childCount: blogs.length,
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

class _BlogListCard extends StatelessWidget {
  final BlogModel blog;
  final int index;
  const _BlogListCard({required this.blog, required this.index});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final isLocked = !isPremium && index >= 2;
    
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final surfaceElevated = isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated;
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSecondary = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          Navigator.pushNamed(context, AppRouter.paywall);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BlogDetailScreen(blog: blog)),
          );
        }
      },
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.25),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: Stack(
                children: [
                  SizedBox(
                    width: 120,
                    height: double.infinity,
                    child: blog.coverImageUrl.isNotEmpty
                        ? Image.network(
                            blog.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                          )
                        : _thumbPlaceholder(),
                  ),
                  if (isLocked)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded, color: AppTheme.primaryGold, size: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            blog.category.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primaryIndigo,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${blog.readTimeMinutes} min read',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      blog.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.3,
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
  }

  Widget _thumbPlaceholder() {
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
        child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 32),
      ),
    );
  }
}
