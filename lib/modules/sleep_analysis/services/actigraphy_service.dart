import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sleep_report.dart';

/// Actigraphy Service — Accelerometer-based sleep stage refinement.
///
/// Uses the device accelerometer (via sensors_plus) to detect body movement
/// during sleep. The data is used to refine the audio-based sleep stage model:
///
///   Still (movement < threshold)   → Supports Deep/REM classification
///   Movement (movement > threshold) → Reclassifies window as Light / Awake
///
/// This is a companion to the audio-based analysis, not a replacement.
/// Motion data is collected in parallel with audio recording.
class ActigraphyService {
  // ── Movement thresholds ─────────────────────────────────────────────────
  /// Gravity constant (m/s²). When perfectly still, magnitude ≈ 9.81.
  static const double _gravity = 9.81;

  /// Movement above gravity (m/s²) to classify as "moving".
  /// 0.15 m/s² = subtle shifts; 0.5 m/s² = clear body repositioning.
  static const double _movingThreshold = 0.15;

  /// Vigorous movement threshold (m/s²) — likely awake.
  static const double _vigorousThreshold = 0.50;

  /// Window duration for motion aggregation.
  static const Duration _windowDuration = Duration(seconds: 3);

  // ── State ───────────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<SleepMotionSample> _samples = [];
  final List<double> _windowBuffer = []; // magnitude deviations in current window
  DateTime? _windowStart;
  DateTime? _recordingStart;
  bool _isRecording = false;

  /// Whether actigraphy data is actively being collected.
  bool get isRecording => _isRecording;

  /// Returns a copy of the collected motion samples.
  List<SleepMotionSample> get samples => List.unmodifiable(_samples);

  // ── Public API ──────────────────────────────────────────────────────────

  /// Start collecting accelerometer data.
  /// Call this when the sleep recording begins.
  Future<void> startRecording() async {
    if (_isRecording) return;
    _samples.clear();
    _windowBuffer.clear();
    _isRecording = true;
    _recordingStart = DateTime.now();
    _windowStart = DateTime.now();

    _subscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100), // 10 Hz
    ).listen(
      _onAccelerometerEvent,
      onError: (e) {
        // Silently fail — actigraphy is optional
        stopRecording();
      },
      cancelOnError: true,
    );
  }

  /// Stop collecting and return the list of motion samples.
  List<SleepMotionSample> stopRecording() {
    _isRecording = false;
    _subscription?.cancel();
    _subscription = null;

    // Flush any remaining buffer
    _flushWindow();

    return List.from(_samples);
  }

  // ── Internal ────────────────────────────────────────────────────────────

  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (!_isRecording) return;

    // Compute magnitude and deviation from gravity
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final deviation = (magnitude - _gravity).abs();
    _windowBuffer.add(deviation);

    // Check if window is complete
    final now = DateTime.now();
    if (_windowStart != null && now.difference(_windowStart!) >= _windowDuration) {
      _flushWindow();
      _windowStart = now;
    }
  }

  void _flushWindow() {
    if (_windowBuffer.isEmpty || _recordingStart == null) return;

    // Use 75th percentile deviation as the window's movement score
    // (robust against brief single-spike artifacts).
    final sorted = List<double>.from(_windowBuffer)..sort();
    final p75idx = ((sorted.length - 1) * 0.75).round().clamp(0, sorted.length - 1);
    final p75deviation = sorted[p75idx];

    final movementIntensity = (p75deviation / _vigorousThreshold).clamp(0.0, 1.0);
    // Use _windowStart time so motion sample aligns with its actual start window,
    // not the time the flush ran (which could be up to 3s later).
    final timeSeconds = (_windowStart ?? DateTime.now()).difference(_recordingStart!).inSeconds.toDouble();

    _samples.add(SleepMotionSample(
      timeSeconds: timeSeconds,
      magnitude: _gravity + p75deviation,
      movementIntensity: movementIntensity,
    ));

    _windowBuffer.clear();
  }

  // ── Stage Refinement ────────────────────────────────────────────────────

  /// Refines the audio-based amplitude timeline using actigraphy data.
  ///
  /// Rules:
  ///   - If motion says "vigorous" → reclassify as [SleepStage.awake]
  ///   - If motion says "moving"   → reclassify as [SleepStage.light]
  ///   - If motion says "still"    → preserve the audio-based stage
  ///   - Snoring windows are NEVER overridden by actigraphy.
  static List<AmplitudeSample> refineStages(
    List<AmplitudeSample> audioTimeline,
    List<SleepMotionSample> motionTimeline,
  ) {
    if (motionTimeline.isEmpty) return audioTimeline;

    return audioTimeline.map((sample) {
      // Never override confirmed snoring
      if (sample.isSnoring) return sample;

      // Find the closest motion sample in time
      SleepMotionSample? closest;
      double minDiff = double.infinity;
      for (final m in motionTimeline) {
        final diff = (m.timeSeconds - sample.timeSeconds).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = m;
        }
      }

      if (closest == null || minDiff > 10) return sample; // no close match

      // Apply actigraphy correction
      SleepStage refinedStage = sample.stage;
      if (closest.movementIntensity >= 1.0) {
        // Vigorous movement: almost certainly awake
        refinedStage = SleepStage.awake;
      } else if (closest.movementIntensity >= (_movingThreshold / _vigorousThreshold)) {
        // Moving but not vigorous → light sleep at most
        if (sample.stage == SleepStage.deep || sample.stage == SleepStage.rem) {
          refinedStage = SleepStage.light;
        }
      }

      if (refinedStage == sample.stage) return sample;

      return AmplitudeSample(
        timeSeconds: sample.timeSeconds,
        amplitude: sample.amplitude,
        isSnoring: false,
        noiseType: sample.noiseType, // preserve classification
        stage: refinedStage,
        intensity: sample.intensity,
        dominantFrequencyHz: sample.dominantFrequencyHz,
        sber: sample.sber,
        fundamentalHz: sample.fundamentalHz,
      );
    }).toList();
  }

  /// Classifies each motion sample into an actigraphy stage.
  static ActigraphyStage classifyMotion(SleepMotionSample sample) {
    if (sample.movementIntensity >= 1.0) return ActigraphyStage.awake;
    if (sample.movementIntensity >= 0.3) return ActigraphyStage.lightSleep;
    if (sample.movementIntensity >= 0.1) return ActigraphyStage.remSuspected;
    return ActigraphyStage.deepSleep;
  }
}
