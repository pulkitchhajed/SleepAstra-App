import 'package:cloud_firestore/cloud_firestore.dart';

class QuickAccessModel {
  final String id;
  final String title;
  final String target;
  final String thumbnailUrl;
  final int order;
  final DateTime createdAt;

  const QuickAccessModel({
    required this.id,
    required this.title,
    required this.target,
    required this.thumbnailUrl,
    required this.order,
    required this.createdAt,
  });

  factory QuickAccessModel.fromJson(String id, Map<String, dynamic> data) {
    return QuickAccessModel(
      id: id,
      title: data['title'] as String? ?? '',
      target: data['target'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      order: data['order'] as int? ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'target': target,
        'thumbnailUrl': thumbnailUrl,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
