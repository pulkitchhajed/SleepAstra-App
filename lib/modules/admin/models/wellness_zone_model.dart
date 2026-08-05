import 'package:cloud_firestore/cloud_firestore.dart';

class WellnessZoneModel {
  final String id;
  final String name;
  final List<String> contentTypes; // 'audio', 'video', 'blog'
  final int order;
  final DateTime createdAt;

  const WellnessZoneModel({
    required this.id,
    required this.name,
    required this.contentTypes,
    this.order = 0,
    required this.createdAt,
  });

  factory WellnessZoneModel.fromJson(String id, Map<String, dynamic> data) {
    return WellnessZoneModel(
      id: id,
      name: data['name'] as String? ?? 'Unnamed Zone',
      contentTypes: List<String>.from(data['contentTypes'] as List? ?? []),
      order: data['order'] as int? ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'contentTypes': contentTypes,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
