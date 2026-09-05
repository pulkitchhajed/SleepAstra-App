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
import '../models/quick_access_model.dart';
import '../services/quick_access_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // WellnessZoneService.ensureDefaultZones();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
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
              Tab(text: 'Quick Access'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminZonesTab(),
            _AdminVideosTab(),
            _AdminBlogsTab(),
            _AdminAudioTab(),
            _AdminQuickAccessTab(),
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
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'create_quick_access',
              onPressed: () => _showCreateQuickAccessDialog(context),
              backgroundColor: AppTheme.primaryIndigo,
              icon: const Icon(Icons.bolt_rounded, color: Colors.white),
              label: const Text(
                'Add Quick Access',
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

  void _showCreateQuickAccessDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final thumbCtrl = TextEditingController();
    String selectedRoute = 'custom';

    final builtInRoutes = {
      'custom': 'Custom URL / Other',
      '/sleep-history': 'Sleep Diary',
      'route:/wellness': 'Wellness Hub (Yoga)',
      '/relaxation': 'Meditation',
      'route:/snore_track': 'Snore Track',
      'route:/sleep_stages': 'Sleep Stages',
      '/journal': 'Journal List',
      '/insights': 'Nidra AI Insights',
      '/daily_sleep_goal': 'Daily Sleep Goal',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              title: const Text('Add Quick Access', style: TextStyle(color: AppTheme.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRoute,
                      dropdownColor: AppTheme.surfaceElevated,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Target Type / Route',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                      items: builtInRoutes.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          selectedRoute = v ?? 'custom';
                          if (selectedRoute != 'custom') {
                            targetCtrl.text = selectedRoute;
                          } else {
                            targetCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (selectedRoute == 'custom') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: targetCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Custom Target URL or Route',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: thumbCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Thumbnail URL',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
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
                    if (titleCtrl.text.trim().isEmpty || targetCtrl.text.trim().isEmpty) return;
                    await QuickAccessService.createItem(
                      title: titleCtrl.text.trim(),
                      target: targetCtrl.text.trim(),
                      thumbnailUrl: thumbCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create', style: TextStyle(color: AppTheme.primaryIndigo)),
                ),
              ],
            );
          },
        );
      },
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

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${zones.length} Zones Available',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (zones.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_clear_rounded, color: AppTheme.textSecondary, size: 48),
                      SizedBox(height: 12),
                      Text('No Zones yet. Tap + to create one.', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ),
      ),
    ],
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
          itemBuilder: (context, i) => AdminVideoCard(video: videos[i]),
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
          itemBuilder: (context, i) => AdminBlogCard(blog: blogs[i]),
        );
      },
    );
  }
}

class AdminVideoCard extends StatelessWidget {
  final VideoModel video;
  const AdminVideoCard({super.key, required this.video});

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

class AdminBlogCard extends StatelessWidget {
  final BlogModel blog;
  const AdminBlogCard({super.key, required this.blog});

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
          itemBuilder: (context, i) => AdminAudioCard(track: tracks[i], service: service),
        );
      },
    );
  }
}

class AdminAudioCard extends StatelessWidget {
  final AudioTrackModel track;
  final AudioTrackService service;
  
  const AdminAudioCard({super.key, required this.track, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                child: track.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        track.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.audiotrack_rounded, color: AppTheme.primaryIndigo),
                      )
                    : const Icon(Icons.audiotrack_rounded, color: AppTheme.primaryIndigo),
              ),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: track.loop
                              ? AppTheme.primaryIndigo.withValues(alpha: 0.15)
                              : AppTheme.textSecondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              track.loop ? Icons.repeat_rounded : Icons.play_arrow_rounded,
                              size: 12,
                              color: track.loop ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              track.loop ? 'Loop: On' : 'Loop: Off',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: track.loop ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _AdminQuickAccessTab extends StatelessWidget {
  const _AdminQuickAccessTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuickAccessModel>>(
      stream: QuickAccessService.watchItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }

        final items = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${items.length} Quick Access Items',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await QuickAccessService.ensureDefaultItems();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Default quick access items populated!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16, color: AppTheme.primaryIndigo),
                    label: const Text('Sync Defaults', style: TextStyle(color: AppTheme.primaryIndigo, fontSize: 13)),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No Quick Access items found.', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    for (int i = 0; i < items.length; i++) {
                      QuickAccessService.updateOrder(items[i].id, i);
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      key: ValueKey(item.id),
                      color: AppTheme.surfaceElevated,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item.thumbnailUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(item.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: AppTheme.primaryIndigo)),
                                )
                              : const Icon(Icons.bolt, color: AppTheme.primaryIndigo),
                        ),
                        title: Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text('Target: ${item.target}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: AppTheme.surfaceElevated,
                                    title: const Text('Delete Item', style: TextStyle(color: AppTheme.textPrimary)),
                                    content: const Text('Delete this Quick Access item?', style: TextStyle(color: AppTheme.textSecondary)),
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
                                  await QuickAccessService.deleteItem(item.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
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
