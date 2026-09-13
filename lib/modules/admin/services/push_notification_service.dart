import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/push_notification_model.dart';

class PushNotificationService {
  static final CollectionReference _collection =
      FirebaseFirestore.instance.collection('scheduled_notifications');

  static Stream<List<PushNotificationModel>> watchNotifications() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PushNotificationModel.fromFirestore(doc))
            .toList());
  }

  static Future<String?> uploadBannerImage(Uint8List imageBytes, String fileName) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('notification_banners/$fileName');
      final uploadTask = await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg')).timeout(const Duration(seconds: 15));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading banner image: $e');
      return null;
    }
  }

  static Future<void> scheduleNotification({
    required String title,
    required String body,
    DateTime? scheduledTime,
    List<String>? recurringWeekdays,
    String? scheduledTimeOfDay,
    String targetAudience = 'All users',
    String priority = 'Standard',
    String onTapAction = 'App home',
    String bannerImageUrl = '',
  }) async {
    final isRecurring = recurringWeekdays != null && recurringWeekdays.isNotEmpty;
    final map = {
      'title': title,
      'body': body,
      'targetAudience': targetAudience,
      'priority': priority,
      'onTapAction': onTapAction,
      'bannerImageUrl': bannerImageUrl,
      'status': isRecurring ? 'recurring' : 'pending',
      'clientTimezoneOffset': DateTime.now().timeZoneOffset.inMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (scheduledTime != null) {
      map['scheduledTime'] = Timestamp.fromDate(scheduledTime);
    }
    if (isRecurring) {
      map['recurringWeekdays'] = recurringWeekdays;
    }
    if (scheduledTimeOfDay != null) {
      map['scheduledTimeOfDay'] = scheduledTimeOfDay;
    }

    await _collection.add(map).timeout(const Duration(seconds: 15));
  }

  static Future<void> deleteNotification(String id) async {
    await _collection.doc(id).delete();
  }
}
