import 'package:flutter/material.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../../videos/models/video_model.dart';
import '../../videos/services/video_service.dart';
import '../../blogs/models/blog_model.dart';
import '../../blogs/services/blog_service.dart';
import '../../audio/models/audio_track_model.dart';
import '../../audio/services/audio_track_service.dart';
import 'upload_video_screen.dart';
import 'upload_blog_screen.dart';
import 'upload_audio_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryIndigo,
            labelColor: AppTheme.primaryIndigo,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(text: 'Videos'),
              Tab(text: 'Blogs'),
              Tab(text: 'Audio'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminVideosTab(),
            _AdminBlogsTab(),
            _AdminAudioTab(),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'upload_video',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
              ),
              backgroundColor: AppTheme.primaryIndigo,
              icon: const Icon(Icons.video_call_rounded, color: Colors.white),
              label: const Text(
                'Upload Video',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'upload_blog',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadBlogScreen()),
              ),
              backgroundColor: AppTheme.primaryIndigo,
              icon: const Icon(Icons.post_add_rounded, color: Colors.white),
              label: const Text(
                'Upload Blog',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'upload_audio',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadAudioScreen()),
              ),
              backgroundColor: AppTheme.primaryIndigo,
              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
              label: const Text(
                'Upload Audio',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminVideosTab extends StatelessWidget {
  const _AdminVideosTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VideoModel>>(
      stream: VideoService.watchVideos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          );
        }
        final videos = snapshot.data ?? [];
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_library_outlined,
                    color: AppTheme.textSecondary, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'No videos yet. Upload one!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: videos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _AdminVideoCard(video: videos[i]),
        );
      },
    );
  }
}

class _AdminBlogsTab extends StatelessWidget {
  const _AdminBlogsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BlogModel>>(
      stream: BlogService.watchBlogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          );
        }
        final blogs = snapshot.data ?? [];
        if (blogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.article_outlined,
                    color: AppTheme.textSecondary, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'No blogs yet. Write one!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: blogs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _AdminBlogCard(blog: blogs[i]),
        );
      },
    );
  }
}

class _AdminVideoCard extends StatelessWidget {
  final VideoModel video;
  const _AdminVideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    width: 90,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                  )
                : _thumbPlaceholder(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryIndigo),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UploadVideoScreen(existingVideo: video),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 90,
        height: 80,
        color: AppTheme.surface,
        child: const Icon(Icons.play_circle_outline_rounded,
            color: AppTheme.textSecondary, size: 32),
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Video?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete "${video.title}"? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await VideoService.deleteVideo(video.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _AdminBlogCard extends StatelessWidget {
  final BlogModel blog;
  const _AdminBlogCard({required this.blog});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: blog.coverImageUrl.isNotEmpty
                ? Image.network(
                    blog.coverImageUrl,
                    width: 90,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                  )
                : _thumbPlaceholder(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blog.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    blog.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryIndigo),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UploadBlogScreen(existingBlog: blog),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 90,
        height: 80,
        color: AppTheme.surface,
        child: const Icon(Icons.article_outlined,
            color: AppTheme.textSecondary, size: 32),
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Blog?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete "${blog.title}"? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BlogService.deleteBlog(blog.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _AdminAudioTab extends StatelessWidget {
  const _AdminAudioTab();

  @override
  Widget build(BuildContext context) {
    final service = AudioTrackService();
    return StreamBuilder<List<AudioTrackModel>>(
      stream: service.getAudioTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          );
        }
        final tracks = snapshot.data ?? [];
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.audiotrack_outlined,
                    color: AppTheme.textSecondary, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'No audio tracks yet. Upload one!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: tracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _AdminAudioCard(track: tracks[i], service: service),
        );
      },
    );
  }
}

class _AdminAudioCard extends StatelessWidget {
  final AudioTrackModel track;
  final AudioTrackService service;
  
  const _AdminAudioCard({required this.track, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: track.thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(track.thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
              ),
              child: track.thumbnailUrl.isEmpty
                  ? const Icon(Icons.audiotrack, color: AppTheme.primaryIndigo)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${track.category} • ${track.duration}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UploadAudioScreen(existingAudio: track)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text('Delete Audio', style: TextStyle(color: Colors.white)),
                    content: const Text('Are you sure you want to delete this track?', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await service.deleteAudioTrack(track.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
