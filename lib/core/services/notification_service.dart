import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  tz.TZDateTime _nextInstanceOfTime(DateTime target) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, target.hour, target.minute
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleBedtimeReminder(DateTime bedtime) async {
    if (kIsWeb) return;
    await requestPermissions();
    final scheduledDate = _nextInstanceOfTime(bedtime);

    await _notifications.zonedSchedule(
      101,
      'Sleep Tracking Reminder',
      'It\'s your bedtime! Don\'t forget to turn on the snore recording before you sleep.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bedtime_reminders',
          'Bedtime Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleBackupAlarm(DateTime alarmTime) async {
    if (kIsWeb) return;
    await requestPermissions();
    final scheduledDate = _nextInstanceOfTime(alarmTime);

    await _notifications.zonedSchedule(
      103, // Unique ID for alarm
      'Wake Up!',
      'Tap to dismiss alarm and analyze your sleep.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarms',
          channelDescription: 'Alarm notifications',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleMorningPrompt(DateTime wakeTime) async {
    if (kIsWeb) return;
    await requestPermissions();
    final scheduledDate = _nextInstanceOfTime(wakeTime);

    await _notifications.zonedSchedule(
      102,
      'Good morning!',
      'How did you sleep? Log your morning journal to get AI insights.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_prompts',
          'Morning Prompts',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelBackupAlarm() async {
    if (kIsWeb) return;
    await _notifications.cancel(103);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }
}