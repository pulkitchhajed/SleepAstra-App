import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime? scheduledTime;
  final String targetAudience;
  final String status;
  final String priority;
  final String onTapAction;
  final String bannerImageUrl;
  final DateTime createdAt;
  final List<String>? recurringWeekdays;
  final String? scheduledTimeOfDay;

  PushNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.scheduledTime,
    this.targetAudience = 'All users',
    this.status = 'pending',
    this.priority = 'Standard',
    this.onTapAction = 'App home',
    this.bannerImageUrl = '',
    required this.createdAt,
    this.recurringWeekdays,
    this.scheduledTimeOfDay,
  });

  factory PushNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PushNotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      targetAudience: data['targetAudience'] ?? 'All users',
      status: data['status'] ?? 'pending',
      priority: data['priority'] ?? 'Standard',
      onTapAction: data['onTapAction'] ?? 'App home',
      bannerImageUrl: data['bannerImageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recurringWeekdays: (data['recurringWeekdays'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      scheduledTimeOfDay: data['scheduledTimeOfDay'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'title': title,
      'body': body,
      'targetAudience': targetAudience,
      'status': status,
      'priority': priority,
      'onTapAction': onTapAction,
      'bannerImageUrl': bannerImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (scheduledTime != null) {
      map['scheduledTime'] = Timestamp.fromDate(scheduledTime!);
    }
    if (recurringWeekdays != null) {
      map['recurringWeekdays'] = recurringWeekdays!;
    }
    if (scheduledTimeOfDay != null) {
      map['scheduledTimeOfDay'] = scheduledTimeOfDay!;
    }
    return map;
  }
}
