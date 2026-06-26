import 'package:flutter/foundation.dart';
import '../models/sleep_report.dart';
import '../../../core/services/firestore_service.dart';

/// Handles persistence of sleep reports — now backed by Firestore.
import 'package:shared_preferences/shared_preferences.dart';

class SleepStorageService {
  Future<void> saveReport(String uid, SleepReport report) async {
    await FirestoreService.saveReport(uid, report);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bug C fix: do NOT manually include 'flutter.' — SharedPreferences adds it internally.
      // The old key 'flutter.latest_sleep_score' was stored as 'flutter.flutter.latest_sleep_score'
      // and could never be read back with prefs.getInt().
      await prefs.setInt('latest_sleep_score', report.qualityScore.toInt());
    } catch (_) {}
  }

  Future<List<SleepReport>> getAllReports(String uid) async {
    try {
      return await FirestoreService.getAllReports(uid);
    } catch (e) {
      debugPrint('[SleepStorageService] getAllReports error: $e');
      return [];
    }
  }

  Future<void> deleteReport(String uid, DateTime recordedAt) async {
    try {
      await FirestoreService.deleteReport(uid, recordedAt);
    } catch (e) {
      debugPrint('[SleepStorageService] deleteReport error: $e');
    }
  }
}
