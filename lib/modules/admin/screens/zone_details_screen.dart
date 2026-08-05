import 'package:flutter/material.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../models/wellness_zone_model.dart';
import 'upload_video_screen.dart';
import 'upload_blog_screen.dart';
import 'upload_audio_screen.dart';
import '../../videos/services/video_service.dart';
import '../../blogs/services/blog_service.dart';
import '../../audio/services/audio_track_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneDetailsScreen extends StatelessWidget {
  final WellnessZoneModel zone;
  const ZoneDetailsScreen({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${zone.name} Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchZoneContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
          }

          final content = snapshot.data ?? [];
          if (content.isEmpty) {
            return const Center(
              child: Text('No content in this zone yet.', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: content.length,
            itemBuilder: (context, index) {
              final item = content[index];
              return Card(
                color: AppTheme.surfaceElevated,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.circle, color: AppTheme.primaryIndigo, size: 12),
                  title: Text(item['title'], style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: Text('Type: ${item['type']}', style: const TextStyle(color: AppTheme.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.textSecondary),
                    onPressed: () {
                      // Navigate to appropriate edit screen (omitted for brevity, or can add later)
                      // The main goal is adding content to the zone.
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (zone.contentTypes.contains('video'))
            _buildFab(context, 'Add Video', Icons.video_call_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UploadVideoScreen(defaultCategory: zone.name)));
            }),
          if (zone.contentTypes.contains('blog')) ...[
            const SizedBox(height: 12),
            _buildFab(context, 'Add Blog', Icons.post_add_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UploadBlogScreen(defaultCategory: zone.name)));
            }),
          ],
          if (zone.contentTypes.contains('audio')) ...[
            const SizedBox(height: 12),
            _buildFab(context, 'Add Audio', Icons.audiotrack_rounded, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UploadAudioScreen(defaultCategory: zone.name)));
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    return FloatingActionButton.extended(
      heroTag: label,
      onPressed: onPressed,
      backgroundColor: AppTheme.primaryIndigo,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchZoneContent() async {
    final db = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> results = [];

    if (zone.contentTypes.contains('video')) {
      final snap = await db.collection('videos').where('category', isEqualTo: zone.name).get();
      results.addAll(snap.docs.map((d) => {'id': d.id, 'title': d['title'] ?? 'Untitled', 'type': 'video'}));
    }
    if (zone.contentTypes.contains('blog')) {
      final snap = await db.collection('blogs').where('category', isEqualTo: zone.name).get();
      results.addAll(snap.docs.map((d) => {'id': d.id, 'title': d['title'] ?? 'Untitled', 'type': 'blog'}));
    }
    if (zone.contentTypes.contains('audio')) {
      final snap = await db.collection('audio_tracks').where('category', isEqualTo: zone.name).get();
      results.addAll(snap.docs.map((d) => {'id': d.id, 'title': d['title'] ?? 'Untitled', 'type': 'audio'}));
    }

    return results;
  }
}
