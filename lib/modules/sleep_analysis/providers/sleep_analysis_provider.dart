import 'dart:async';
import 'dart:isolate';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/sleep_report.dart';
import '../services/audio_analyzer_service.dart';
import '../services/sleep_storage_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/recording_logger.dart';

enum AnalysisState { idle, recording, analysing, done, error }

class SleepAnalysisProvider extends ChangeNotifier {

  final SleepStorageService _storage = SleepStorageService();

  AnalysisState _state = AnalysisState.idle;
  SleepReport? _report;
  List<SleepReport> _history = [];
  String? _errorMessage;
  String? _pickedFileName;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  DateTime? _explicitStartTime;

  void setExplicitStartTime(DateTime time) {
    _explicitStartTime = time;
  }
  String? _pendingFilePath;
  String? _currentUid;
  double _currentAmplitude = 0.0;

  // ── Getters ──────────────────────────────────────────────
  AnalysisState get state => _state;
  SleepReport? get report => _report;
  String? get errorMessage => _errorMessage;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;
  String? get pickedFileName => _pickedFileName;
  bool get hasFile => _pendingFilePath != null;
  List<SleepReport> get history => _history;
  double get currentAmplitude => _currentAmplitude;

  // ── Public API ───────────────────────────────────────────

  /// Call this after picking a file
  void setPickedFile(String path, String fileName) {
    _pendingFilePath = path;
    _pickedFileName = fileName;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  void setRecordingActive(bool active) {
    _isRecording = active;
    if (active) {
      _state = AnalysisState.recording;
      _recordingDuration = Duration.zero;
    }
    notifyListeners();
  }

  void updateRecordingDuration(Duration d) {
    _recordingDuration = d;
    notifyListeners();
  }

  void updateAmplitude(double amp) {
    _currentAmplitude = amp;
    notifyListeners();
  }

  /// Call after recording stops
  void setRecordedFile(String path, String fileName) {
    _pendingFilePath = path;
    _pickedFileName = fileName;
    _isRecording = false;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  Future<SleepReport?> analyzeCurrentFile({
    required int goalMinutes,
    bool healthIntegrationEnabled = false,
  }) async {
    if (_state == AnalysisState.analysing) {
      debugPrint('[Analysis] Prevented duplicate analysis call');
      return null;
    }
    if (_pendingFilePath == null) {
      debugPrint('[Analysis] No pending file — nothing to analyze');
      return null;
    }
    _state = AnalysisState.analysing;
    _errorMessage = null;
    notifyListeners();

    try {
      final path = _pendingFilePath!;
      final name = _pickedFileName ?? 'recording.pcm';
      final startTime = _explicitStartTime ?? DateTime.now().subtract(_recordingDuration);
      _explicitStartTime = null; // reset after use

      RecordingLogger().info('Starting analysis of file: $path (Duration: $_recordingDuration)');
      debugPrint('[Analysis] Starting analysis of file: $path');

      final actualDur = _recordingDuration > Duration.zero ? _recordingDuration : null;
      final timeoutMinutes = 5 + ((actualDur?.inHours ?? 8) * 5);
      final analysisTimeout = Duration(minutes: timeoutMinutes.clamp(5, 180));

      final report = await Isolate.run(() async {
        final svc = AudioAnalyzerService();
        return await svc.analyzeFile(
          path,
          name,
          goalMinutes: goalMinutes,
          actualDuration: actualDur,
          recordedAt: startTime, // Bug F fix: use actual sleep start time
        );
      }).timeout(analysisTimeout, onTimeout: () {
        throw TimeoutException('Analysis took too long. The recording may be corrupted or in an unsupported format. Please try a PCM or M4A file.');
      });

      // Fetch health data if enabled
      SleepReport finalReport = report;
      if (healthIntegrationEnabled) {
        final endTime = startTime.add(report.totalDuration);
        final avgHeartRate = await HealthService().getAverageHeartRate(startTime, endTime);
        final steps = await HealthService().getStepCount(
          startTime.subtract(const Duration(hours: 12)),
          startTime,
        );

        // Bug E fix: do NOT mutate report.insights (final List);
        // instead build a new list and create a fresh SleepReport copy.
        if (avgHeartRate != null || steps != null) {
          final healthInsight = SleepInsight(
            title: 'Health Correlation',
            description: 'Your heart rate averaged ${avgHeartRate?.toInt() ?? "--"} bpm during sleep. '
                '${steps != null ? "You took $steps steps today." : ""}',
            emoji: '🩺',
          );
          finalReport = SleepReport(
            fileName: report.fileName,
            recordedAt: report.recordedAt,
            totalDuration: report.totalDuration,
            snoringDuration: report.snoringDuration,
            snoringEventCount: report.snoringEventCount,
            qualityScore: report.qualityScore,
            quality: report.quality,
            snoringEvents: report.snoringEvents,
            amplitudeTimeline: report.amplitudeTimeline,
            insights: [...report.insights, healthInsight],
            sleepDebtHours: report.sleepDebtHours,
            lightSleepPercent: report.lightSleepPercent,
            deepSleepPercent: report.deepSleepPercent,
            remSleepPercent: report.remSleepPercent,
            apneaRiskLevel: report.apneaRiskLevel,
            cpapUsageDuration: report.cpapUsageDuration,
          );
        }
      }

      _report = finalReport;
      _state = AnalysisState.done;
      RecordingLogger().info('Analysis successful. Snoring duration: ${report.snoringDuration.inSeconds}s, Quality: ${report.quality.name}');

      // ── Save to Firestore ──────────────────────────────────────────
      // Always use the Firebase Auth UID at save-time (most authoritative).
      // Fall back to the cached device UID only if auth is not available.
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
      final saveUid = firebaseUid ?? _currentUid ?? await FirestoreService.deviceUid;
      
      debugPrint('[Analysis] Saving report to Firestore. firebaseUid=$firebaseUid, saveUid=$saveUid');
      
      await _storage.saveReport(saveUid, _report!);
      
      // Reload history from Firestore with the same UID
      _history = await _storage.getAllReports(saveUid);
      _currentUid = saveUid;

      notifyListeners();
      return _report;
    } catch (e, stack) {
      RecordingLogger().error('Analysis provider error', e, stack);
      debugPrint('[Analysis] Error: $e');
      _state = AnalysisState.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }


  Future<void> loadHistory(String uid) async {
    _currentUid = uid;
    // Reset active report and state when switching user context
    _report = null;
    _state = AnalysisState.idle;
    _isRecording = false;
    _history = await _storage.getAllReports(uid);
    notifyListeners();
  }

  Future<void> deleteFromHistory(SleepReport report) async {
    if (_currentUid == null) return;
    await _storage.deleteReport(_currentUid!, report.recordedAt);
    await loadHistory(_currentUid!);
  }

  void reset() {
    _currentUid = null;
    _state = AnalysisState.idle;
    _report = null;
    _errorMessage = null;
    _pickedFileName = null;
    _pendingFilePath = null;
    _isRecording = false;
    _recordingDuration = Duration.zero;
    notifyListeners();
  }
}
