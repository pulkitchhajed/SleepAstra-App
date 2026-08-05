import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wellness_zone_model.dart';

class WellnessZoneService {
  static final _db = FirebaseFirestore.instance;
  static final _col = _db.collection('wellness_zones');

  /// Stream all zones, ordered by the `order` field, then by `createdAt`.
  static Stream<List<WellnessZoneModel>> watchZones() {
    return _col
        .orderBy('order')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WellnessZoneModel.fromJson(doc.id, doc.data()))
            .toList());
  }

  /// Create a new zone
  static Future<void> createZone({
    required String name,
    required List<String> contentTypes,
    int order = 0,
  }) async {
    await _col.add({
      'name': name,
      'contentTypes': contentTypes,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a zone
  static Future<void> deleteZone(String id) async {
    await _col.doc(id).delete();
  }

  /// Update zone order (for drag-and-drop)
  static Future<void> updateZoneOrder(String id, int newOrder) async {
    await _col.doc(id).update({'order': newOrder});
  }

  /// One-time backfill of legacy hardcoded categories into Zones
  static Future<void> backfillDefaultZones() async {
    final existing = await _col.limit(1).get();
    if (existing.docs.isNotEmpty) return; // Only run if empty

    final defaultZones = [
      {'name': 'Meditation', 'types': ['audio', 'video'], 'order': 0},
      {'name': 'Sleep Sounds', 'types': ['audio'], 'order': 1},
      {'name': 'Breathwork', 'types': ['audio', 'video'], 'order': 2},
      {'name': 'Music', 'types': ['audio'], 'order': 3},
      {'name': 'Yoga', 'types': ['video'], 'order': 4},
    ];

    for (final z in defaultZones) {
      await createZone(
        name: z['name'] as String,
        contentTypes: z['types'] as List<String>,
        order: z['order'] as int,
      );
    }
  }
}

