import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fftea/fftea.dart';
import '../models/sleep_report.dart';
import '../../../core/services/recording_logger.dart';
import 'apnea_pattern_detector.dart';
import 'ml_audio_classifier.dart';

/// Analyses raw audio bytes and produces a [SleepReport].
///
/// Detection strategy — 4-Feature Spectral Voting:
///   1. RMS Amplitude     — minimum volume gate (+1 vote)
///   2. SBER (Snoring Band Energy Ratio) — 50–800 Hz / total FFT energy (+2 votes if ≥50%, +1 if ≥35%)
///   3. Spectral Entropy  — snoring has ordered harmonic structure, low entropy (+1 vote if ≤0.75)
///   4. Autocorrelation Pitch (F0) — snoring F0 60–300 Hz (+1 vote)
///   5. Temporal filter   — requires ≥2 consecutive snoring windows (prevents one-shot noise spikes)
///
/// Snoring is confirmed when snore_vote ≥ 2.
///
/// Why this beats ZCR:
///   Fan/HVAC: SBER ~0.20 (energy spread across all freqs) → vote ≤ 1 → NOT snoring ✓
///   Snoring:  SBER ~0.55–0.80 (energy concentrated in 50–800 Hz) → vote ≥ 3 → snoring ✓
class DynamicBaselineTracker {
  /// Adaptive noise floor using 10th-percentile estimator over the last 60 windows.
  final List<double> _history = [];
  static const int _histSize = 60;
  double noiseFloor = 0.005; // start at a low, realistic value

  /// Rolling buffer of the last 5 F0 (pitch) estimates, used for temporal
  /// pitch stability scoring. High std-dev means rapidly varying pitch → speech.
  final List<double> _f0History = [];
  static const int _f0HistSize = 5;

  void update(double rms) {
    _history.add(rms);
    if (_history.length > _histSize) _history.removeAt(0);

    // Use 10th-percentile of recent history as a robust noise floor estimate.
    // This is more stable than exponential averaging — a temporarily loud room
    // doesn't inflate the baseline and then suppress quiet-snoring detection.
    final sorted = List<double>.from(_history)..sort();
    final idx = ((sorted.length - 1) * 0.10).floor().clamp(0, sorted.length - 1);
    noiseFloor = sorted[idx].clamp(0.001, 0.08); // cap raised to 0.08 to handle loud rooms
  }

  /// Record a detected F0 value and return the standard deviation of
  /// the recent F0 history (pitch instability score).
  double trackF0(double f0Hz) {
    _f0History.add(f0Hz);
    if (_f0History.length > _f0HistSize) _f0History.removeAt(0);
    if (_f0History.length < 2) return 0.0;
    final mean = _f0History.reduce((a, b) => a + b) / _f0History.length;
    final variance = _f0History.fold(0.0, (s, x) => s + (x - mean) * (x - mean)) / _f0History.length;
    return sqrt(variance); // std-dev in Hz
  }
}

class AudioAnalyzerService {
  // ── Detection thresholds ───────────────────────────────────────────

  /// Snoring Band Energy Ratio thresholds.
  /// Snoring concentrates ≥50% of its FFT energy in the 50–500 Hz band.
  static const double _sberStrongThreshold = 0.40; // +2 votes
  static const double _sberWeakThreshold   = 0.25; // +1 vote

  /// Spectral entropy upper bound.
  /// Snoring has harmonic structure → low entropy (≤0.85).
  /// White noise / fans → high entropy (>0.85).
  static const double _maxEntropyForSnoring = 0.85;

  /// Minimum vote score to classify a window as snoring.
  static const int _minSnoreVote = 2;

  /// Minimum consecutive snoring windows before an event is confirmed (~6 s).
  /// Set to 2 so that a single-window burst (cough, bark, door slam) is
  /// discarded by the temporal smoothing pass even if it passes the veto.
  static const int _minSnoringWindows = 2;

  static const int _targetWindowSeconds = 3;

  // ── Cepstral F0 pitch constants ───────────────────────────────────────────
  /// Snoring fundamental frequency range (Hz). Sounds with F0 in this range
  /// get an extra +1 vote, helping distinguish voiced snoring from fans.
  static const double _f0SnoreLowHz  = 60.0;
  static const double _f0SnoreHighHz = 300.0;

  // ── Multi-feature veto thresholds ────────────────────────────────────────

