import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
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
import 'upload_quick_access_screen.dart';
import '../models/push_notification_model.dart';
import '../services/push_notification_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  
  final List<String> _tabs = [
    'Zones', 'Videos', 'Blogs', 'Audio', 'Quick Access', 'Notifications'
  ];

  final List<IconData> _tabIcons = [
    Icons.layers_rounded,
    Icons.video_library_rounded,
    Icons.article_rounded,
    Icons.audiotrack_rounded,
    Icons.bolt_rounded,
    Icons.notifications_rounded,
  ];

  final List<Widget> _tabViews = [
    const _AdminZonesTab(),
    const _AdminVideosTab(),
    const _AdminBlogsTab(),
    const _AdminAudioTab(),
    const _AdminQuickAccessTab(),
    const _AdminNotificationsTab(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? AppTheme.backgroundLight : AppTheme.background;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: isDesktop ? null : AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout(isLight) : _buildMobileLayout(isLight),
      floatingActionButton: _getFabForCurrentTab(),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(isLight),
    );
  }

  Widget _buildDesktopLayout(bool isLight) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          backgroundColor: isLight ? AppTheme.surfaceLight : AppTheme.surface,
          selectedIconTheme: const IconThemeData(color: AppTheme.primaryIndigo),
          unselectedIconTheme: IconThemeData(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
          selectedLabelTextStyle: const TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold),
          unselectedLabelTextStyle: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          destinations: List.generate(_tabs.length, (index) {
            return NavigationRailDestination(
              icon: Icon(_tabIcons[index]),
              label: Text(_tabs[index]),
            );
          }),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: _tabViews[_selectedIndex],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isLight) {
    return _tabViews[_selectedIndex];
  }

  Widget _buildBottomNavBar(bool isLight) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: isLight ? AppTheme.surfaceLight : AppTheme.surface,
      selectedItemColor: AppTheme.background, // Text color for selected item will be handled manually if needed, but standard handles it. 
      unselectedItemColor: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
      showUnselectedLabels: true,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: List.generate(_tabs.length, (index) {
        final isSelected = _selectedIndex == index;
        return BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orangeAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _tabIcons[index],
              color: isSelected ? Colors.black : (isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
            ),
          ),
          label: _tabs[index] == 'Notifications' ? 'Push' : _tabs[index],
        );
      }),
    );
  }

  Widget? _getFabForCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'create_zone',
          onPressed: () => _showCreateZoneDialog(context),
          backgroundColor: AppTheme.success,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Create Zone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'upload_video',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadVideoScreen())),
          backgroundColor: AppTheme.primaryIndigo,
          icon: const Icon(Icons.video_call_rounded, color: Colors.white),
          label: const Text('Upload Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'upload_blog',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadBlogScreen())),
          backgroundColor: AppTheme.primaryIndigo,
          icon: const Icon(Icons.post_add_rounded, color: Colors.white),
          label: const Text('Upload Blog', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: 'upload_audio',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAudioScreen())),
          backgroundColor: AppTheme.primaryIndigo,
          icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
          label: const Text('Upload Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );
      case 4:
        return FloatingActionButton.extended(
          heroTag: 'create_quick_access',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadQuickAccessScreen())),
          backgroundColor: AppTheme.primaryIndigo,
          icon: const Icon(Icons.bolt_rounded, color: Colors.white),
          label: const Text('Add Quick Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );
      case 5:
        return null;
      default:
        return null;
    }
  }

  void _showCreateZoneDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final typeAudio = ValueNotifier(false);
    final typeVideo = ValueNotifier(false);
    final typeBlog = ValueNotifier(false);
    final addToQuickAccess = ValueNotifier(true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
        title: Text('Create New Zone', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Zone Name (e.g. Meditation)',
                  labelStyle: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Content Types Supported:', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
              ValueListenableBuilder<bool>(
                valueListenable: typeAudio,
                builder: (ctx, val, _) => CheckboxListTile(
                  title: Text('Audio', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                  value: val,
                  onChanged: (v) => typeAudio.value = v ?? false,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: typeVideo,
                builder: (ctx, val, _) => CheckboxListTile(
                  title: Text('Video', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                  value: val,
                  onChanged: (v) => typeVideo.value = v ?? false,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: typeBlog,
                builder: (ctx, val, _) => CheckboxListTile(
                  title: Text('Blog', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                  value: val,
                  onChanged: (v) => typeBlog.value = v ?? false,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: addToQuickAccess,
                builder: (ctx, val, _) => Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CheckboxListTile(
                    title: const Text('Add to Quick Access on Home', style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('Shows in Home screen carousel', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    value: val,
                    activeColor: AppTheme.accentTeal,
                    onChanged: (v) => addToQuickAccess.value = v ?? true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
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
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: AppTheme.error)));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }

        final zones = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${zones.length} Zones Available',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (zones.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_clear_rounded, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), size: 48),
                      SizedBox(height: 12),
                      Text('No Zones yet. Tap + to create one.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(zone.name, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary), fontWeight: FontWeight.w600)),
                subtitle: Text('Types: ${zone.contentTypes.join(", ")}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bolt_rounded, color: AppTheme.accentTeal),
                      tooltip: 'Pin to Quick Access',
                      onPressed: () async {
                        await QuickAccessService.createItem(
                          title: zone.name,
                          target: 'zone:${zone.id}',
                          thumbnailUrl: '',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Pinned "${zone.name}" to Quick Access!')),
                          );
                        }
                      },
                    ),
                    Icon(Icons.drag_handle, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppTheme.error),
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
        backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
        title: Text('Delete Zone?', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
        content: Text('Are you sure you want to delete ${zone.name}? Content within will NOT be deleted.',
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
          ),
          TextButton(
            onPressed: () async {
              await WellnessZoneService.deleteZone(zone.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
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
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          );
        }
        final videos = snapshot.data ?? [];
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined,
                    color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), size: 56),
                SizedBox(height: 16),
                Text(
                  'No videos yet. Upload one!',
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: videos.length,
          separatorBuilder: (_, __) => SizedBox(height: 12),
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
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          );
        }
        final blogs = snapshot.data ?? [];
        if (blogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), size: 56),
                SizedBox(height: 16),
                Text(
                  'No blogs yet. Write one!',
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: blogs.length,
          separatorBuilder: (_, __) => SizedBox(height: 12),
          itemBuilder: (context, i) => AdminBlogCard(blog: blogs[i]),
        );
      },
    );
  }
}

class AdminVideoCard extends StatelessWidget {
  final VideoModel video;
  AdminVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    width: 90,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(context),
                  )
                : _thumbPlaceholder(context),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.edit_rounded, color: AppTheme.primaryIndigo),
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
                icon: Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) => Container(
        width: 90,
        height: 80,
        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface),
        child: Icon(Icons.play_circle_outline_rounded,
            color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), size: 32),
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
        title: Text('Delete Video?',
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
        content: Text(
          'Delete "${video.title}"? This cannot be undone.',
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await VideoService.deleteVideo(video.id);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class AdminBlogCard extends StatelessWidget {
  final BlogModel blog;
  AdminBlogCard({super.key, required this.blog});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: blog.coverImageUrl.isNotEmpty
                ? Image.network(
                    blog.coverImageUrl,
                    width: 90,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(context),
                  )
                : _thumbPlaceholder(context),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blog.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    blog.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.edit_rounded, color: AppTheme.primaryIndigo),
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
                icon: Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) => Container(
        width: 90,
        height: 80,
        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface),
        child: Icon(Icons.article_outlined,
            color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), size: 32),
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
        title: Text('Delete Blog?',
            style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
        content: Text(
          'Delete "${blog.title}"? This cannot be undone.',
          style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BlogService.deleteBlog(blog.id);
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
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
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          );
        }
        final tracks = snapshot.data ?? [];
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.audiotrack_outlined,
                    color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), size: 56),
                SizedBox(height: 16),
                Text(
                  'No audio tracks yet. Upload one!',
                  style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: tracks.length,
          separatorBuilder: (_, __) => SizedBox(height: 12),
          itemBuilder: (context, i) => AdminAudioCard(track: tracks[i], service: service),
        );
      },
    );
  }
}

