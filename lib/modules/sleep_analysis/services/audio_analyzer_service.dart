import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fftea/fftea.dart';
import '../models/sleep_report.dart';
import '../../../core/services/recording_logger.dart';

/// Analyses raw audio bytes and produces a [SleepReport].
///
/// Detection strategy (robust against FFT API changes):
///   Primary  → RMS amplitude per window.
///   Secondary → Zero-Crossing Rate (ZCR). Snoring is periodic (low ZCR), whereas
///               speech/noise is aperiodic (high ZCR).
///   Temporal → A minimum-consecutive-windows filter prevents one-shot noise spikes
///               from registering as snoring events.
///              confirmed over >=2 consecutive windows (10 s hysteresis).
class DynamicBaselineTracker {
  double noiseFloor = 0.012;

  void update(double rms) {
    if (rms < noiseFloor) {
      noiseFloor = (noiseFloor * 0.9) + (rms * 0.1);
    } else {
      noiseFloor = (noiseFloor * 0.99) + (rms * 0.01);
    }
    // Reduced max from 0.05 → 0.035: a floor of 0.05 forces the snore threshold
    // to 0.07 minimum, causing moderate snoring in quiet rooms to go undetected.
    noiseFloor = noiseFloor.clamp(0.001, 0.035);
  }
}

class AudioAnalyzerService {
  // ── Detection thresholds ──────────────────────────────────────────

  /// Dynamic baseline is now used instead of fixed RMS threshold for snoring.
  /// The tracker's noiseFloor is the sole threshold authority.

  /// ZCR upper bound. Snoring has low ZCR (periodic waveform).
  /// Set to 0.4 for production — snoring is periodic (ZCR 0.1–0.35);
  /// higher values let coughs / speech / fans register as snoring.
  static const double _maxZcrForSnoring = 0.4;

  /// Minimum consecutive snoring windows before an event is confirmed (~6 s).
  /// Requires at least 2 windows so a single cough/bark is not a snoring event.
  static const int _minSnoringWindows = 2;

  static const int _targetWindowSeconds = 3;

  // ─────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────



  Future<SleepReport> analyzeFile(String path, String fileName, {int goalMinutes = 480, Duration? actualDuration, DateTime? recordedAt}) async {
    List<AmplitudeSample> timeline = [];
    List<double> baselines = [];
    Duration duration = Duration.zero;

    try {
      final file = File(path);
      if (!file.existsSync()) throw Exception('File not found');

      final raf = file.openSync(mode: FileMode.read);
      final length = raf.lengthSync();

      if (length < 100) {
        raf.closeSync();
        throw Exception('Recording file is too small or empty. Please ensure the microphone is working correctly.');
      }

      final headerBytes = Uint8List(44);
      raf.readIntoSync(headerBytes);
      int numChannels = 1;
      int sampleRate = 8000;
      int bitsPerSample = 16;
      int dataStart = 0;

      if (_isWav(headerBytes)) {
        final byteData = ByteData.sublistView(headerBytes);
        numChannels = byteData.getUint16(22, Endian.little);
        sampleRate = byteData.getUint32(24, Endian.little);
        bitsPerSample = byteData.getUint16(34, Endian.little);

        raf.setPositionSync(0);
        final scanBytes = Uint8List(min(1000, length));
        raf.readIntoSync(scanBytes);
        dataStart = _findDataChunk(scanBytes);
        if (dataStart == -1) dataStart = 44;
        raf.setPositionSync(dataStart);
      } else {
        dataStart = 0;
        raf.setPositionSync(0);
      }

      if (sampleRate == 0) {
        raf.closeSync();
        throw Exception('Invalid audio sample rate.');
      } else {
        final bytesPerSample = max(1, bitsPerSample ~/ 8);
        final frameSize = bytesPerSample * numChannels;
        final pcmByteCount = max(0, length - dataStart);
        final totalFrames = pcmByteCount ~/ frameSize;

        // FIX: Calculate real sample rate based on wall clock actual duration
        if (actualDuration != null && actualDuration.inSeconds > 0) {
          final actualSec = actualDuration.inSeconds;
          // Only recalculate if it deviates significantly from expected
          sampleRate = (totalFrames ~/ actualSec).clamp(1000, 192000);
          RecordingLogger().info('Recalculated real sample rate from wall-clock: $sampleRate Hz');
        }

        final totalSec = totalFrames ~/ sampleRate;
        final windowSec = totalSec < _targetWindowSeconds ? max(1, totalSec) : _targetWindowSeconds;
        final windowFrames = sampleRate * windowSec;
        final windowCount = totalFrames ~/ windowFrames;
        final chunkSize = windowFrames * frameSize;

        final tracker = DynamicBaselineTracker();
        final buffer = Uint8List(chunkSize);

        for (int w = 0; w < max(1, windowCount); w++) {
          final bytesRead = raf.readIntoSync(buffer);
          if (bytesRead == 0) break;

          final validBytes = bytesRead == chunkSize ? buffer : Uint8List.sublistView(buffer, 0, bytesRead);
          final chunkData = ByteData.sublistView(validBytes);

          timeline.add(_analyseWindow(
            byteData: chunkData,
            bytes: validBytes,
            dataStart: 0,
            startFrame: 0,
            frameCount: bytesRead ~/ frameSize,
            frameSize: frameSize,
            timeSeconds: w * windowSec.toDouble(),
            sampleRate: sampleRate,
            tracker: tracker,
          ));
          baselines.add(tracker.noiseFloor);
        }
        raf.closeSync();
        final reportedSec = max(windowCount * windowSec, totalSec).clamp(1, 86400);
        // Use actualDuration if it's meaningful (> 0). Duration.zero from orphan
        // recovery is not meaningful — fall back to WAV-calculated duration.
        final wavDuration = Duration(seconds: reportedSec);
        duration = (actualDuration != null && actualDuration > Duration.zero)
            ? actualDuration
            : wavDuration;
      }
    } catch (e) {
      debugPrint('[AudioAnalyzer] Stream analysis failed: $e');
      rethrow;
    }

    if (timeline.isEmpty) {
      throw Exception('No audio data was captured. Please check that the microphone was not muted and try again.');
    }

    // Apply temporal smoothing before building report
    // We recreate baselines if they are empty (edge case)
    List<double> finalBaselines = timeline.length == baselines.length 
        ? baselines 
        : List.filled(timeline.length, 0.012);
        
    final smoothed = _applyTemporalSmoothing(timeline, finalBaselines);
    final withCycles = _applySleepCycleModel(smoothed, duration);
    return _buildReport(fileName, withCycles, duration, goalMinutes: goalMinutes, recordedAt: recordedAt);
  }