  /// Speech Formant Ratio (SFR): fraction of total energy in the 1000–3000 Hz band.
  /// Human speech has strong formant peaks (F1, F2) in this range.
  /// Snoring has very little energy above 800 Hz.
  /// If SFR > this threshold, the window is classified as talking, not snoring.
  static const double _speechFormantRatioThreshold = 0.20;

  /// Spectral Rolloff threshold (Hz).
  /// The frequency below which 85% of spectral energy lies.
  /// Snoring rolloff is typically < 600 Hz. Speech / music rolloff > 700 Hz.
  static const double _spectralRolloffThreshold = 700.0;

  /// Temporal Pitch Instability threshold (Hz std-dev over last 5 windows).
  /// Stable snoring: low F0 variance. Speech/music: F0 jumps rapidly.
  /// If pitch std-dev > this over the last 5 windows, veto snore classification.
  static const double _f0InstabilityThreshold = 50.0;

  // ─────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────

  Future<SleepReport> analyzeFile(String path, String fileName, {int goalMinutes = 480, Duration? actualDuration, DateTime? recordedAt, Uint8List? modelBuffer}) async {
    List<AmplitudeSample> timeline = [];
    List<double> baselines = [];
    Duration duration = Duration.zero;

    // Initialize ML Classifier
    final mlClassifier = MLAudioClassifierService();
    if (modelBuffer != null) {
      await mlClassifier.initializeFromBuffer(modelBuffer);
    }

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
      int sampleRate = 16000;
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

        // Recalculate real sample rate based on wall-clock actual duration
        if (actualDuration != null && actualDuration.inSeconds > 0) {
          final actualSec = actualDuration.inSeconds;
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
            mlClassifier: mlClassifier,
          ));
          baselines.add(tracker.noiseFloor);
        }
        raf.closeSync();
        final reportedSec = max(windowCount * windowSec, totalSec).clamp(1, 86400);
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

    List<double> finalBaselines = timeline.length == baselines.length
        ? baselines
        : List.filled(timeline.length, 0.012);

    final smoothed = _applyTemporalSmoothing(timeline, finalBaselines);
    final withCycles = _applySleepCycleModel(smoothed, duration);
    return _buildReport(fileName, withCycles, duration, finalBaselines: finalBaselines, goalMinutes: goalMinutes, recordedAt: recordedAt);
  }


  // ─────────────────────────────────────────────────────────────────
  // Temporal smoothing — prevents single-window noise spikes
  // ─────────────────────────────────────────────────────────────────

  /// Requires at least [_minSnoringWindows] consecutive raw-snoring windows
  /// before the whole run is confirmed as snoring.
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
              noiseType: s.noiseType, // preserve classification
              stage: _ambientStage(s.amplitude, baselines[j]),
              intensity: SnoreIntensity.none,
              dominantFrequencyHz: s.dominantFrequencyHz,
              sber: s.sber, // preserve SBER for frequency profile chart
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
    if (rms > noiseFloor + 0.08) return SleepStage.awake;
    if (rms < noiseFloor + 0.018) return SleepStage.deep;
    if (rms < noiseFloor + 0.045) return SleepStage.rem;
    return SleepStage.light;
  }

  /// Applies a gentle physiological bias to resolve Light/REM ambiguity.
  /// Snoring, Awake, and Deep detections are always preserved verbatim.
  static List<AmplitudeSample> _applySleepCycleModel(
    List<AmplitudeSample> timeline,
    Duration totalDuration,
  ) {
    if (timeline.isEmpty) return timeline;
    final totalSec = totalDuration.inSeconds.toDouble();
    if (totalSec < 900) return timeline; // Only apply for ≥15 min recordings

    const cycleSec = 5400.0; // 90-minute cycle

    return timeline.map((s) {
      // Trusted detections — preserve verbatim
      if (s.isSnoring) return s;
      if (s.stage == SleepStage.awake) return s;
      if (s.stage == SleepStage.deep) return s;

      // Ambiguous region (Light / REM)
      final relPos = (s.timeSeconds / totalSec).clamp(0.0, 1.0);

      if (relPos < 0.05 || relPos > 0.97) {
        return AmplitudeSample(
          timeSeconds: s.timeSeconds,
          amplitude: s.amplitude,
          isSnoring: false,
          noiseType: s.noiseType, // preserve classification
          stage: SleepStage.light,
          intensity: s.intensity,
          dominantFrequencyHz: s.dominantFrequencyHz,
          sber: s.sber,
          fundamentalHz: s.fundamentalHz,
        );
      }

      final cyclePos = (s.timeSeconds % cycleSec) / cycleSec;
      final isLateInCycle = cyclePos >= 0.65;

      SleepStage finalStage = s.stage;
      if (s.stage == SleepStage.light && isLateInCycle) {
        finalStage = SleepStage.rem;
      }

      return AmplitudeSample(
        timeSeconds: s.timeSeconds,
        amplitude: s.amplitude,
        isSnoring: false,
        noiseType: s.noiseType, // preserve classification
        stage: finalStage,
        intensity: s.intensity,
        dominantFrequencyHz: s.dominantFrequencyHz,
        sber: s.sber,
        fundamentalHz: s.fundamentalHz,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // WAV Parsing
  // ─────────────────────────────────────────────────────────────────

  static bool _isWav(Uint8List bytes) =>
      bytes.length > 44 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46;

  // ─────────────────────────────────────────────────────────────────
  // Per-window analysis: 5-Feature Spectral Voting
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
    required MLAudioClassifierService mlClassifier,
  }) {
    final startByte = dataStart + startFrame * frameSize;
    final endByte   = min(startByte + frameCount * frameSize, bytes.length);

    if (startByte >= endByte) {
      return AmplitudeSample(timeSeconds: timeSeconds, amplitude: 0, isSnoring: false, stage: SleepStage.deep, intensity: SnoreIntensity.none);
    }

    double sumSq       = 0.0;
    int    sampleCount = 0;

    final int step = frameSize;
    final expectedCount = ((endByte - startByte) / step).ceil();
    final floatList = Float32List(expectedCount);

    for (int b = startByte; b < endByte - 1; b += step) {
      if (b + 1 >= bytes.length) break;
      final raw = byteData.getInt16(b, Endian.little);
      final v   = raw / 32768.0;
      floatList[sampleCount] = v;
      sumSq += v * v;
      sampleCount++;
    }

    if (sampleCount == 0) {
      return AmplitudeSample(timeSeconds: timeSeconds, amplitude: 0, isSnoring: false, stage: SleepStage.deep, intensity: SnoreIntensity.none);
    }

    final rms = sqrt(sumSq / sampleCount).clamp(0.0, 1.0);
    tracker.update(rms);

    // ── Spectral Analysis (FFT) ────────────────────────────────────
    // Run whenever amplitude is potentially meaningful (above noise floor).
    // Lower gate (floor + 0.003) ensures quiet snoring still gets FFT analysis.
    double computedSber    = 0.0;  // Snoring Band Energy Ratio
    double computedEntropy = 1.0;  // Normalized spectral entropy (1.0 = max disorder)
    double computedSfr     = 0.0;  // Speech Formant Ratio (1000–3000 Hz / total)
    double spectralRolloffHz = 0.0; // Freq below which 85% of energy lies
    double? dominantFreq;

    if (rms >= tracker.noiseFloor + 0.002) {
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
            final halfLen = freq.length; // fftSize/2 + 1 = 513
            final freqResolution = sampleRate.toDouble() / fftSize;

            // Dynamically compute snoring band bin range
            // Extended to 800 Hz to capture breath turbulence harmonics
            final snoreLowBin  = (50.0  / freqResolution).round().clamp(1, halfLen - 1);
            final snoreHighBin = (800.0 / freqResolution).round().clamp(snoreLowBin, halfLen - 1);
            final maxBinFor2kHz = (2000.0 / freqResolution).round().clamp(1, halfLen - 1);
            // Entropy computed only over meaningful bins (not silent high-freq region)
            final entropyHighBin = maxBinFor2kHz;

            double totalEnergy     = 0.0;
            double snoreBandEnergy = 0.0;
            double maxMagSq        = 0.0;
            int    maxIdx          = 1;

            // Pass 1: energy accumulation + dominant frequency
            for (int i = 1; i < halfLen; i++) {
              final r  = freq[i].x;
              final im = freq[i].y;
              final magSq = r * r + im * im;
              totalEnergy += magSq;
              if (i >= snoreLowBin && i <= snoreHighBin) {
                snoreBandEnergy += magSq;
              }
              if (i <= maxBinFor2kHz && magSq > maxMagSq) {
                maxMagSq = magSq;
                maxIdx = i;
              }
            }

            dominantFreq = maxIdx * freqResolution;

            // SBER: snoring band energy fraction (50–800 Hz)
            computedSber = totalEnergy > 1e-15
                ? (snoreBandEnergy / totalEnergy).clamp(0.0, 1.0)
                : 0.0;

            // SFR: Speech Formant Ratio — energy in the 1000–3000 Hz band.
            // Human speech has strong F1/F2 formants here. Snoring has almost none.
            final formantLowBin  = (1000.0 / freqResolution).round().clamp(1, halfLen - 1);
            final formantHighBin = (3000.0 / freqResolution).round().clamp(formantLowBin, halfLen - 1);
            double formantEnergy = 0.0;
            for (int i = formantLowBin; i <= formantHighBin; i++) {
              final r = freq[i].x, im = freq[i].y;
              formantEnergy += r * r + im * im;
            }
            computedSfr = totalEnergy > 1e-15
                ? (formantEnergy / totalEnergy).clamp(0.0, 1.0)
                : 0.0;

            // Spectral Rolloff — frequency below which 85% of energy lies.
            // Snoring rolloff < 600 Hz; speech/music rolloff > 700 Hz.
            if (totalEnergy > 1e-15) {
              final rolloffTarget = totalEnergy * 0.85;
              double cumulative = 0.0;
              for (int i = 1; i < halfLen; i++) {
                final r = freq[i].x, im = freq[i].y;
                cumulative += r * r + im * im;
                if (cumulative >= rolloffTarget) {
                  spectralRolloffHz = i * freqResolution;
                  break;
                }
              }
            }

            // Pass 2: Spectral Entropy — computed only over meaningful bins
            // Using full spectrum would bias entropy because silent high-freq bins
            // all approach zero, artificially lowering the entropy score.
            if (totalEnergy > 1e-15) {
              double bandEnergy = 0.0;
              for (int i = 1; i <= entropyHighBin; i++) {
                final r = freq[i].x, im = freq[i].y;
                bandEnergy += r * r + im * im;
              }
              if (bandEnergy > 1e-15) {
                double entropy = 0.0;
                for (int i = 1; i <= entropyHighBin; i++) {
                  final r  = freq[i].x;
                  final im = freq[i].y;
                  final p  = (r * r + im * im) / bandEnergy;
                  if (p > 1e-12) entropy -= p * log(p);
                }
                final maxEntropy = log(entropyHighBin.toDouble());
                computedEntropy  = maxEntropy > 0
                    ? (entropy / maxEntropy).clamp(0.0, 1.0)
                    : 1.0;
              }
            }
          });
        } catch (e) {
          debugPrint('FFT Error: $e');
        }
      }
    }

    // ── Autocorrelation Pitch (F0) Detection ───────────────────────
    // Direct autocorrelation on raw PCM samples — the most reliable method
    // for periodic signals like snoring. The lag with the highest correlation
    // corresponds to one pitch period, giving us F0 = sampleRate / lag.
    // Snoring fundamental: 60–300 Hz. Fans/HVAC: aperiodic → no clear peak.
    double? cepstralF0;
    if (rms >= tracker.noiseFloor + 0.002 && sampleCount >= 512) {
      try {
        // Use up to 2048 samples for autocorrelation (enough for 60Hz at 8kHz)
        final acSamples = min(sampleCount, 2048);
        final samples = Float64List(acSamples);
        int si = 0;
        for (int b = startByte; b < endByte - 1 && si < acSamples; b += step) {
          samples[si++] = byteData.getInt16(b, Endian.little) / 32768.0;
        }

        // Lag range: sampleRate/300Hz to sampleRate/60Hz
        final minLag = max(1, (sampleRate / _f0SnoreHighHz).round());
        final maxLag = min(acSamples ~/ 2, (sampleRate / _f0SnoreLowHz).round());

        double maxCorr = -double.infinity;
        int bestLag = minLag;
        // Normalized autocorrelation: AC(lag) / AC(0)
        final ac0 = samples.fold(0.0, (s, x) => s + x * x);
        if (ac0 > 1e-10) {
          for (int lag = minLag; lag <= maxLag; lag++) {
            double corr = 0.0;
            final limit = acSamples - lag;
            for (int i = 0; i < limit; i++) {
              corr += samples[i] * samples[i + lag];
            }
            corr /= ac0; // normalize
            if (corr > maxCorr) { maxCorr = corr; bestLag = lag; }
          }
          // Accept if normalized correlation > 0.15 (indicates periodic signal)
          if (maxCorr > 0.15 && bestLag > 0) {
            cepstralF0 = sampleRate / bestLag.toDouble();
          }
        }
      } catch (e) {
        // Non-fatal
      }
    }

    // ── Spectral Voting ────────────────────────────────────────────
    // Score ≥ 2 → snoring confirmed.
    //
    //  Feature                       Condition                  Votes
    //  ──────────────────────────────────────────────────────────────
    //  1. Amplitude gate             rms > floor + 0.003        +1
    //  2. Strong spectral (SBER)     SBER ≥ 0.50                +2
    //     Weak spectral (SBER)       SBER ≥ 0.35                +1
    //  3. Ordered signal (entropy)   entropy ≤ 0.75             +1
    //  4. Autocorrelation F0 pitch   60 Hz ≤ F0 ≤ 300 Hz        +1
    int snoreVote = 0;
    if (rms >= tracker.noiseFloor + 0.002) snoreVote += 1; // extremely low gate

    if (computedSber >= _sberStrongThreshold) {
      snoreVote += 2;
    } else if (computedSber >= _sberWeakThreshold) {
      snoreVote += 1;
    }
    if (computedEntropy <= _maxEntropyForSnoring) { snoreVote += 1; }
    if (cepstralF0 != null && cepstralF0 >= _f0SnoreLowHz && cepstralF0 <= _f0SnoreHighHz) {
      snoreVote += 1;
    }

    bool isSnoring = snoreVote >= _minSnoreVote;

    // ── Multi-Layer Veto System ────────────────────────────────────
    // Even if a window has enough votes, any of the following conditions
    // can veto the snore classification. Each targets a specific noise type.

    // VETO 1 — High-Pitch Frequency:
    // F0 > 300 Hz means animal (cat/dog), baby, or high-pitched instrument.
    final bool isHighPitchVetoed = cepstralF0 != null && cepstralF0 > _f0SnoreHighHz;
    if (isHighPitchVetoed) isSnoring = false;

    // VETO 2 — Speech Formant Ratio (SFR):
    // Strong energy in 1000–3000 Hz band indicates human speech formants.
    // Snoring concentrates energy in 50–800 Hz, not in the formant range.
    final bool isFormantVetoed = computedSfr > _speechFormantRatioThreshold;
    if (isFormantVetoed) isSnoring = false;

    // VETO 3 — Spectral Rolloff:
    // If 85% of energy lies above 700 Hz, the source is speech or music,
    // not low-frequency respiratory snoring.
    final bool isRolloffVetoed = spectralRolloffHz > _spectralRolloffThreshold && spectralRolloffHz > 0;
    if (isRolloffVetoed) isSnoring = false;

    // VETO 4 — Temporal Pitch Instability:
    // Snoring is a steady, repetitive respiratory sound with stable pitch.
    // Speech and music have rapidly varying F0 across windows.
    // Track F0 in the rolling buffer and veto if std-dev is too high.
    bool isPitchInstabilityVetoed = false;
    if (cepstralF0 != null) {
      final f0StdDev = tracker.trackF0(cepstralF0);
      if (f0StdDev > _f0InstabilityThreshold) {
        isPitchInstabilityVetoed = true;
        isSnoring = false;
      }
    }

    // ── ML Classification ──────────────────────────────────────────
    NoiseType mlNoiseType = NoiseType.ambient;
    if (rms >= tracker.noiseFloor + 0.002) {
      mlNoiseType = mlClassifier.classifyAudio(Float32List.sublistView(floatList, 0, sampleCount));
    }

    // ── Noise Classification ───────────────────────────────────────
    // ML Override: If YAMNet strongly identifies this as talking/animals/music,
    // we veto the heuristic snore classification.
    if (mlNoiseType == NoiseType.talking) {
      isSnoring = false;
    } else if (mlNoiseType == NoiseType.snoring) {
      // If ML strongly detects a snore, force it even if heuristics missed it
      isSnoring = true;
    }

    NoiseType noiseType = NoiseType.ambient;
    if (isSnoring) {
      noiseType = NoiseType.snoring;
    } else if (mlNoiseType != NoiseType.ambient) {
      // Use ML classification if it found something
      noiseType = mlNoiseType;
    } else if (isHighPitchVetoed) {
      // High-pitched vocalization (cat, dog, baby) → talking/vocalization
      noiseType = NoiseType.talking;
    } else if (isFormantVetoed || isPitchInstabilityVetoed) {
      // Strong speech formants or unstable pitch → human speech or TV
      noiseType = NoiseType.talking;
    } else if (isRolloffVetoed) {
      // High spectral rolloff with no formants → music or broadband noise
      noiseType = NoiseType.talking;
    } else if (rms >= tracker.noiseFloor + 0.02) {
      // Loud noise, none of the above patterns matched.
      if (cepstralF0 != null && computedSber >= 0.25) {
        noiseType = NoiseType.talking;
      } else if (cepstralF0 == null && computedEntropy > 0.8) {
        // Unstructured broadband burst (rustling, door slam, footsteps)
        noiseType = NoiseType.movement;
      }
    }

    // Debug: log every window's features so we can tune thresholds easily
    debugPrint(
      '[Snore @${timeSeconds.toStringAsFixed(1)}s] '
      'rms=${rms.toStringAsFixed(4)} floor=${tracker.noiseFloor.toStringAsFixed(4)} '
      'SBER=${computedSber.toStringAsFixed(3)} SFR=${computedSfr.toStringAsFixed(3)} '
      'Rolloff=${spectralRolloffHz.toStringAsFixed(0)}Hz '
      'entropy=${computedEntropy.toStringAsFixed(3)} '
      'F0=${cepstralF0?.toStringAsFixed(1) ?? "null"} '
      'vote=$snoreVote '
      'vetoes=[${isHighPitchVetoed ? "pitch " : ""}${isFormantVetoed ? "formant " : ""}${isRolloffVetoed ? "rolloff " : ""}${isPitchInstabilityVetoed ? "instability " : ""}]'
      ' → ${noiseType.name}',
    );

    // ── Sleep stage classification ─────────────────────────────────
    SleepStage stage;
    SnoreIntensity intensity = SnoreIntensity.none;

    if (isSnoring) {
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
      noiseType: noiseType,
      stage: stage,
      intensity: intensity,
      dominantFrequencyHz: dominantFreq,
      sber: computedSber > 0 ? computedSber : null,
      fundamentalHz: cepstralF0,
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
    required List<double> finalBaselines,
    int goalMinutes = 480,
    DateTime? recordedAt,
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
        ? max(1, (timeline[1].timeSeconds - timeline[0].timeSeconds).round())
        : _targetWindowSeconds;
    final snoringDuration = Duration(seconds: snoringWindowCount * winSec);

    final snoringPct = totalDuration.inSeconds > 0
        ? (snoringDuration.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    // ── Sleep quality score ─────────────────────────────────────────
    final snoringPenalty = snoringPct * 60;
    final fragmentationPenalty = min(20.0, events.length * 1.5);
    final hours = totalDuration.inSeconds / 3600.0;
    final durationBonus = min(10.0, hours * 1.5);

    // Penalize for movement and vocal disruptions (new noise classification)
    final movementWindows = timeline.where((s) => s.noiseType == NoiseType.movement).length;
    final talkingWindows  = timeline.where((s) => s.noiseType == NoiseType.talking).length;
    final totalWindows    = max(1, timeline.length);
    final movementPct = movementWindows / totalWindows;
    final talkingPct  = talkingWindows  / totalWindows;
    final disruptionPenalty = (movementPct * 20.0) + (talkingPct * 15.0);

    final rawScore = 100 - snoringPenalty - fragmentationPenalty - disruptionPenalty + durationBonus;
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

    // ── Sleep stage percentages ─────────────────────────────────────
    // Use the already-computed stage field from _analyseWindow / smoothing / cycle model
    // instead of re-classifying from raw amplitude (which throws away all that work).
    final quietWindows = timeline.where((s) => !s.isSnoring).toList();
    int deepCount = 0, remCount = 0, lightCount = 0;
    for (final s in quietWindows) {
      switch (s.stage) {
        case SleepStage.deep:  deepCount++;  break;
        case SleepStage.rem:   remCount++;   break;
        case SleepStage.light: lightCount++; break;
        default: lightCount++; // awake windows during non-snoring = treat as light
      }
    }
    final nonSnoringTotal = max(1, quietWindows.length);
    double deep  = (deepCount  / nonSnoringTotal).clamp(0.10, 0.40);
    double rem   = (remCount   / nonSnoringTotal).clamp(0.10, 0.35);
    double light = (lightCount / nonSnoringTotal).clamp(0.15, 0.70);
    final stageTotal = deep + rem + light;
    deep /= stageTotal; rem /= stageTotal; light /= stageTotal;

    final goalHours = goalMinutes / 60.0;
    final debtHours = max(0.0, goalHours - hours);

    // ── CSG Apnea Pattern Detection ────────────────────────────────
    final avgNoiseFloor = finalBaselines.isNotEmpty
        ? finalBaselines.reduce((a, b) => a + b) / finalBaselines.length
        : 0.012;
    final apneaResult = ApneaPatternDetector.detect(
      timeline: timeline,
      snoringEvents: events,
      totalDuration: totalDuration,
      noiseFloor: avgNoiseFloor,
    );

    // Upgrade apnea risk using clinical AHI thresholds
    String clinicalApneaRisk = apneaRisk;
    if (apneaResult.ahi >= 30) {
      clinicalApneaRisk = 'Severe';
    } else if (apneaResult.ahi >= 15) {
      clinicalApneaRisk = 'High';
    } else if (apneaResult.ahi >= 5) {
      clinicalApneaRisk = 'Moderate';
    }

    return SleepReport(
      fileName: fileName,
      recordedAt: recordedAt ?? DateTime.now(),
      totalDuration: totalDuration,
      snoringDuration: snoringDuration,
      snoringEventCount: events.length,
      qualityScore: qualityScore,
      quality: quality,
      snoringEvents: events,
      amplitudeTimeline: timeline,
      insights: _generateInsights(quality, snoringPct, events.length, peakTimelineAmp, totalDuration, apneaResult.ahi),
      sleepDebtHours: (debtHours * 10).roundToDouble() / 10,
      lightSleepPercent: light,
      deepSleepPercent: deep,
      remSleepPercent: rem,
      apneaRiskLevel: clinicalApneaRisk,
      cpapUsageDuration: cpapUsage,
      detectedApneaEvents: apneaResult.events,
      apneaHypopneaIndex: apneaResult.ahi,
    );
  }

  List<SleepInsight> _generateInsights(
    SleepQuality quality,
    double snoringPct,
    int eventCount,
    double peakTimelineAmp,
    Duration totalDuration,
    double ahi,
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

    // Apnea-Hypopnea Index (AHI) — clinical thresholds
    if (ahi >= 30) {
      insights.add(SleepInsight(
        title: 'Severe Apnea Risk Indicator',
        emoji: '🚨',
        description: 'An AHI (Apnea-Hypopnea Index) of ${ahi.toStringAsFixed(1)} was detected — indicating severe risk. '
            'Please consult a sleep specialist immediately.',
      ));
    } else if (ahi >= 15) {
      insights.add(SleepInsight(
        title: 'High Apnea Risk Indicator',
        emoji: '🩺',
        description: 'An AHI (Apnea-Hypopnea Index) of ${ahi.toStringAsFixed(1)} was detected — above the clinical threshold of 15. '
            'We strongly recommend a sleep study consultation.',
      ));
    } else if (ahi >= 5) {
      insights.add(SleepInsight(
        title: 'Moderate Apnea Risk Indicator',
        emoji: '⚠️',
        description: 'An AHI (Apnea-Hypopnea Index) of ${ahi.toStringAsFixed(1)} was detected. '
            'This suggests mild to moderate sleep apnea. Monitor your symptoms and consider a follow-up.',
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

    // Hydration tip — only shown when snoring was detected
    if (snoringPct > 0.02) {
      insights.add(const SleepInsight(
        title: 'Hydration Tip',
        emoji: '💧',
        description: 'Dehydration worsens snoring. Aim for 8 glasses of water throughout the day, and avoid alcohol within 3 hours of bed.',
      ));
    }

    return insights;
  }

  /// Extracts snore events from the source audio file and writes them into separate WAV files.
  /// Groups events that are within 30 seconds of each other into the same session.
  /// Returns a list of the generated clips.
  Future<List<SnoreAudioClip>> extractSnoreAudio(
    String sourcePath, 
    List<SnoringEvent> events,
    {Duration? actualDuration}
  ) async {
    if (events.isEmpty) return [];

    try {
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) return [];

      final raf = sourceFile.openSync(mode: FileMode.read);
      final headerBytes = Uint8List(44);
      raf.readIntoSync(headerBytes);

      int numChannels = 1;
      int sampleRate = 16000;
      int bitsPerSample = 16;
      int dataStart = 0;

      if (_isWav(headerBytes)) {
        final byteData = ByteData.sublistView(headerBytes);
        numChannels = byteData.getUint16(22, Endian.little);
        sampleRate = byteData.getUint32(24, Endian.little);
        bitsPerSample = byteData.getUint16(34, Endian.little);
        
        raf.setPositionSync(0);
        final scanBytes = Uint8List(min(1000, sourceFile.lengthSync()));
        raf.readIntoSync(scanBytes);
        dataStart = _findDataChunk(scanBytes);
        if (dataStart == -1) dataStart = 44;
      }

      final bytesPerSample = (bitsPerSample ~/ 8) * numChannels;
      
      int totalDataBytes = sourceFile.lengthSync() - dataStart;
      double durationMs = actualDuration != null && actualDuration.inMilliseconds > 0
          ? actualDuration.inMilliseconds.toDouble()
          : (totalDataBytes / bytesPerSample / sampleRate * 1000);
      
      // Group events into sessions if they are within 30 seconds of each other.
      final sessions = <List<SnoringEvent>>[];
      List<SnoringEvent> currentSession = [events.first];
      
      for (int i = 1; i < events.length; i++) {
        final current = events[i];
        final previous = currentSession.last;
        final previousEnd = previous.timestamp + previous.duration;
        
        if ((current.timestamp - previousEnd).inSeconds <= 10) { // Changed to 10s break
          currentSession.add(current);
        } else {
          sessions.add(currentSession);
          currentSession = [current];
        }
      }
      sessions.add(currentSession);
      
      final clips = <SnoreAudioClip>[];

      for (int i = 0; i < sessions.length; i++) {
        final sessionEvents = sessions[i];
        final sessionStart = sessionEvents.first.timestamp;
        
        // Sum up the actual duration of the extracted events (since gaps are skipped)
        Duration actualClipDuration = Duration.zero;
        for (final e in sessionEvents) {
          actualClipDuration += e.duration;
        }
        
        final extIndex = sourcePath.lastIndexOf('.');
        final destPath = extIndex != -1 
            ? '${sourcePath.substring(0, extIndex)}_snore_$i.wav'
            : '${sourcePath}_snore_$i.wav';
        
        final outDestFile = File(destPath);
        if (outDestFile.existsSync()) outDestFile.deleteSync();
        final outRaf = outDestFile.openSync(mode: FileMode.write);

        // Write placeholder WAV header
        outRaf.writeFromSync(Uint8List(44));
        
        int totalDataBytesWritten = 0;

        for (final event in sessionEvents) {
          double startRatio = event.timestamp.inMilliseconds / durationMs;
          double lenRatio = event.duration.inMilliseconds / durationMs;
          
          int startOffset = (startRatio * totalDataBytes).floor();
          startOffset -= startOffset % bytesPerSample;
          startOffset = startOffset.clamp(0, totalDataBytes);
          
          int lengthBytes = (lenRatio * totalDataBytes).floor();
          lengthBytes -= lengthBytes % bytesPerSample;
          lengthBytes = lengthBytes.clamp(0, totalDataBytes - startOffset);
          
          if (lengthBytes == 0) continue;
          
          raf.setPositionSync(dataStart + startOffset);
          
          int remaining = lengthBytes;
          final buffer = Uint8List(4096);
          while (remaining > 0) {
            final toRead = min(remaining, buffer.length);
            final bytesRead = raf.readIntoSync(buffer, 0, toRead);
            if (bytesRead == 0) break;
            
            outRaf.writeFromSync(buffer, 0, bytesRead);
            totalDataBytesWritten += bytesRead;
            remaining -= bytesRead;
          }
        }

        // Update WAV header
        final fileSize = totalDataBytesWritten + 36;
        final header = ByteData(44);
        
        header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
        header.setUint32(4, fileSize, Endian.little);
        header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
        header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 1, Endian.little);
        header.setUint16(22, numChannels, Endian.little);
        header.setUint32(24, sampleRate, Endian.little);
        header.setUint32(28, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little);
        header.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little);
        header.setUint16(34, bitsPerSample, Endian.little);
        header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
        header.setUint32(40, totalDataBytesWritten, Endian.little);

        outRaf.setPositionSync(0);
        outRaf.writeFromSync(header.buffer.asUint8List());
        outRaf.closeSync();
        
        clips.add(SnoreAudioClip(
          timestamp: sessionStart,
          duration: actualClipDuration,
          localPath: destPath,
        ));
      }

      raf.closeSync();
      return clips;
    } catch (e) {
      RecordingLogger().error('Failed to extract snore audio clips', e);
      return [];
    }
  }
}
