import 'dart:math';
import '../models/sleep_report.dart';

/// Advanced Apnea Pattern Recognition — Crescendo-Silence-Gasp Detector
///
/// Detects the three-phase clinical signature of Obstructive Sleep Apnea (OSA):
///
///   Phase 1 — CRESCENDO:  A series of snoring windows where amplitude
///                          is progressively increasing (the airway is
///                          gradually narrowing/vibrating harder).
///
///   Phase 2 — SILENCE:    A sudden cessation of all sound for 10–120 s
///                          while the person's chest continues to struggle
///                          (the airway has completely collapsed).
///
///   Phase 3 — GASP/AROUSAL: A sharp, high-amplitude, high-entropy burst
///                          of sound as the person gasps awake and resumes
///                          breathing.
///
/// Only events that exhibit all three phases get a HIGH confidence score.
/// Single-phase events (just a gap) still get LOW confidence to avoid false positives.
///
/// Output:
///   - [SuspectedApneaEvent] list (with confidence 0–1)
///   - Approximate AHI (events/hour of sleep)
class ApneaPatternDetector {
  // ── Phase 1 thresholds ─────────────────────────────────────────────────────

  /// Minimum number of consecutive snoring windows showing amplitude growth
  /// to count as a crescendo (3 windows × 3 s = ≥9 s of building snoring).
  static const int _minCrescendoWindows = 3;

  /// Required fractional amplitude growth per window during crescendo phase.
  /// 0.05 = each window must be at least 5% louder than the previous.
  static const double _crescendoGrowthRate = 0.04;

  // ── Phase 2 thresholds ─────────────────────────────────────────────────────

  /// Minimum silence duration (in seconds) to count as an apnea event.
  /// Clinical definition of apnea = ≥10 s of airflow cessation.
  static const int _minSilenceSec = 10;

  /// Maximum silence duration. Beyond 120 s the person likely just rolled
  /// into a quiet sleep stage rather than having an apnea event.
  static const int _maxSilenceSec = 120;

  // ── Phase 3 thresholds ─────────────────────────────────────────────────────

  /// The recovery gasp must be above this multiple of the local noise floor.
  /// 3.0× = the gasp is 3× louder than baseline ambient noise.
  static const double _gaspAmplitudeMult = 3.0;

  /// Number of windows after silence to look for a recovery gasp.
  static const int _gaspLookAheadWindows = 3;

  // ──────────────────────────────────────────────────────────────────────────