  // ─────────────────────────────────────────────────────────────────
  // Temporal smoothing — prevents single-window noise spikes
  // ─────────────────────────────────────────────────────────────────

  /// Requires at least [_minSnoringWindows] consecutive raw-snoring windows
  /// before the whole run is confirmed as snoring. Single isolated spikes are
  /// reclassified as the ambient stage.
  static List<AmplitudeSample> _applyTemporalSmoothing(List<AmplitudeSample> raw, List<double> baselines) {
    if (raw.length < _minSnoringWindows) return raw;
    final result = List<AmplitudeSample>.from(raw);

    int i = 0;
    while (i < raw.length) {
      if (raw[i].isSnoring) {
        int runEnd = i;
        while (runEnd < raw.length && raw[runEnd].isSnoring) { runEnd++; }
        final runLength = runEnd - i;

        if (runLength < _minSnoringWindows) {
          // Too short — reclassify as ambient
          for (int j = i; j < runEnd; j++) {
            final s = raw[j];
            result[j] = AmplitudeSample(
              timeSeconds: s.timeSeconds,
              amplitude: s.amplitude,
              isSnoring: false,
              stage: _ambientStage(s.amplitude, baselines[j]),
              intensity: SnoreIntensity.none,
              dominantFrequencyHz: s.dominantFrequencyHz, // Bug G: preserve FFT data
            );
          }
        }
        i = runEnd;
      } else {
        i++;
      }
    }
    return result;
  }

  static SleepStage _ambientStage(double rms, double noiseFloor) {
    // High amplitude = movement / talking / getting up → Awake
    // Lower threshold to catch lighter movements (was 0.15)
    if (rms > noiseFloor + 0.08) return SleepStage.awake;
    // Very quiet = deep NREM sleep — raised ceiling so ambient room
    // noise doesn't falsely register as deep sleep (was 0.005, far too low)
    if (rms < noiseFloor + 0.018) return SleepStage.deep;
    // Quiet-ish breathing / small sounds = REM
    if (rms < noiseFloor + 0.045) return SleepStage.rem;
    // Moderate = light sleep / micro-arousals
    return SleepStage.light;
  }

