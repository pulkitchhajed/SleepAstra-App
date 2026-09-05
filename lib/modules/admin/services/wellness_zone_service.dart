import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wellness_zone_model.dart';

class WellnessZoneService {
  static final _db = FirebaseFirestore.instance;
  static final _col = _db.collection('wellness_zones');

  static bool _ensuredDefaults = false;

  /// Stream all zones, ordered by the `order` field, then by `createdAt`.
  static Stream<List<WellnessZoneModel>> watchZones() {
    return _col.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WellnessZoneModel.fromJson(doc.id, doc.data()))
          .toList();
      list.sort((a, b) {
        final orderComp = a.order.compareTo(b.order);
        if (orderComp != 0) return orderComp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
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

  /// Update an existing zone (name, contentTypes)
  static Future<void> updateZone({
    required String id,
    required String name,
    required List<String> contentTypes,
  }) async {
    await _col.doc(id).update({
      'name': name,
      'contentTypes': contentTypes,
    });
  }

  /// Update zone order (for drag-and-drop)
  static Future<void> updateZoneOrder(String id, int newOrder) async {
    await _col.doc(id).update({'order': newOrder});
  }

  static const List<Map<String, dynamic>> defaultZonesList = [
    {'name': 'Meditation', 'types': ['audio', 'video'], 'order': 0},
    {'name': 'Sleep Sounds', 'types': ['audio'], 'order': 1},
    {'name': 'Breathwork', 'types': ['audio', 'video'], 'order': 2},
    {'name': 'Music', 'types': ['audio'], 'order': 3},
    {'name': 'Yoga', 'types': ['video'], 'order': 4},
    {'name': 'Sleep Tips', 'types': ['blog'], 'order': 5},
    {'name': 'Wellness', 'types': ['blog', 'audio', 'video'], 'order': 6},
    {'name': 'Research', 'types': ['blog'], 'order': 7},
    {'name': 'Stories', 'types': ['blog'], 'order': 8},
    {'name': 'Nutrition', 'types': ['blog'], 'order': 9},
    {'name': 'Exercise', 'types': ['blog', 'video'], 'order': 10},
    {'name': 'Wellness Videos', 'types': ['video'], 'order': 11},
  ];

  /// Ensure all default zones exist in Firestore without duplicating
  static Future<void> ensureDefaultZones() async {
    try {
      final existing = await _col.get();
      final existingNames = existing.docs
          .map((d) => d.data()['name']?.toString().toLowerCase().trim() ?? '')
          .toSet();

      for (int i = 0; i < defaultZonesList.length; i++) {
        final z = defaultZonesList[i];
        final name = z['name'] as String;
        if (!existingNames.contains(name.toLowerCase().trim())) {
          await createZone(
            name: name,
            contentTypes: List<String>.from(z['types'] as List),
            order: existing.docs.length + i,
          );
        }
      }
    } catch (_) {}
  }

  /// One-time backfill of legacy hardcoded categories into Zones
  static Future<void> backfillDefaultZones() async {
    await ensureDefaultZones();
  }
}

