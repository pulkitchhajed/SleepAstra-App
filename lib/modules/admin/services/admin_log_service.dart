import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to record and stream administrator activity audit logs.
class AdminLogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _col = _db.collection('admin_logs');

  /// Records an administrative action to Firestore /admin_logs.
  static Future<void> logActivity({
    required String action,
    String? email,
    String? details,
  }) async {
    try {
      final effectiveEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim().toLowerCase()
          : (FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? 'system');

      await _col.add({
        'action': action,
        'email': effectiveEmail,
        'details': details ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'app',
      });
      debugPrint('[AdminLogService] Activity logged: $action by $effectiveEmail');
    } catch (e) {
      debugPrint('[AdminLogService] Failed to log activity: $e');
    }
  }

  /// Streams the most recent 150 audit logs ordered by newest first.
  static Stream<List<AdminLogEntry>> watchLogs() {
    return _col
        .orderBy('timestamp', descending: true)
        .limit(150)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AdminLogEntry.fromFirestore(doc)).toList();
    });
  }
}

class AdminLogEntry {
  final String id;
  final String action;
  final String email;
  final String details;
  final DateTime timestamp;
  final String platform;

  AdminLogEntry({
    required this.id,
    required this.action,
    required this.email,
    required this.details,
    required this.timestamp,
    required this.platform,
  });

  factory AdminLogEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['timestamp'];
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      dt = DateTime.now();
    }
    return AdminLogEntry(
      id: doc.id,
      action: data['action'] as String? ?? 'Action',
      email: data['email'] as String? ?? 'Unknown',
      details: data['details'] as String? ?? '',
      timestamp: dt,
      platform: data['platform'] as String? ?? 'unknown',
    );
  }
}
