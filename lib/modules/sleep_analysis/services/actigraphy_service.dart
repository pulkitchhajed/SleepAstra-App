import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:screen_state/screen_state.dart';
import '../models/sleep_report.dart';

/// Actigraphy Service — Accelerometer + Screen State sleep stage refinement.
///
/// Uses the device accelerometer (via sensors_plus) to detect body movement
/// AND the screen state (via screen_state) to detect active phone usage.
///
/// The Magic Rule:
///   - Screen ON + App in Background = User is actively using another app → Awake
///   - Screen ON + App in Foreground = User left the recording screen open → Normal heuristics
///   - Screen OFF = Rely on accelerometer data as before
class ActigraphyService with WidgetsBindingObserver {
  // ── Movement thresholds ─────────────────────────────────────────────────
  static const double _gravity = 9.81;
  static const double _movingThreshold = 0.15;
  static const double _vigorousThreshold = 0.50;
  static const Duration _windowDuration = Duration(seconds: 3);

  // ── State ───────────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<ScreenStateEvent>? _screenSubscription;

  final List<SleepMotionSample> _samples = [];
  final List<double> _windowBuffer = [];
  DateTime? _windowStart;
  DateTime? _recordingStart;
  bool _isRecording = false;

  /// Whether the phone screen is currently on.
  bool _isScreenOn = false;

  /// Whether the app is currently in the foreground (resumed) or not.
  bool _isAppInForeground = true;

  bool get isRecording => _isRecording;
  List<SleepMotionSample> get samples => List.unmodifiable(_samples);

  // ── Public API ──────────────────────────────────────────────────────────

  /// Start collecting accelerometer and screen state data.
  Future<void> startRecording() async {
    if (_isRecording) return;
    _samples.clear();
    _windowBuffer.clear();
    _isRecording = true;
    _isScreenOn = false;
    _isAppInForeground = true;
    _recordingStart = DateTime.now();
    _windowStart = DateTime.now();

    // Register app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Subscribe to accelerometer
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(
      _onAccelerometerEvent,
      onError: (e) {
        // Silently fail — actigraphy is optional
        stopRecording();
      },
      cancelOnError: true,
    );

    // Subscribe to screen state events
    try {
      final screen = Screen();
      _screenSubscription = screen.screenStateStream.listen(
        _onScreenStateEvent,
        onError: (_) {}, // silently ignore — screen_state is optional
      );
    } catch (_) {
      // screen_state not available on this platform — gracefully degrade
    }
  }

  /// Stop collecting and return the list of motion samples.
  List<SleepMotionSample> stopRecording() {
    _isRecording = false;

    _accelSubscription?.cancel();
    _accelSubscription = null;

    _screenSubscription?.cancel();
    _screenSubscription = null;

    WidgetsBinding.instance.removeObserver(this);

    // Flush any remaining buffer
    _flushWindow();

    return List.from(_samples);
  }

  // ── App Lifecycle Observer ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
  }

  // ── Internal ────────────────────────────────────────────────────────────

  void _onScreenStateEvent(ScreenStateEvent event) {
    switch (event) {
      case ScreenStateEvent.screenOn:
      case ScreenStateEvent.screenUnlocked:
        _isScreenOn = true;
        break;
      case ScreenStateEvent.screenOff:
        _isScreenOn = false;
        break;
    }
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (!_isRecording) return;
    if (!event.x.isFinite || !event.y.isFinite || !event.z.isFinite) return;

    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final deviation = (magnitude - _gravity).abs();
    _windowBuffer.add(deviation);

    final now = DateTime.now();
    if (_windowStart != null && now.difference(_windowStart!) >= _windowDuration) {
      _flushWindow();
      _windowStart = now;
    }
  }

  void _flushWindow() {
    if (_windowBuffer.isEmpty || _recordingStart == null) return;

    final sorted = List<double>.from(_windowBuffer)..sort();
    final p75Index = (sorted.length * 0.75).floor().clamp(0, sorted.length - 1);
    final p75deviation = sorted[p75Index];

    double movementIntensity = (p75deviation / _vigorousThreshold).clamp(0.0, 1.0);

    final timeSeconds = (_windowStart ?? DateTime.now())
        .difference(_recordingStart!)
        .inSeconds
        .toDouble();

    // The Magic Rule: user is "using phone" if screen is ON and app is NOT in foreground
    final isUsingPhone = _isScreenOn && !_isAppInForeground;

    _samples.add(SleepMotionSample(
      timeSeconds: timeSeconds,
      magnitude: _gravity + p75deviation,
      movementIntensity: movementIntensity,
      isUsingPhone: isUsingPhone,
    ));

    _windowBuffer.clear();
  }

  // ── Stage Refinement ────────────────────────────────────────────────────

  /// Refines the audio-based amplitude timeline using actigraphy data.
  ///
  /// Priority order (highest to lowest):
  ///   1. isUsingPhone = true       → SleepStage.awake (user on another app)
  ///   2. vigorous movement         → SleepStage.awake
  ///   3. moderate movement         → SleepStage.light (at most)
  ///   4. still                     → preserve the audio-based stage
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

      if (closest == null || minDiff > 10) return sample;

      // ── Priority 1: Phone usage (screen on + app in background) ──────────
      if (closest.isUsingPhone) {
        return AmplitudeSample(
          timeSeconds: sample.timeSeconds,
          amplitude: sample.amplitude,
          isSnoring: false,
          noiseType: sample.noiseType,
          stage: SleepStage.awake,
          intensity: sample.intensity,
          dominantFrequencyHz: sample.dominantFrequencyHz,
          sber: sample.sber,
          fundamentalHz: sample.fundamentalHz,
        );
      }

      // ── Priority 2 & 3: Movement-based correction ─────────────────────
      SleepStage refinedStage = sample.stage;
      if (closest.movementIntensity >= 1.0) {
        refinedStage = SleepStage.awake;
      } else if (closest.movementIntensity >= (_movingThreshold / _vigorousThreshold)) {
        if (sample.stage == SleepStage.deep || sample.stage == SleepStage.rem) {
          refinedStage = SleepStage.light;
        }
      }

      if (refinedStage == sample.stage) return sample;

      return AmplitudeSample(
        timeSeconds: sample.timeSeconds,
        amplitude: sample.amplitude,
        isSnoring: false,
        noiseType: sample.noiseType,
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
    if (sample.isUsingPhone) return ActigraphyStage.awake;
    if (sample.movementIntensity >= 1.0) return ActigraphyStage.awake;
    if (sample.movementIntensity >= 0.3) return ActigraphyStage.lightSleep;
    if (sample.movementIntensity >= 0.1) return ActigraphyStage.remSuspected;
    return ActigraphyStage.deepSleep;
  }
}