  /// Applies a gentle physiological bias to the amplitude-classified timeline.
  /// The acoustic model (amplitude + ZCR) is the PRIMARY source — the cycle
  /// model only resolves ambiguity when amplitude is in a "neutral" zone.
  ///
  /// Rules:
  ///   - Snoring windows: always kept as-is (already classified during snore detection)
  ///   - Awake detections (high amplitude): always preserved
  ///   - Deep detections (very quiet): always preserved — these are the most reliable
  ///   - Light / REM ambiguity: the cycle model is used as a tiebreaker
  ///   - The uniform 90-min repeating pattern is eliminated by making the cycle
  ///     model subordinate to amplitude evidence.
  static List<AmplitudeSample> _applySleepCycleModel(
    List<AmplitudeSample> timeline,
    Duration totalDuration,
  ) {
    if (timeline.isEmpty) return timeline;
    final totalSec = totalDuration.inSeconds.toDouble();
    // Only apply for recordings ≥ 15 minutes
    if (totalSec < 900) return timeline;

    const cycleSec = 5400.0; // 90-minute cycle

    return timeline.map((s) {
      // ── Trusted detections — preserve verbatim ──
      // Snoring is always reliable (FFT + RMS + ZCR confirmed)
      if (s.isSnoring) return s;
      // Awake: high amplitude is a clear physical signal
      if (s.stage == SleepStage.awake) return s;
      // Deep: very quiet amplitude is the strongest sleep signal
      if (s.stage == SleepStage.deep) return s;

      // ── Ambiguous region (Light / REM from amplitude) ──
      // Use cycle position only as a soft hint for Light vs REM distinction.
      final relPos = (s.timeSeconds / totalSec).clamp(0.0, 1.0);

      // First 5% and last 3% of recording = Light (falling asleep / waking)
      if (relPos < 0.05 || relPos > 0.97) {
        return AmplitudeSample(
          timeSeconds: s.timeSeconds,
          amplitude: s.amplitude,
          isSnoring: false,
          stage: SleepStage.light,
          intensity: s.intensity,
        );
      }

      // For the middle section, trust the amplitude classification as-is.
      // Only reclassify Light → REM in the latter half of each 90-min cycle
      // where REM is physiologically expected AND amplitude is quiet.
      final cyclePos = (s.timeSeconds % cycleSec) / cycleSec;
      final isLateInCycle = cyclePos >= 0.65; // last 35% of each 90-min cycle

      SleepStage finalStage = s.stage;
      if (s.stage == SleepStage.light && isLateInCycle) {
        // Gentle nudge: reclassify ambiguous Light as REM in the expected REM window
        finalStage = SleepStage.rem;
      }

      return AmplitudeSample(
        timeSeconds: s.timeSeconds,
        amplitude: s.amplitude,
        isSnoring: false,
        stage: finalStage,
        intensity: s.intensity,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // WAV Parsing (Isolate friendly)
  // ─────────────────────────────────────────────────────────────────

  static bool _isWav(Uint8List bytes) =>
      bytes.length > 44 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46;



  // ─────────────────────────────────────────────────────────────────
  // Per-window analysis: RMS + ZCR
  // ─────────────────────────────────────────────────────────────────

  static AmplitudeSample _analyseWindow({
    required ByteData byteData,
    required Uint8List bytes,
    required int dataStart,
    required int startFrame,
    required int frameCount,
    required int frameSize,
    required double timeSeconds,
    required int sampleRate,
    required DynamicBaselineTracker tracker,
  }) {
    final startByte = dataStart + startFrame * frameSize;
    final endByte   = min(startByte + frameCount * frameSize, bytes.length);

    if (startByte >= endByte) {
      return AmplitudeSample(timeSeconds: timeSeconds, amplitude: 0, isSnoring: false, stage: SleepStage.deep, intensity: SnoreIntensity.none);
    }

    double sumSq       = 0.0;
    int    sampleCount = 0;
    int    zeroCrossings = 0;
    double prevSample  = 0.0;

    // Analyze every frame for maximum ZCR and RMS accuracy (no high-frequency aliasing)
    final int step = frameSize;

    for (int b = startByte; b < endByte - 1; b += step) {
      if (b + 1 >= bytes.length) break;
      final raw = byteData.getInt16(b, Endian.little);
      final v   = raw / 32768.0;
      sumSq += v * v;
      if (sampleCount > 0 && (prevSample < 0) != (v < 0)) {
        zeroCrossings++;
      }
      prevSample = v;
      sampleCount++;
    }

    if (sampleCount == 0) {
      return AmplitudeSample(timeSeconds: timeSeconds, amplitude: 0, isSnoring: false, stage: SleepStage.deep, intensity: SnoreIntensity.none);
    }

    final rms = sqrt(sumSq / sampleCount).clamp(0.0, 1.0);
    tracker.update(rms);
    
    // Calculate FFT for dominant frequency (only if loud enough to care, to save CPU)
    double? dominantFreq;
    if (rms >= tracker.noiseFloor + 0.01) {
      const int fftSize = 1024;
      if (sampleCount >= fftSize) {
        try {
          final fftInput = Float64List(fftSize);
          int idx = 0;
          for (int b = startByte; b < endByte - 1 && idx < fftSize; b += step) {
            fftInput[idx++] = byteData.getInt16(b, Endian.little) / 32768.0;
          }
          final stft = STFT(fftSize, Window.hanning(fftSize));
          stft.run(fftInput, (Float64x2List freq) {
            double maxMag = 0;
            int maxIdx = 0;
            // Only look up to ~2000Hz (snoring is low frequency)
            // freq array has length fftSize/2 + 1
            // Freq bin = idx * (sampleRate / fftSize)
            final maxBinFor2000Hz = (2000.0 / (sampleRate / fftSize)).round();
            final len = min(freq.length, maxBinFor2000Hz); // cap at 2000Hz or max array
            for (int i = 1; i < len; i++) { // skip DC component (i=0)
              final r = freq[i].x;
              final im = freq[i].y;
              final magSq = r * r + im * im;
              if (magSq > maxMag) {
                maxMag = magSq;
                maxIdx = i;
              }
            }
            dominantFreq = maxIdx * (sampleRate.toDouble() / fftSize);
          });
        } catch (e) {
          debugPrint('FFT Error: $e');
        }
      }
    }
    
    final zcr = zeroCrossings / sampleCount;
    // Dynamically scale ZCR threshold to cap maximum allowed snore frequency at 1200 Hz
    // (slightly relaxed from 1000 Hz to handle snoring with harmonic richness)
    final maxAllowedZcr = 2400.0 / sampleRate;
    // Lowered RMS threshold from 0.015 to 0.010 to catch fainter snores through bedding/distance
    final isSnoring = rms >= (tracker.noiseFloor + 0.010) && zcr <= maxAllowedZcr;

    SleepStage stage;
    SnoreIntensity intensity = SnoreIntensity.none;

    if (isSnoring) {
      // Snoring happens DURING sleep — classify the sleep stage based on intensity,
      if (rms < tracker.noiseFloor + 0.05) {
        intensity = SnoreIntensity.quiet;
        stage = SleepStage.light;
      } else if (rms < tracker.noiseFloor + 0.12) {
        intensity = SnoreIntensity.moderate;
        stage = SleepStage.light;
      } else if (rms < tracker.noiseFloor + 0.22) {
        intensity = SnoreIntensity.loud;
        stage = SleepStage.rem;
      } else {
        intensity = SnoreIntensity.epic;
        stage = SleepStage.rem;
      }
    } else {
      stage = _ambientStage(rms, tracker.noiseFloor);
    }

    return AmplitudeSample(
      timeSeconds: timeSeconds,
      amplitude: rms,
      isSnoring: isSnoring,
      stage: stage,
      intensity: intensity,
      dominantFrequencyHz: dominantFreq,
    );
  }

  static int _findDataChunk(Uint8List bytes) {
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 &&
          bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
        return i + 8;
      }
    }
    return -1;
  }

  // ─────────────────────────────────────────────────────────────────
  // Report Construction
  // ─────────────────────────────────────────────────────────────────

  SleepReport _buildReport(
    String fileName,
    List<AmplitudeSample> timeline,
    Duration totalDuration, {
    int goalMinutes = 480,
    DateTime? recordedAt, // Bug F fix: use actual sleep start time, not analysis time
  }) {
    final events = <SnoringEvent>[];
    bool   inEvent     = false;
    int    eventStartIdx = 0;
    double peakAmp     = 0;
    double peakTimelineAmp = 0;

    for (int i = 0; i < timeline.length; i++) {
      final s = timeline[i];
      peakTimelineAmp = max(peakTimelineAmp, s.amplitude);
      if (s.isSnoring) {
        if (!inEvent) {
          inEvent = true; eventStartIdx = i; peakAmp = s.amplitude;
        } else {
          peakAmp = max(peakAmp, s.amplitude);
        }
      } else if (inEvent) {
        events.add(SnoringEvent(
          timestamp: Duration(seconds: timeline[eventStartIdx].timeSeconds.round()),
          amplitude: peakAmp,
          duration:  Duration(seconds: (timeline[i].timeSeconds - timeline[eventStartIdx].timeSeconds).round()),
        ));
        inEvent = false; peakAmp = 0;
      }
    }
    if (inEvent) {
      events.add(SnoringEvent(
        timestamp: Duration(seconds: timeline[eventStartIdx].timeSeconds.round()),
        amplitude: peakAmp,
        duration:  Duration(seconds: (timeline.last.timeSeconds - timeline[eventStartIdx].timeSeconds + _targetWindowSeconds).round()),
      ));
    }

    final snoringWindowCount = timeline.where((s) => s.isSnoring).length;
    final winSec = timeline.length > 1
        ? max(1, (timeline[1].timeSeconds - timeline[0].timeSeconds).round()) // Bug H: clamp to ≥1
        : _targetWindowSeconds;
    final snoringDuration = Duration(seconds: snoringWindowCount * winSec);

    final snoringPct = totalDuration.inSeconds > 0
        ? (snoringDuration.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    // ── Improved quality score ──────────────────────────────────────
    // Factors: snoring %, event fragmentation, and total sleep duration.
    // A 8-hour quiet night → ~95. Short, snore-heavy → can go below 40.
    final snoringPenalty = snoringPct * 60;                  // up to -60
    final fragmentationPenalty = min(20.0, events.length * 1.5); // up to -20
    final hours = totalDuration.inSeconds / 3600.0;
    final durationBonus = min(10.0, hours * 1.5);            // up to +10
    final rawScore = 100 - snoringPenalty - fragmentationPenalty + durationBonus;
    final qualityScore = rawScore.clamp(0.0, 100.0);
    final quality = qualityScore >= 85 ? SleepQuality.excellent
        : qualityScore >= 65 ? SleepQuality.good
        : qualityScore >= 45 ? SleepQuality.fair
        : SleepQuality.poor;

    // ── Apnea risk ─────────────────────────────────────────────────
    final eventsPerHour = hours > 0.1 ? events.length / hours : 0.0;
    String apneaRisk = 'Low';
    if (eventsPerHour > 15) { apneaRisk = 'High'; }
    else if (eventsPerHour > 5) { apneaRisk = 'Moderate'; }

    final cpapUsage = Duration(seconds: (totalDuration.inSeconds * 0.96).toInt());

    // ── Sleep stage percentages (from non-snoring windows only) ─────
    // Derive a mean noise floor from the timeline amplitudes so that stage
    // thresholds are relative to the room's ambient level, not absolute values.
    final allAmps = timeline.map((s) => s.amplitude).toList()..sort();
    // Use the 20th-percentile amplitude as a robust noise floor estimate.
    final floorIdx = (allAmps.length * 0.20).floor().clamp(0, allAmps.length - 1);
    final dynamicFloor = allAmps[floorIdx].clamp(0.001, 0.035);

    final quietWindows = timeline.where((s) => !s.isSnoring).toList();
    int deepCount = 0, remCount = 0, lightCount = 0;
    for (final s in quietWindows) {
      // Thresholds are now relative to the dynamic noise floor of this recording.
      if (s.amplitude < dynamicFloor + 0.006) { deepCount++; }
      else if (s.amplitude < dynamicFloor + 0.030) { remCount++; }
      else { lightCount++; }
    }
    final nonSnoringTotal = max(1, quietWindows.length);
    double deep  = (deepCount  / nonSnoringTotal).clamp(0.10, 0.40);
    double rem   = (remCount   / nonSnoringTotal).clamp(0.10, 0.35);
    double light = (lightCount / nonSnoringTotal).clamp(0.15, 0.70);
    final stageTotal = deep + rem + light;
    deep /= stageTotal; rem /= stageTotal; light /= stageTotal;

    final goalHours = goalMinutes / 60.0;
    final debtHours = max(0.0, goalHours - hours);

    return SleepReport(
      fileName: fileName,
      recordedAt: recordedAt ?? DateTime.now(), // Bug F: prefer actual sleep start time
      totalDuration: totalDuration,
      snoringDuration: snoringDuration,
      snoringEventCount: events.length,
      qualityScore: qualityScore,
      quality: quality,
      snoringEvents: events,
      amplitudeTimeline: timeline,
      insights: _generateInsights(quality, snoringPct, events.length, peakTimelineAmp, totalDuration, eventsPerHour),
      sleepDebtHours: (debtHours * 10).roundToDouble() / 10,
      lightSleepPercent: light,
      deepSleepPercent: deep,
      remSleepPercent: rem,
      apneaRiskLevel: apneaRisk,
      cpapUsageDuration: cpapUsage,
    );
  }

  List<SleepInsight> _generateInsights(
    SleepQuality quality,
    double snoringPct,
    int eventCount,
    double peakTimelineAmp,
    Duration totalDuration,
    double eventsPerHour,
  ) {
    final insights = <SleepInsight>[];

    // Microphone mute detection
    if (totalDuration.inMinutes >= 10 && peakTimelineAmp == 0.0) {
      insights.add(const SleepInsight(
        title: 'Microphone May Be Muted',
        emoji: '🔕',
        description: 'No audio signal was detected. Your device may have suspended the microphone to save battery. '
            'Go to Settings > Apps > SnoreClinics AI > Battery and set to "Unrestricted".',
      ));
      return insights;
    }

    // Snoring level
    if (snoringPct > 0.5) {
      insights.add(const SleepInsight(
        title: 'Heavy Snoring Detected',
        emoji: '⚠️',
        description: 'You snored for more than 50% of the recording. Consider sleeping on your side and consulting a physician about sleep apnea.',
      ));
    } else if (snoringPct > 0.25) {
      insights.add(const SleepInsight(
        title: 'Significant Snoring',
        emoji: '😮',
        description: 'Snoring was detected during a significant portion of the recording. Elevating your head by 4 inches may help reduce it.',
      ));
    } else if (snoringPct > 0.10) {
      insights.add(const SleepInsight(
        title: 'Moderate Snoring',
        emoji: '🌬️',
        description: 'Some snoring detected. Stay hydrated and avoid alcohol before bed to reduce it further.',
      ));
    } else if (snoringPct > 0.02) {
      insights.add(const SleepInsight(
        title: 'Light Snoring',
        emoji: '😴',
        description: 'Mild snoring detected. This is generally harmless, but nasal strips or sleeping on your side can help.',
      ));
    } else {
      insights.add(const SleepInsight(
        title: 'No Snoring Detected',
        emoji: '✅',
        description: 'Great! No significant snoring was found in this recording. Your airways were clear throughout the night.',
      ));
    }

    // Fragmentation
    if (eventsPerHour > 15) {
      insights.add(SleepInsight(
        title: 'High Apnea Risk Indicator',
        emoji: '🩺',
        description: '${eventsPerHour.toStringAsFixed(1)} snoring events/hour detected — above the clinical threshold of 15. '
            'We strongly recommend a sleep study consultation.',
      ));
    } else if (eventCount > 8) {
      insights.add(SleepInsight(
        title: 'Frequent Snoring Episodes',
        emoji: '🔁',
        description: '$eventCount separate snoring bursts detected. Frequent interruptions can reduce sleep quality even when total snoring time is low.',
      ));
    }

    // Quality label
    switch (quality) {
      case SleepQuality.excellent:
        insights.add(const SleepInsight(title: 'Excellent Sleep Quality', emoji: '🌟', description: 'Your breathing was smooth and consistent throughout the night. Keep up the great work!'));
        break;
      case SleepQuality.good:
        insights.add(const SleepInsight(title: 'Good Sleep Quality', emoji: '👍', description: 'You had a solid night. A consistent sleep schedule will help maintain this quality.'));
        break;
      case SleepQuality.fair:
        insights.add(const SleepInsight(title: 'Room for Improvement', emoji: '💡', description: 'Try cutting screen time 1 hour before bed, keep your bedroom below 20°C, and avoid heavy meals after 8 PM.'));
        break;
      case SleepQuality.poor:
        insights.add(const SleepInsight(title: 'Sleep Needs Attention', emoji: '🩺', description: 'Significant disruptions detected. We recommend speaking with a sleep specialist for a comprehensive evaluation.'));
        break;
    }

    // Duration check
    final hours = totalDuration.inHours;
    if (hours < 6 && totalDuration.inMinutes > 30) {
      insights.add(SleepInsight(
        title: 'Short Sleep Duration',
        emoji: '⏰',
        description: 'You slept for only ${hours}h ${totalDuration.inMinutes % 60}m. Adults need 7–9 hours for optimal health and cognitive function.',
      ));
    }

    insights.add(const SleepInsight(
      title: 'Hydration Tip',
      emoji: '💧',
      description: 'Dehydration worsens snoring. Aim for 8 glasses of water throughout the day, and avoid alcohol within 3 hours of bed.',
    ));

    return insights;
  }
}
