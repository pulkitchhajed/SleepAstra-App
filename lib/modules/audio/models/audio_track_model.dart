import 'package:cloud_firestore/cloud_firestore.dart';

class AudioTrackModel {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final String thumbnailUrl;
  final String duration;
  final String category;
  final DateTime createdAt;
  final String uploadedBy;

  const AudioTrackModel({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.category,
    required this.createdAt,
    required this.uploadedBy,
  });

  factory AudioTrackModel.fromJson(String id, Map<String, dynamic> data) {
    return AudioTrackModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      duration: data['duration'] as String? ?? '0:00',
      category: data['category'] as String? ?? 'Sleep Sounds',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      uploadedBy: data['uploadedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'audioUrl': audioUrl,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': uploadedBy,
      };
}