class AdminAudioCard extends StatelessWidget {
  final AudioTrackModel track;
  final AudioTrackService service;
  
  AdminAudioCard({super.key, required this.track, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(12),
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
                        errorBuilder: (_, __, ___) => Icon(Icons.audiotrack_rounded, color: AppTheme.primaryIndigo),
                      )
                    : Icon(Icons.audiotrack_rounded, color: AppTheme.primaryIndigo),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${track.category} • ${track.duration}',
                    style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: track.loop
                              ? AppTheme.primaryIndigo.withValues(alpha: 0.15)
                              : (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              track.loop ? Icons.repeat_rounded : Icons.play_arrow_rounded,
                              size: 12,
                              color: track.loop ? AppTheme.primaryIndigo : (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                            ),
                            SizedBox(width: 4),
                            Text(
                              track.loop ? 'Loop: On' : 'Loop: Off',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: track.loop ? AppTheme.primaryIndigo : (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
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
              icon: Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UploadAudioScreen(existingAudio: track)),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface),
                    title: Text('Delete Audio', style: TextStyle(color: Colors.white)),
                    content: Text('Are you sure you want to delete this track?', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text('Delete', style: TextStyle(color: AppTheme.error)),
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
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: AppTheme.error)));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }

        final items = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${items.length} Quick Access Items',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await QuickAccessService.ensureDefaultItems();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Default quick access items populated!')),
                        );
                      }
                    },
                    icon: Icon(Icons.sync_rounded, size: 16, color: AppTheme.primaryIndigo),
                    label: Text('Sync Defaults', style: TextStyle(color: AppTheme.primaryIndigo, fontSize: 13)),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text('No Quick Access items found.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
                      margin: EdgeInsets.only(bottom: 12),
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
                                  child: Image.network(item.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.bolt, color: AppTheme.primaryIndigo)),
                                )
                              : Icon(Icons.bolt, color: AppTheme.primaryIndigo),
                        ),
                        title: Text(item.title, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary), fontWeight: FontWeight.w600)),
                        subtitle: Text('Target: ${item.target}', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle_rounded, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => UploadQuickAccessScreen(existingItem: item)),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: AppTheme.error),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
                                    title: Text('Delete Item', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                                    content: Text('Delete this Quick Access item?', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: Text('Delete', style: TextStyle(color: AppTheme.error)),
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

class _AdminNotificationsTab extends StatefulWidget {
  const _AdminNotificationsTab();

  @override
  State<_AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<_AdminNotificationsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  
  String _audience = 'All users';
  String _priority = 'Standard';
  String _timing = 'Send now';
  String _onTap = 'App home';
  bool _previewDarkTheme = false;
  Uint8List? _bannerImageBytes;
  String? _bannerImageName;
  bool _isSubmitting = false;
  DateTime? _scheduledDateTime;
  List<String> _selectedWeekdays = ['Monday'];
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final List<String> _weekdays = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<String> _onTapRoutes = [
    'App home', 'Settings', 'Sleep Analysis', 'Sleep History', 
    'Morning Journal', 'Evening Journal', 'Insights', 'Nidra Chat', 
    'Breathing', 'Relaxation', 'Video Library', 'Daily Sleep Goal'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleCtrl.addListener(() => setState(() {}));
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final secondaryTextColor = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Pane: Compose Notification
        Expanded(
          flex: 55,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compose\nNotification', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor, height: 1.2)),
                const SizedBox(height: 24),
                _buildTextField('Title', _titleCtrl, isLight),
                const SizedBox(height: 16),
                _buildTextField('Message', _messageCtrl, isLight, maxLines: 3),
                const SizedBox(height: 24),
                
                Text('Audience', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('All users', _audience, (v) => setState(() => _audience = v), isLight),
                    _buildChip('Premium users only', _audience, (v) => setState(() => _audience = v), isLight),
                    _buildChip('Unsubscribed users', _audience, (v) => setState(() => _audience = v), isLight),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Priority', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('Standard', _priority, (v) => setState(() => _priority = v), isLight),
                    _buildChip('Urgent', _priority, (v) => setState(() => _priority = v), isLight),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Delivery Timing', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('Send now', _timing, (v) => setState(() => _timing = v), isLight),
                    _buildChip('Schedule', _timing, (v) => setState(() => _timing = v), isLight),
                  ],
                ),
                if (_timing == 'Schedule') ...[
                  const SizedBox(height: 16),
                  Text('Days of week', style: TextStyle(fontSize: 14, color: secondaryTextColor)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekdays.map((day) {
                      final isSelected = _selectedWeekdays.contains(day);
                      return FilterChip(
                        label: Text(day.substring(0, 3)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedWeekdays.add(day);
                            } else {
                              if (_selectedWeekdays.length > 1) {
                                _selectedWeekdays.remove(day);
                              }
                            }
                          });
                        },
                        selectedColor: AppTheme.primaryIndigo.withOpacity(0.2),
                        backgroundColor: isLight ? Colors.white : AppTheme.surface,
                        checkmarkColor: AppTheme.primaryIndigo,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: _selectedTime);
                            if (time != null) setState(() => _selectedTime = time);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Time',
                              labelStyle: TextStyle(color: secondaryTextColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(_selectedTime.format(context), style: TextStyle(color: textColor)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                Text('On tap, open:', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _onTapRoutes.contains(_onTap) ? _onTap : 'App home',
                      isExpanded: true,
                      dropdownColor: isLight ? AppTheme.surfaceLight : AppTheme.surface,
                      items: _onTapRoutes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _onTap = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text('Banner Image (optional)', style: TextStyle(fontSize: 16, color: secondaryTextColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Required: 1080 x 540 px (±10 px). Landscape format.', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                const SizedBox(height: 12),
                if (_bannerImageBytes != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_bannerImageBytes!, height: 100, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() { _bannerImageBytes = null; _bannerImageName = null; }),
                        icon: const Icon(Icons.delete, color: AppTheme.error, size: 16),
                        label: const Text('Remove Image', style: TextStyle(color: AppTheme.error)),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickBannerImage,
                    icon: const Icon(Icons.upload_rounded, color: AppTheme.primaryIndigo),
                    label: const Text('Upload Banner\nImage', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primaryIndigo)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    ),
                  ),
                const SizedBox(height: 32),

                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_titleCtrl.text.isNotEmpty && _messageCtrl.text.isNotEmpty && !_isSubmitting) ? _submitNotification : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_titleCtrl.text.isNotEmpty && _messageCtrl.text.isNotEmpty) ? AppTheme.primaryIndigo : Colors.grey.shade300,
                      foregroundColor: (_titleCtrl.text.isNotEmpty && _messageCtrl.text.isNotEmpty) ? Colors.white : Colors.black54,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.black38,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Send\nnotification', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Pane: Live Preview
        Expanded(
          flex: 45,
          child: Container(
            color: isLight ? Colors.grey.shade100 : Colors.grey.shade900,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryIndigo,
                  unselectedLabelColor: secondaryTextColor,
                  indicatorColor: AppTheme.primaryIndigo,
                  tabs: const [
                    Tab(text: 'Live Preview'),
                    Tab(text: 'History'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLivePreview(isLight),
                      _buildHistory(isLight),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickBannerImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _bannerImageBytes = result.files.single.bytes;
        _bannerImageName = result.files.single.name;
      });
    }
  }

  Future<void> _submitNotification() async {
    if (_titleCtrl.text.isEmpty || _messageCtrl.text.isEmpty) return;

    DateTime? finalSchedule;
    List<String>? finalRecurringDays;
    String? finalTimeString;

    if (_timing == 'Schedule') {
      finalRecurringDays = _selectedWeekdays;
      finalTimeString = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    } else {
      finalSchedule = DateTime.now();
    }

    setState(() => _isSubmitting = true);

    try {
      String bannerUrl = '';
      if (_bannerImageBytes != null && _bannerImageName != null) {
        final url = await PushNotificationService.uploadBannerImage(_bannerImageBytes!, '${DateTime.now().millisecondsSinceEpoch}_$_bannerImageName');
        if (url != null) bannerUrl = url;
      }

      await PushNotificationService.scheduleNotification(
        title: _titleCtrl.text.trim(),
        body: _messageCtrl.text.trim(),
        scheduledTime: finalSchedule,
        recurringWeekdays: finalRecurringDays,
        scheduledTimeOfDay: finalTimeString,
        targetAudience: _audience,
        priority: _priority,
        onTapAction: _onTap,
        bannerImageUrl: bannerUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification scheduled successfully!')));
        setState(() {
          _titleCtrl.clear();
          _messageCtrl.clear();
          _audience = 'All users';
          _priority = 'Standard';
          _timing = 'Send now';
          _onTap = 'App home';
          _bannerImageBytes = null;
          _bannerImageName = null;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to schedule: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isLight, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withOpacity(0.5))),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildChip(String label, String groupValue, ValueChanged<String> onSelected, bool isLight) {
    final isSelected = label == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onSelected(label);
      },
      selectedColor: AppTheme.primaryIndigo.withOpacity(0.2),
      backgroundColor: isLight ? Colors.white : AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryIndigo : (isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppTheme.primaryIndigo : Colors.grey.withOpacity(0.5)),
      ),
      showCheckmark: label == 'All users' && isSelected, // Checkmark only for All users as per screenshot
    );
  }

  Widget _buildLivePreview(bool isAppLight) {
    // The preview itself has a theme toggle
    final previewBg = _previewDarkTheme ? Colors.black : Colors.white;
    final previewText = _previewDarkTheme ? Colors.white : Colors.black;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Theme:', style: TextStyle(color: isAppLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
              const SizedBox(width: 8),
              Switch(
                value: _previewDarkTheme,
                onChanged: (v) => setState(() => _previewDarkTheme = v),
                activeColor: Colors.black,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 300,
            height: 600,
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.grey.shade400, width: 4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('3:07', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: previewText, height: 1.0)),
                const SizedBox(height: 8),
                Text('Saturday, Sep 12', style: TextStyle(fontSize: 18, color: previewText.withOpacity(0.7))),
                const SizedBox(height: 32),
                if (_titleCtrl.text.isNotEmpty || _messageCtrl.text.isNotEmpty || _bannerImageBytes != null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _previewDarkTheme ? const Color(0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryIndigo,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.nights_stay, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 6),
                              Text('Sleep Astra', style: TextStyle(fontSize: 12, color: _previewDarkTheme ? Colors.white70 : Colors.black54)),
                              const Spacer(),
                              Text('now', style: TextStyle(fontSize: 12, color: _previewDarkTheme ? Colors.white70 : Colors.black54)),
                            ],
                          ),
                        ),
                        // Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_titleCtrl.text.isNotEmpty)
                                Text(_titleCtrl.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: previewText)),
                              if (_titleCtrl.text.isNotEmpty && _messageCtrl.text.isNotEmpty)
                                const SizedBox(height: 4),
                              if (_messageCtrl.text.isNotEmpty)
                                Text(_messageCtrl.text, style: TextStyle(color: previewText.withOpacity(0.9), fontSize: 13, height: 1.3)),
                            ],
                          ),
                        ),
                        // Banner Image
                        if (_bannerImageBytes != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                            child: Image.memory(
                              _bannerImageBytes!, 
                              width: double.infinity, 
                              height: 120, 
                              fit: BoxFit.cover
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Text(
                      'Your preview\nappears here',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: previewText.withOpacity(0.3)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(bool isLight) {
    return StreamBuilder<List<PushNotificationModel>>(
      stream: PushNotificationService.watchNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
        }
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return Center(
            child: Text(
              'No notifications sent yet.',
              style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notif = notifications[index];
            return Card(
              color: isLight ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(notif.title, style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Status: ${notif.status} • Scheduled: ${notif.scheduledTime != null ? DateFormat('MMM dd, hh:mm a').format(notif.scheduledTime!) : (notif.recurringWeekdays?.join(", ") ?? "") + " at " + (notif.scheduledTimeOfDay ?? "")}', style: TextStyle(fontSize: 12, color: AppTheme.primaryIndigo)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: (Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated),
                        title: Text('Delete Notification', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                        content: Text('Are you sure you want to delete this scheduled notification?', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)))),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await PushNotificationService.deleteNotification(notif.id);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

