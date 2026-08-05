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
import '../models/wellness_zone_model.dart';
import '../services/wellness_zone_service.dart';
import 'zone_details_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
              Tab(text: 'Zones'),
              Tab(text: 'Videos'),
              Tab(text: 'Blogs'),
              Tab(text: 'Audio'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminZonesTab(),
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
              heroTag: 'create_zone',
              onPressed: () => _showCreateZoneDialog(context),
              backgroundColor: AppTheme.success,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Create Zone',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
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

  void _showCreateZoneDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final typeAudio = ValueNotifier(false);
    final typeVideo = ValueNotifier(false);
    final typeBlog = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Create New Zone', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Zone Name (e.g. Meditation)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Content Types Supported:', style: TextStyle(color: AppTheme.textSecondary)),
              ValueListenableBuilder<bool>(
                valueListenable: typeAudio,
                builder: (ctx, val, _) => CheckboxListTile(
                  title: const Text('Audio', style: TextStyle(color: AppTheme.textPrimary)),
                  value: val,
                  onChanged: (v) => typeAudio.value = v ?? false,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: typeVideo,
                builder: (ctx, val, _) => CheckboxListTile(
                  title: const Text('Video', style: TextStyle(color: AppTheme.textPrimary)),
                  value: val,
                  onChanged: (v) => typeVideo.value = v ?? false,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: typeBlog,
                builder: (ctx, val, _) => CheckboxListTile(
                  title: const Text('Blog', style: TextStyle(color: AppTheme.textPrimary)),
                  value: val,
                  onChanged: (v) => typeBlog.value = v ?? false,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final types = <String>[];
              if (typeAudio.value) types.add('audio');
              if (typeVideo.value) types.add('video');
              if (typeBlog.value) types.add('blog');
              await WellnessZoneService.createZone(
                name: nameCtrl.text.trim(),
                contentTypes: types,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: AppTheme.primaryIndigo)),
          ),
        ],
      ),
    );
  }
}


class _AdminZonesTab extends StatelessWidget {
  const _AdminZonesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WellnessZoneModel>>(
      stream: WellnessZoneService.watchZones(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }

        final zones = snapshot.data!;
        if (zones.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No Zones found. Create one to get started.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await WellnessZoneService.backfillDefaultZones();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                  child: const Text('Backfill Default Zones', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: zones.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = zones.removeAt(oldIndex);
            zones.insert(newIndex, item);
            for (int i = 0; i < zones.length; i++) {
              WellnessZoneService.updateZoneOrder(zones[i].id, i);
            }
          },
          itemBuilder: (context, index) {
            final zone = zones[index];
            return Card(
              key: ValueKey(zone.id),
              color: AppTheme.surfaceElevated,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(zone.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Types: ${zone.contentTypes.join(", ")}', style: const TextStyle(color: AppTheme.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      onPressed: () => _confirmDelete(context, zone),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZoneDetailsScreen(zone: zone),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WellnessZoneModel zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Zone?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete ${zone.name}? Content within will NOT be deleted.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await WellnessZoneService.deleteZone(zone.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
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
