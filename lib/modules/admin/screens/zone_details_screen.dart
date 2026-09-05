import 'package:flutter/material.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../models/wellness_zone_model.dart';
import '../services/wellness_zone_service.dart';
import '../../videos/models/video_model.dart';
import '../../videos/services/video_service.dart';
import '../../blogs/models/blog_model.dart';
import '../../blogs/services/blog_service.dart';
import '../../audio/models/audio_track_model.dart';
import '../../audio/services/audio_track_service.dart';
import 'upload_video_screen.dart';
import 'upload_blog_screen.dart';
import 'upload_audio_screen.dart';
import 'admin_dashboard_screen.dart';

class ZoneDetailsScreen extends StatefulWidget {
  final WellnessZoneModel zone;
  const ZoneDetailsScreen({super.key, required this.zone});

  @override
  State<ZoneDetailsScreen> createState() => _ZoneDetailsScreenState();
}

class _ZoneDetailsScreenState extends State<ZoneDetailsScreen> with SingleTickerProviderStateMixin {
  late WellnessZoneModel _currentZone;
  late TabController _tabController;
  final _audioService = AudioTrackService();

  List<String> get _availableTabs {
    final types = _currentZone.contentTypes;
    final tabs = <String>[];
    if (types.contains('video')) tabs.add('Videos');
    if (types.contains('audio')) tabs.add('Audio');
    if (types.contains('blog')) tabs.add('Blogs');
    if (tabs.isEmpty) tabs.addAll(['Videos', 'Audio', 'Blogs']);
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _currentZone = widget.zone;
    _tabController = TabController(length: _availableTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _rebuildTabController() {
    _tabController.dispose();
    _tabController = TabController(length: _availableTabs.length, vsync: this);
    setState(() {});
  }

  Future<void> _showEditZoneDialog() async {
    final nameCtrl = TextEditingController(text: _currentZone.name);
    final typeAudio = ValueNotifier<bool>(_currentZone.contentTypes.contains('audio'));
    final typeVideo = ValueNotifier<bool>(_currentZone.contentTypes.contains('video'));
    final typeBlog = ValueNotifier<bool>(_currentZone.contentTypes.contains('blog'));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Zone', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Zone Name',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.cardBorder)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryIndigo)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Allowed Content Types:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ValueListenableBuilder<bool>(
                valueListenable: typeAudio,
                builder: (c, val, _) => CheckboxListTile(
                  title: const Text('Audio', style: TextStyle(color: AppTheme.textPrimary)),
                  value: val,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (v) => typeAudio.value = v ?? false,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: typeVideo,
                builder: (c, val, _) => CheckboxListTile(
                  title: const Text('Video', style: TextStyle(color: AppTheme.textPrimary)),
                  value: val,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (v) => typeVideo.value = v ?? false,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: typeBlog,
                builder: (c, val, _) => CheckboxListTile(
                  title: const Text('Blog', style: TextStyle(color: AppTheme.textPrimary)),
                  value: val,
                  activeColor: AppTheme.primaryIndigo,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              final types = <String>[];
              if (typeAudio.value) types.add('audio');
              if (typeVideo.value) types.add('video');
              if (typeBlog.value) types.add('blog');

              await WellnessZoneService.updateZone(
                id: _currentZone.id,
                name: newName,
                contentTypes: types,
              );

              if (!mounted) return;
              setState(() {
                _currentZone = WellnessZoneModel(
                  id: _currentZone.id,
                  name: newName,
                  contentTypes: types,
                  order: _currentZone.order,
                  createdAt: _currentZone.createdAt,
                );
              });
              _rebuildTabController();
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Zone updated!'), backgroundColor: AppTheme.success),
              );
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteZone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Zone?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${_currentZone.name}"? Content within this zone will NOT be deleted.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Zone', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await WellnessZoneService.deleteZone(_currentZone.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zone deleted.'), backgroundColor: AppTheme.textSecondary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _availableTabs;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_currentZone.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo),
            tooltip: 'Edit Zone',
            onPressed: _showEditZoneDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
            tooltip: 'Delete Zone',
            onPressed: _confirmDeleteZone,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryIndigo,
          labelColor: AppTheme.primaryIndigo,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs.map((tab) {
          switch (tab) {
            case 'Videos':
              return _buildVideosTab();
            case 'Audio':
              return _buildAudioTab();
            case 'Blogs':
              return _buildBlogsTab();
            default:
              return const SizedBox.shrink();
          }
        }).toList(),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_currentZone.contentTypes.contains('video'))
            _buildFab(context, 'Add Video', Icons.video_call_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadVideoScreen(defaultCategory: _currentZone.name)),
              );
            }),
          if (_currentZone.contentTypes.contains('blog')) ...[
            const SizedBox(height: 10),
            _buildFab(context, 'Add Blog', Icons.post_add_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadBlogScreen(defaultCategory: _currentZone.name)),
              );
            }),
          ],
          if (_currentZone.contentTypes.contains('audio')) ...[
            const SizedBox(height: 10),
            _buildFab(context, 'Add Audio', Icons.audiotrack_rounded, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadAudioScreen(defaultCategory: _currentZone.name)),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    return StreamBuilder<List<VideoModel>>(
      stream: VideoService.watchVideos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
        }

        final allVideos = snapshot.data ?? [];
        final zoneVideos = allVideos
            .where((v) => v.category.trim().toLowerCase() == _currentZone.name.trim().toLowerCase())
            .toList();

        if (zoneVideos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.video_library_outlined,
            title: 'No videos in ${_currentZone.name}',
            buttonLabel: 'Upload Video',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadVideoScreen(defaultCategory: _currentZone.name)),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: zoneVideos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => AdminVideoCard(video: zoneVideos[i]),
        );
      },
    );
  }

  Widget _buildAudioTab() {
    return StreamBuilder<List<AudioTrackModel>>(
      stream: _audioService.getAudioTracks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
        }

        final allTracks = snapshot.data ?? [];
        final zoneTracks = allTracks
            .where((t) => t.category.trim().toLowerCase() == _currentZone.name.trim().toLowerCase())
            .toList();

        if (zoneTracks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.audiotrack_outlined,
            title: 'No audio tracks in ${_currentZone.name}',
            buttonLabel: 'Upload Audio',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadAudioScreen(defaultCategory: _currentZone.name)),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: zoneTracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => AdminAudioCard(track: zoneTracks[i], service: _audioService),
        );
      },
    );
  }

  Widget _buildBlogsTab() {
    return StreamBuilder<List<BlogModel>>(
      stream: BlogService.watchBlogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
        }

        final allBlogs = snapshot.data ?? [];
        final zoneBlogs = allBlogs
            .where((b) => b.category.trim().toLowerCase() == _currentZone.name.trim().toLowerCase())
            .toList();

        if (zoneBlogs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.article_outlined,
            title: 'No blogs in ${_currentZone.name}',
            buttonLabel: 'Upload Blog',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadBlogScreen(defaultCategory: _currentZone.name)),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: zoneBlogs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => AdminBlogCard(blog: zoneBlogs[i]),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    return FloatingActionButton.extended(
      heroTag: 'zone_${_currentZone.name}_$label',
      onPressed: onPressed,
      backgroundColor: AppTheme.primaryIndigo,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