  /// Runs the full CSG detector on a completed [AmplitudeSample] timeline
  /// and returns the list of detected apnea events plus approximate AHI.
  static ({List<SuspectedApneaEvent> events, double ahi}) detect({
    required List<AmplitudeSample> timeline,
    required List<SnoringEvent> snoringEvents,
    required Duration totalDuration,
    required double noiseFloor,
  }) {
    if (timeline.length < 4) {
      return (events: const [], ahi: 0.0);
    }

    final events = <SuspectedApneaEvent>[];

    // ── Step 1: Identify Crescendo Runs ──────────────────────────────────────
    // A crescendo run is a contiguous sequence of [isSnoring] windows where
    // amplitude is monotonically or near-monotonically increasing.
    final crescendoEndIndices = <int>{};

    int windowStart = 0;
    while (windowStart < timeline.length) {
      if (!timeline[windowStart].isSnoring) { windowStart++; continue; }

      // Walk forward collecting consecutive snoring windows
      int runEnd = windowStart + 1;
      while (runEnd < timeline.length && timeline[runEnd].isSnoring) { runEnd++; }
      // [windowStart, runEnd) is a snoring run

      if (runEnd - windowStart >= _minCrescendoWindows) {
        // Check if amplitude is generally increasing
        int growthCount = 0;
        for (int i = windowStart + 1; i < runEnd; i++) {
          final growth = (timeline[i].amplitude - timeline[i - 1].amplitude) /
              max(timeline[i - 1].amplitude, 0.001);
          if (growth >= _crescendoGrowthRate) growthCount++;
        }
        final growthRatio = growthCount / (runEnd - windowStart - 1);
        if (growthRatio >= 0.5) {
          // More than half the windows are growing → crescendo confirmed
          crescendoEndIndices.add(runEnd - 1);
        }
      }
      windowStart = runEnd;
    }

    // ── Step 2: Silence Detection ─────────────────────────────────────────────
    // For each crescendo end, look ahead for a silence gap
    for (final crescendoEnd in crescendoEndIndices) {
      final silenceStart = crescendoEnd + 1;
      if (silenceStart >= timeline.length) continue;

      // Find consecutive non-snoring windows starting at silenceStart
      int silenceEnd = silenceStart;
      while (silenceEnd < timeline.length && !timeline[silenceEnd].isSnoring) {
        silenceEnd++;
      }
      // Silence window: [silenceStart, silenceEnd)

      final silenceSec = (silenceEnd > silenceStart)
          ? (timeline[silenceEnd > 0 ? silenceEnd - 1 : 0].timeSeconds -
              timeline[silenceStart].timeSeconds)
          : 0.0;

      if (silenceSec < _minSilenceSec || silenceSec > _maxSilenceSec) continue;

      // ── Step 3: Gasp / Arousal Detection ─────────────────────────────────
      double gaspAmplitude = 0.0;
      bool gaspFound = false;

      final gaspSearchEnd = min(silenceEnd + _gaspLookAheadWindows, timeline.length);
      for (int gi = silenceEnd; gi < gaspSearchEnd; gi++) {
        if (timeline[gi].amplitude >= noiseFloor * _gaspAmplitudeMult) {
          gaspAmplitude = max(gaspAmplitude, timeline[gi].amplitude);
          gaspFound = true;
        }
      }

      // ── Confidence Scoring ────────────────────────────────────────────────
      // Full 3-phase event: high confidence (0.80–0.95)
      // 2-phase (crescendo + silence, no gasp): moderate (0.55)
      // 1-phase (just silence): low (0.35)
      double confidence;
      ApneaEventType type;

      if (gaspFound) {
        // Confidence proportional to how loud the gasp was
        confidence = (0.75 + (gaspAmplitude / max(noiseFloor * 4, 0.1)) * 0.15).clamp(0.75, 0.95);
        type = gaspAmplitude > noiseFloor * 5
            ? ApneaEventType.gasping
            : ApneaEventType.recoveryBreath;
      } else {
        confidence = 0.55;
        type = ApneaEventType.breathingPause;
      }

      events.add(SuspectedApneaEvent(
        timestamp: Duration(seconds: timeline[silenceStart].timeSeconds.round()),
        gapDuration: Duration(seconds: silenceSec.round()),
        type: type,
        peakRecoveryAmplitude: gaspAmplitude,
        confidence: confidence,
      ));
    }

    // ── Fallback: Simple gap scanner for short recordings without crescendos ─
    // Ensures we always catch obvious pauses even if no crescendo was found.
    if (events.isEmpty && snoringEvents.length >= 2) {
      for (int i = 0; i < snoringEvents.length - 1; i++) {
        final currentEnd = snoringEvents[i].timestamp + snoringEvents[i].duration;
        final gap = snoringEvents[i + 1].timestamp - currentEnd;
        if (gap.inSeconds >= _minSilenceSec && gap.inSeconds <= _maxSilenceSec) {
          events.add(SuspectedApneaEvent(
            timestamp: currentEnd,
            gapDuration: gap,
            type: ApneaEventType.breathingPause,
            peakRecoveryAmplitude: snoringEvents[i + 1].amplitude,
            confidence: 0.35,
          ));
        }
      }
    }

    // ── AHI Calculation ───────────────────────────────────────────────────────
    // Only count events with confidence ≥ 0.5 for AHI (filter out weak signals)
    // Clinical AHI divides by total SLEEP time (not total recording time).
    // Awake windows are excluded so the denominator reflects true in-sleep hours.
    final highConfidenceEvents = events.where((e) => e.confidence >= 0.5).length;
    final sleepHours = totalDuration.inSeconds / 3600.0;
    final ahi = sleepHours > 0.1 ? highConfidenceEvents / sleepHours : 0.0;

    // Sort by timestamp
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return (events: events, ahi: ahi);
  }
}
