import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final List<String> tags;
  final DateTime createdAt;
  final String uploadedBy;
  final List<String> likes;
  final List<String> useful;

  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.tags,
    required this.createdAt,
    required this.uploadedBy,
    this.likes = const [],
    this.useful = const [],
  });

  factory VideoModel.fromJson(String id, Map<String, dynamic> data) {
    return VideoModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      tags: List<String>.from(data['tags'] as List? ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      uploadedBy: data['uploadedBy'] as String? ?? '',
      likes: List<String>.from(data['likes'] as List? ?? []),
      useful: List<String>.from(data['useful'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': uploadedBy,
        'likes': likes,
        'useful': useful,
      };
}
