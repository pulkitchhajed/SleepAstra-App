import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/sleep_report.dart';
import '../services/audio_analyzer_service.dart';
import '../services/sleep_storage_service.dart';
import '../services/actigraphy_service.dart';
import '../services/audio_storage_service.dart';
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
  bool _wasInterrupted = false;

  void setExplicitStartTime(DateTime time) {
    _explicitStartTime = time;
  }
  String? _pendingFilePath;
  String? _currentUid;
  double _currentAmplitude = 0.0;
  bool _isAppRecording = false; // true only when the app itself recorded the file

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
  /// True if the last recording session was interrupted by a phone call or
  /// another app that took over the microphone.
  bool get wasInterrupted => _wasInterrupted;

  // ── Public API ───────────────────────────────────────────

  /// Call this after picking a file from the file manager (do NOT auto-delete)
  void setPickedFile(String path, String fileName) {
    _pendingFilePath = path;
    _pickedFileName = fileName;
    _isAppRecording = false;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  /// Checks SharedPreferences and FlutterForegroundTask to see if an active recording session is underway.
  /// Restores _isRecording, _state, _recordingDuration, and _explicitStartTime if active.
  Future<bool> checkAndRestoreActiveRecordingState() async {
    if (kIsWeb) return _isRecording;

    try {
      final prefs = await SharedPreferences.getInstance();
      final activePath = prefs.getString('active_recording_path');
      final startMs = prefs.getInt('active_recording_start_ms');

      final bool serviceRunning = await FlutterForegroundTask.isRunningService;

      if (activePath != null && File(activePath).existsSync() && (serviceRunning || _isRecording)) {
        _isRecording = true;
        _state = AnalysisState.recording;
        if (startMs != null) {
          final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
          _explicitStartTime = startTime;
          _recordingDuration = DateTime.now().difference(startTime);
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[SleepAnalysisProvider] Error checking active recording state: $e');
    }

    return _isRecording;
  }

  /// Marks recording as active/inactive WITHOUT resetting duration.
  /// Call [resetRecordingState] first when starting a brand-new recording.
  void setRecordingActive(bool active) {
    _isRecording = active;
    _state = active ? AnalysisState.recording : AnalysisState.idle;
    if (!active) {
      // Clear the start time so it is not accidentally reused by the next session
      _explicitStartTime = null;
    }
    notifyListeners();
  }

  /// Resets duration and state for a brand-new recording session.
  /// Must be called BEFORE starting the recorder so restored values from a
  /// previous crash-recovery path are not accidentally carried over.
  void resetRecordingState() {
    _recordingDuration = Duration.zero;
    _explicitStartTime = null;
    _wasInterrupted = false;
    _state = AnalysisState.recording;
    _isRecording = true;
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

  /// Mark whether the current recording session has been interrupted by an
  /// external audio event (phone call, other app taking the microphone).
  void setInterrupted(bool interrupted) {
    _wasInterrupted = interrupted;
    notifyListeners();
  }

  /// Call after recording stops (marks file as auto-deletable)
  void setRecordedFile(String path, String fileName) {
    _pendingFilePath = path;
    _pickedFileName = fileName;
    _isAppRecording = true;
    _isRecording = false;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  Future<SleepReport?> analyzeCurrentFile({
    required int goalMinutes,
    bool healthIntegrationEnabled = false,
    List<SleepMotionSample> motionSamples = const [],
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

      // Load ML Model buffer on main thread because rootBundle doesn't work in isolates
      Uint8List? modelBuffer;
      try {
        final byteData = await rootBundle.load('assets/models/yamnet.tflite');
        modelBuffer = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      } catch (e) {
        debugPrint('[Analysis] Failed to load YAMNet model buffer: $e');
      }

      final report = await Isolate.run(() async {
        final svc = AudioAnalyzerService();
        return await svc.analyzeFile(
          path,
          name,
          goalMinutes: goalMinutes,
          actualDuration: actualDur,
          recordedAt: startTime, // Bug F fix: use actual sleep start time
          modelBuffer: modelBuffer,
        );
      }).timeout(analysisTimeout, onTimeout: () {
        throw TimeoutException('Analysis took too long. The recording may be corrupted or in an unsupported format. Please try a PCM or M4A file.');
      });

      // Apply actigraphy stage refinement if motion data is available
      SleepReport baseReport = report;
      if (motionSamples.isNotEmpty) {
        final refinedTimeline = ActigraphyService.refineStages(
          report.amplitudeTimeline,
          motionSamples,
        );
        baseReport = SleepReport(
          fileName: report.fileName,
          recordedAt: report.recordedAt,
          totalDuration: report.totalDuration,
          snoringDuration: report.snoringDuration,
          snoringEventCount: report.snoringEventCount,
          qualityScore: report.qualityScore,
          quality: report.quality,
          snoringEvents: report.snoringEvents,
          amplitudeTimeline: refinedTimeline,
          insights: report.insights,
          sleepDebtHours: report.sleepDebtHours,
          lightSleepPercent: report.lightSleepPercent,
          deepSleepPercent: report.deepSleepPercent,
          remSleepPercent: report.remSleepPercent,
          apneaRiskLevel: report.apneaRiskLevel,
          cpapUsageDuration: report.cpapUsageDuration,
          detectedApneaEvents: report.detectedApneaEvents,
          apneaHypopneaIndex: report.apneaHypopneaIndex,
          motionTimeline: motionSamples,
          actigraphyAvailable: true,
          snoreAudioClips: report.snoreAudioClips, // preserve clips
        );
        RecordingLogger().info('Actigraphy stage refinement applied to ${refinedTimeline.length} windows.');
      }

      // Fetch health data if enabled
      SleepReport finalReport = baseReport;
      if (healthIntegrationEnabled) {
        final endTime = startTime.add(baseReport.totalDuration);
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
            emoji: '\u{1FA7A}',
          );
          finalReport = SleepReport(
            fileName: baseReport.fileName,
            recordedAt: baseReport.recordedAt,
            totalDuration: baseReport.totalDuration,
            snoringDuration: baseReport.snoringDuration,
            snoringEventCount: baseReport.snoringEventCount,
            qualityScore: baseReport.qualityScore,
            quality: baseReport.quality,
            snoringEvents: baseReport.snoringEvents,
            amplitudeTimeline: baseReport.amplitudeTimeline,
            insights: [...baseReport.insights, healthInsight],
            sleepDebtHours: baseReport.sleepDebtHours,
            lightSleepPercent: baseReport.lightSleepPercent,
            deepSleepPercent: baseReport.deepSleepPercent,
            remSleepPercent: baseReport.remSleepPercent,
            apneaRiskLevel: baseReport.apneaRiskLevel,
            cpapUsageDuration: baseReport.cpapUsageDuration,
            detectedApneaEvents: baseReport.detectedApneaEvents,
            apneaHypopneaIndex: baseReport.apneaHypopneaIndex,
            motionTimeline: baseReport.motionTimeline,
            actigraphyAvailable: baseReport.actigraphyAvailable,
            snoreAudioClips: baseReport.snoreAudioClips, // preserve clips
          );
        }
      }

      // ── Snore Audio Extraction ──────────────────────────────────────────
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
      final saveUid = firebaseUid ?? _currentUid ?? await FirestoreService.deviceUid;
      
      List<SnoreAudioClip> snoreClips = [];
      
      if (finalReport.snoringEvents.isNotEmpty) {
        RecordingLogger().info('Extracting snore audio clips...');
        final localClips = await AudioAnalyzerService().extractSnoreAudio(
          path, 
          finalReport.snoringEvents,
          actualDuration: finalReport.totalDuration,
        );
        
        if (localClips.isNotEmpty) {
          snoreClips = await AudioStorageService.uploadSnoreAudioClips(saveUid, localClips, startTime);
        }
      }

      // ── Delete raw PCM to free space (only if app created it) ──────────────────
      if (_isAppRecording) {
        try {
          final rawFile = File(path);
          if (rawFile.existsSync()) {
            rawFile.deleteSync();
            RecordingLogger().info('Deleted raw recording to free space: $path');
          }
        } catch (e) {
          RecordingLogger().error('Could not delete raw recording', e);
        }
      }

      // Add audio paths to final report
      finalReport = SleepReport(
        fileName: finalReport.fileName,
        recordedAt: finalReport.recordedAt,
        totalDuration: finalReport.totalDuration,
        snoringDuration: finalReport.snoringDuration,
        snoringEventCount: finalReport.snoringEventCount,
        qualityScore: finalReport.qualityScore,
        quality: finalReport.quality,
        snoringEvents: finalReport.snoringEvents,
        amplitudeTimeline: finalReport.amplitudeTimeline,
        insights: finalReport.insights,
        sleepDebtHours: finalReport.sleepDebtHours,
        lightSleepPercent: finalReport.lightSleepPercent,
        deepSleepPercent: finalReport.deepSleepPercent,
        remSleepPercent: finalReport.remSleepPercent,
        apneaRiskLevel: finalReport.apneaRiskLevel,
        cpapUsageDuration: finalReport.cpapUsageDuration,
        detectedApneaEvents: finalReport.detectedApneaEvents,
        apneaHypopneaIndex: finalReport.apneaHypopneaIndex,
        motionTimeline: finalReport.motionTimeline,
        actigraphyAvailable: finalReport.actigraphyAvailable,
        snoreAudioClips: snoreClips,
      );

      _report = finalReport;
      _state = AnalysisState.done;
      RecordingLogger().info('Analysis successful. Snoring duration: ${finalReport.snoringDuration.inSeconds}s, Quality: ${finalReport.quality.name}, ML active: ${modelBuffer != null}');

      // ── Save to Firestore ──────────────────────────────────────────
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
    await _storage.deleteReport(_currentUid!, report);
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
    _wasInterrupted = false;
    notifyListeners();
  }
}
