import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/sleep_report.dart';
import '../../../core/services/firestore_service.dart';
import 'audio_storage_service.dart';

/// Handles persistence of sleep reports — now backed by Firestore.

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
      final firestoreReports = await FirestoreService.getAllReports(uid);
      // Defensive mutable copy — Firestore list may be unmodifiable
      final reports = firestoreReports.toList();
      await _cleanOldAudio(uid, reports);
      return reports;
    } catch (e) {
      debugPrint('[SleepStorageService] getAllReports error: $e');
      return [];
    }
  }

  /// Automatically deletes snore audio files older than 7 days to save space.
  Future<void> _cleanOldAudio(String uid, List<SleepReport> reports) async {
    final now = DateTime.now();
    bool updatedAny = false;

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      final age = now.difference(report.recordedAt);
      
      if (age.inDays >= 7 && report.snoreAudioClips.isNotEmpty) {
        for (final clip in report.snoreAudioClips) {
          if (clip.localPath.isNotEmpty) {
            try {
              final file = File(clip.localPath);
              if (file.existsSync()) file.deleteSync();
            } catch (_) {}
          }
          if (clip.remoteUrl != null) {
            await AudioStorageService.deleteSnoreAudio(clip.remoteUrl!);
          }
        }

        // Create updated report without audio paths
        reports[i] = SleepReport(
          fileName: report.fileName,
          recordedAt: report.recordedAt,
          totalDuration: report.totalDuration,
          snoringDuration: report.snoringDuration,
          snoringEventCount: report.snoringEventCount,
          qualityScore: report.qualityScore,
          quality: report.quality,
          snoringEvents: report.snoringEvents,
          amplitudeTimeline: report.amplitudeTimeline,
          insights: report.insights,
          sleepDebtHours: report.sleepDebtHours,
          lightSleepPercent: report.lightSleepPercent,
          deepSleepPercent: report.deepSleepPercent,
          remSleepPercent: report.remSleepPercent,
          apneaRiskLevel: report.apneaRiskLevel,
          cpapUsageDuration: report.cpapUsageDuration,
          detectedApneaEvents: report.detectedApneaEvents,
          apneaHypopneaIndex: report.apneaHypopneaIndex,
          motionTimeline: report.motionTimeline,
          actigraphyAvailable: report.actigraphyAvailable,
          snoreAudioClips: const [], // Cleared
        );
        
        // Save the updated report back to Firestore
        await FirestoreService.saveReport(uid, reports[i]);
        updatedAny = true;
      }
    }
    if (updatedAny) {
      debugPrint('[SleepStorageService] Cleaned up snore audio older than 7 days.');
    }
  }

  Future<void> deleteReport(String uid, SleepReport report) async {
    try {
      // 1. Delete associated audio clips to prevent orphans
      for (final clip in report.snoreAudioClips) {
        if (clip.localPath.isNotEmpty) {
          try {
            final file = File(clip.localPath);
            if (file.existsSync()) file.deleteSync();
          } catch (_) {}
        }
        if (clip.remoteUrl != null) {
          await AudioStorageService.deleteSnoreAudio(clip.remoteUrl!);
        }
      }

      // 2. Delete the report document from Firestore
      await FirestoreService.deleteReport(uid, report.recordedAt);
    } catch (e) {
      debugPrint('[SleepStorageService] deleteReport error: $e');
    }
  }
}
