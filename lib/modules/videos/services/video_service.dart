import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/video_model.dart';

/// Cloudinary configuration.
class CloudinaryConfig {
  static const String cloudName = 'dqi1hruqe';
  static const String uploadPreset = 'Nidra Videos'; // unsigned preset
}

class VideoService {
  static final _db = FirebaseFirestore.instance;
  static final _videosCol = _db.collection('videos');

  // ─── Cloudinary Upload ────────────────────────────────────────────────────

  /// Uploads a video file to Cloudinary and returns its public URL.
  /// Reports progress via [onProgress] callback (0.0 – 1.0).
  static Future<Map<String, String>> uploadVideoToCloudinary(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/video/upload',
    );

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['resource_type'] = 'video'
      ..files.add(await http.MultipartFile.fromPath('file', videoFile.path));

    final streamedResponse = await request.send();

    // Track upload progress
    int bytesReceived = 0;
    final total = streamedResponse.contentLength ?? 1;
    final responseBytes = <int>[];

    await for (final chunk in streamedResponse.stream) {
      responseBytes.addAll(chunk);
      bytesReceived += chunk.length;
      onProgress?.call(bytesReceived / total);
    }

    final body = json.decode(utf8.decode(responseBytes)) as Map<String, dynamic>;

    if (streamedResponse.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${body['error']}');
    }

    final videoUrl = body['secure_url'] as String;
    // Generate thumbnail from Cloudinary's automatic thumbnail (replace extension)
    final thumbnailUrl = videoUrl
        .replaceAll('/video/upload/', '/video/upload/so_0,w_640,h_360,c_fill/')
        .replaceAll('.mp4', '.jpg')
        .replaceAll('.mov', '.jpg')
        .replaceAll('.avi', '.jpg');

    return {'videoUrl': videoUrl, 'thumbnailUrl': thumbnailUrl};
  }

  // ─── Firestore CRUD ───────────────────────────────────────────────────────

  /// Saves a new video document to the `videos` collection.
  static Future<void> saveVideo({
    required String title,
    required String description,
    required String videoUrl,
    required String thumbnailUrl,
    List<String> tags = const [],
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final id = const Uuid().v4();
      await _videosCol.doc(id).set({
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'tags': tags,
        'uploadedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[VideoService] saveVideo error: $e');
      rethrow;
    }
  }

  /// Updates an existing video document.
  static Future<void> updateVideo({
    required String id,
    required String title,
    required String description,
    required String videoUrl,
    required String thumbnailUrl,
    List<String> tags = const [],
  }) async {
    try {
      await _videosCol.doc(id).update({
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'tags': tags,
      });
    } catch (e) {
      debugPrint('[VideoService] updateVideo error: $e');
      rethrow;
    }
  }

  /// Toggles a reaction (likes or useful) for the current user.
  static Future<void> toggleReaction(String videoId, String field) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _videosCol.doc(videoId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final list = List<String>.from(data[field] as List? ?? []);
      
      if (list.contains(uid)) {
        await docRef.update({
          field: FieldValue.arrayRemove([uid])
        });
      } else {
        await docRef.update({
          field: FieldValue.arrayUnion([uid])
        });
      }
    } catch (e) {
      debugPrint('[VideoService] toggleReaction error: $e');
    }
  }

  /// Fetches all videos, newest first.
  static Stream<List<VideoModel>> watchVideos() {
    return _videosCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VideoModel.fromJson(d.id, d.data()))
            .toList());
  }

  /// Deletes a video document from Firestore.
  static Future<void> deleteVideo(String id) async {
    try {
      await _videosCol.doc(id).delete();
    } catch (e) {
      debugPrint('[VideoService] deleteVideo error: $e');
      rethrow;
    }
  }

  /// Seeds demo videos if the collection is empty.
  /// Call this once after user login.
  static Future<void> seedDemoVideos() async {
    try {
      final snap = await _videosCol.limit(1).get();
      if (snap.docs.isNotEmpty) return; // Already has content

      final now = DateTime.now();
      final demos = [
        {
          'id': 'demo-video-1',
          'title': 'Deep Sleep Meditation (10 Mins)',
          'description': 'A guided 10-minute meditation to help you relax and fall into a deep, restful sleep.',
          'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          'thumbnailUrl': 'https://images.unsplash.com/photo-1511295742362-92c96b124e52?w=600&h=400&fit=crop',
          'tags': ['meditation', 'sleep', 'guided'],
          'uploadedBy': 'system',
          'likes': [],
          'useful': [],
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        },
        {
          'id': 'demo-video-2',
          'title': 'Understanding Sleep Cycles',
          'description': 'Learn about the different stages of sleep and how they affect your energy levels and overall health.',
          'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          'thumbnailUrl': 'https://images.unsplash.com/photo-1541781774459-bb2af28430e4?w=600&h=400&fit=crop',
          'tags': ['education', 'science', 'health'],
          'uploadedBy': 'system',
          'likes': [],
          'useful': [],
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        },
        {
          'id': 'demo-video-3',
          'title': 'Relaxing Nature Sounds',
          'description': 'Wind down with the soothing sounds of a forest stream. Perfect for masking background noise.',
          'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
          'thumbnailUrl': 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=600&h=400&fit=crop',
          'tags': ['sounds', 'nature', 'relaxation'],
          'uploadedBy': 'system',
          'likes': [],
          'useful': [],
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
        },
      ];

      final batch = _db.batch();
      for (final d in demos) {
        final id = d['id'] as String;
        final data = Map<String, dynamic>.from(d)..remove('id');
        batch.set(_videosCol.doc(id), data);
      }
      await batch.commit();
      debugPrint('[VideoService] Seeded ${demos.length} demo videos');
    } catch (e) {
      debugPrint('[VideoService] seedDemoVideos error: $e');
    }
  }
}
