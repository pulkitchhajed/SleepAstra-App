import 'package:cloud_firestore/cloud_firestore.dart';

class BlogModel {
  final String id;
  final String title;
  final String content;
  final String summary;
  final String coverImageUrl;
  final String category;
  final List<String> tags;
  final String author;
  final int readTimeMinutes;
  final DateTime createdAt;
  final String uploadedBy;
  final List<String> likes;
  final List<String> bookmarks;

  const BlogModel({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.coverImageUrl,
    required this.category,
    required this.tags,
    required this.author,
    required this.readTimeMinutes,
    required this.createdAt,
    required this.uploadedBy,
    this.likes = const [],
    this.bookmarks = const [],
  });

  factory BlogModel.fromJson(String id, Map<String, dynamic> data) {
    return BlogModel(
      id: id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      coverImageUrl: data['coverImageUrl'] as String? ?? '',
      category: data['category'] as String? ?? '',
      tags: List<String>.from(data['tags'] as List? ?? []),
      author: data['author'] as String? ?? '',
      readTimeMinutes: data['readTimeMinutes'] as int? ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      uploadedBy: data['uploadedBy'] as String? ?? '',
      likes: List<String>.from(data['likes'] as List? ?? []),
      bookmarks: List<String>.from(data['bookmarks'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'summary': summary,
        'coverImageUrl': coverImageUrl,
        'category': category,
        'tags': tags,
        'author': author,
        'readTimeMinutes': readTimeMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': uploadedBy,
        'likes': likes,
        'bookmarks': bookmarks,
      };
}
