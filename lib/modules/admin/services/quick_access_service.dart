import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quick_access_model.dart';
import '../../../core/router/app_router.dart';

class QuickAccessService {
  static final _db = FirebaseFirestore.instance.collection('quick_access');

  static Stream<List<QuickAccessModel>> watchItems() {
    return _db.orderBy('order').snapshots().map(
          (s) => s.docs.map((d) => QuickAccessModel.fromJson(d.id, d.data())).toList(),
        );
  }

  static Future<void> createItem({
    required String title,
    required String target,
    required String thumbnailUrl,
  }) async {
    final count = await _db.count().get();
    await _db.add({
      'title': title,
      'target': target,
      'thumbnailUrl': thumbnailUrl,
      'order': count.count ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateItem({
    required String id,
    required String title,
    required String target,
    required String thumbnailUrl,
  }) async {
    await _db.doc(id).update({
      'title': title,
      'target': target,
      'thumbnailUrl': thumbnailUrl,
    });
  }

  static Future<void> updateOrder(String id, int newOrder) async {
    await _db.doc(id).update({'order': newOrder});
  }

  static Future<void> deleteItem(String id) async {
    await _db.doc(id).delete();
  }

  static Future<void> ensureDefaultItems() async {
    final snap = await _db.limit(1).get();
    if (snap.docs.isEmpty) {
      final defaults = [
        {'title': 'Sleep Diary', 'target': AppRouter.sleepHistory, 'thumb': ''},
        {'title': 'Yoga', 'target': 'route:/wellness', 'thumb': ''},
        {'title': 'Meditation', 'target': AppRouter.relaxation, 'thumb': ''},
        {'title': 'Snore Track', 'target': 'route:/snore_track', 'thumb': ''},
        {'title': 'Sleep Stages', 'target': 'route:/sleep_stages', 'thumb': ''},
      ];

      for (int i = 0; i < defaults.length; i++) {
        final d = defaults[i];
        await _db.add({
          'title': d['title'],
          'target': d['target'],
          'thumbnailUrl': d['thumb'],
          'order': i,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
