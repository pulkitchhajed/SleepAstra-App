// Sleep Analysis Data Models

/// Represents a single snoring spike event detected during audio analysis
class SnoringEvent {
  final Duration timestamp;
  final double amplitude; // 0.0 – 1.0 normalized
  final Duration duration;

  const SnoringEvent({
    required this.timestamp,
    required this.amplitude,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.inMilliseconds,
        'amplitude': amplitude,
        'durationMs': duration.inMilliseconds,
      };
}

/// A recorded audio clip for a specific snoring session.
class SnoreAudioClip {
  final Duration timestamp;
  final Duration duration;
  final String localPath;
  final String? remoteUrl;

  const SnoreAudioClip({
    required this.timestamp,
    required this.duration,
    required this.localPath,
    this.remoteUrl,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'localPath': localPath,
        'remoteUrl': remoteUrl,
      };

  factory SnoreAudioClip.fromJson(Map<String, dynamic> json) {
    return SnoreAudioClip(
      timestamp: Duration(milliseconds: json['timestampMs'] as int? ?? 0),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      localPath: json['localPath'] as String? ?? '',
      remoteUrl: json['remoteUrl'] as String?,
    );
  }
}

/// Quality label derived from sleep score
enum SleepQuality { excellent, good, fair, poor }

/// Sleep Stages derived from analysis
enum SleepStage { deep, rem, light, awake }

/// Snoring Intensity levels
enum SnoreIntensity { none, quiet, moderate, loud, epic }

/// A single insight / tip surfaced from the analysis
class SleepInsight {
  final String title;
  final String description;
  final String emoji;

  const SleepInsight({
    required this.title,
    required this.description,
    required this.emoji,
  });
}

/// Apnea event types based on snoring gaps
enum ApneaEventType { breathingPause, gasping, choking, recoveryBreath }

/// Represents a suspected sleep apnea event.
/// Populated by the CrescendoSilenceGasp detector (Phase 2),
/// or by the simple gap scanner for short recordings.
class SuspectedApneaEvent {
  final Duration timestamp;
  final Duration gapDuration;
  final ApneaEventType type;
  final double peakRecoveryAmplitude;

  /// Confidence that this is a true apnea event (0–1).
  /// Higher when a crescendo build-up + recovery gasp is found.
  final double confidence;

  const SuspectedApneaEvent({
    required this.timestamp,
    required this.gapDuration,
    required this.type,
    required this.peakRecoveryAmplitude,
    this.confidence = 0.5,
  });
}

/// Categories of detected noises
enum NoiseType { snoring, talking, movement, ambient, coughing, babyCrying, pets, music, environmental }

/// Amplitude sample for the timeline chart
class AmplitudeSample {
  final double timeSeconds; // x-axis
  final double amplitude; // RMS
  final bool isSnoring;
  final NoiseType noiseType;
  final SleepStage stage;
  final SnoreIntensity intensity;

  // Additional analysis fields (optional, populated by Phase 2/3)
  final double? dominantFrequencyHz;
  final double? sber; // Snoring Band Energy Ratio
  final double? fundamentalHz; // Cepstral F0 pitch if detected

  const AmplitudeSample({
    required this.timeSeconds,
    required this.amplitude,
    required this.isSnoring,
    this.noiseType = NoiseType.ambient,
    this.stage = SleepStage.light,
    this.intensity = SnoreIntensity.none,
    this.dominantFrequencyHz,
    this.sber,
    this.fundamentalHz,
  });

  Map<String, dynamic> toJson() => {
        'timeSeconds': timeSeconds,
        'amplitude': amplitude,
        'isSnoring': isSnoring,
        'noiseType': noiseType.name,
        'stage': stage.name,
        'intensity': intensity.name,
        'dominantFrequencyHz': dominantFrequencyHz,
        'sber': sber,
        'fundamentalHz': fundamentalHz,
      };

  factory AmplitudeSample.fromJson(Map<String, dynamic> json) {
    return AmplitudeSample(
      timeSeconds: (json['timeSeconds'] as num?)?.toDouble() ?? 0.0,
      amplitude: (json['amplitude'] as num?)?.toDouble() ?? 0.0,
      isSnoring: json['isSnoring'] as bool? ?? false,
      noiseType: NoiseType.values.firstWhere(
        (e) => e.name == json['noiseType'],
        orElse: () => (json['isSnoring'] as bool? ?? false) ? NoiseType.snoring : NoiseType.ambient,
      ),
      stage: SleepStage.values.firstWhere(
        (e) => e.name == json['stage'],
        orElse: () => SleepStage.light,
      ),
      intensity: SnoreIntensity.values.firstWhere(
        (e) => e.name == json['intensity'],
        orElse: () => SnoreIntensity.none,
      ),
      dominantFrequencyHz: (json['dominantFrequencyHz'] as num?)?.toDouble(),
      sber: (json['sber'] as num?)?.toDouble(),
      fundamentalHz: (json['fundamentalHz'] as num?)?.toDouble(),
    );
  }
}

/// A single accelerometer motion sample captured during sleep.
/// Used for actigraphy-based sleep stage refinement.
class SleepMotionSample {
  final double timeSeconds;

  /// Magnitude of acceleration vector: sqrt(ax²+ay²+az²) in m/s².
  /// Sleeping: ~9.8 (gravity only). Movement: >9.9.
  final double magnitude;

  /// Movement intensity above gravity baseline (0.0 = still, 1.0 = vigorous)
  final double movementIntensity;

  const SleepMotionSample({
    required this.timeSeconds,
    required this.magnitude,
    required this.movementIntensity,
  });
}

/// Computed actigraphy-based sleep stage for a time window.
enum ActigraphyStage { deepSleep, lightSleep, remSuspected, awake }

/// Full sleep report produced after audio analysis
class SleepReport {
  final String fileName;
  final DateTime recordedAt;
  final Duration totalDuration;
  final Duration snoringDuration;
  final int snoringEventCount;
  final double qualityScore; // 0–100
  final SleepQuality quality;
  final List<SnoringEvent> snoringEvents;
  final List<AmplitudeSample> amplitudeTimeline;
  final List<SleepInsight> insights;

  // AI Synthetic Metrics
  final double sleepDebtHours;
  final double lightSleepPercent;
  final double deepSleepPercent;
  final double remSleepPercent;
  final String apneaRiskLevel;
  final Duration cpapUsageDuration;

  // ── New: Advanced Apnea Detection ──────────────────────────────────────────
  /// Apnea events discovered by the Crescendo-Silence-Gasp detector.
  /// Populated with high-confidence events (>0.7) for the AHI calculation.
  final List<SuspectedApneaEvent> detectedApneaEvents;

  /// Approximate Apnea-Hypopnea Index (events per hour of sleep).
  /// AHI < 5 = Normal, 5–15 = Mild, 15–30 = Moderate, >30 = Severe OSA.
  final double apneaHypopneaIndex;

  // ── New: Actigraphy ────────────────────────────────────────────────────────
  /// Accelerometer samples recorded during the sleep session.
  final List<SleepMotionSample> motionTimeline;

  /// Whether the actigraphy data was actually collected (false = phone not on bed)
  final bool actigraphyAvailable;

  // ── New: Snore Audio Extracts ──────────────────────────────────────────────
  /// A list of recorded snore audio clips.
  final List<SnoreAudioClip> snoreAudioClips;

  const SleepReport({
    required this.fileName,
    required this.recordedAt,
    required this.totalDuration,
    required this.snoringDuration,
    required this.snoringEventCount,
    required this.qualityScore,
    required this.quality,
    required this.snoringEvents,
    required this.amplitudeTimeline,
    required this.insights,
    this.sleepDebtHours = 0.0,
    this.lightSleepPercent = 0.50,
    this.deepSleepPercent = 0.25,
    this.remSleepPercent = 0.25,
    this.apneaRiskLevel = 'Low',
    this.cpapUsageDuration = Duration.zero,
    this.detectedApneaEvents = const [],
    this.apneaHypopneaIndex = 0.0,
    this.motionTimeline = const [],
    this.actigraphyAvailable = false,
    this.snoreAudioClips = const [],
  });

  double get snoringPercentage =>
      totalDuration.inSeconds > 0
          ? (snoringDuration.inSeconds / totalDuration.inSeconds) * 100
          : 0;

  /// Average SBER of confirmed snoring windows, expressed as 0–100.
  /// Represents how confident the algorithm is that detected sounds are snoring
  /// (vs. ambient noise). Higher = more confident.
  double get detectionConfidence {
    final snoringWindows = amplitudeTimeline
        .where((s) => s.isSnoring && s.sber != null)
        .toList();
    if (snoringWindows.isEmpty) return 0.0;
    final avgSber = snoringWindows.map((s) => s.sber!).reduce((a, b) => a + b) /
        snoringWindows.length;
    return (avgSber * 100).clamp(0.0, 100.0);
  }

  /// Average SBER across ALL audio windows (snoring + non-snoring).
  /// Used by the Frequency Profile chart to show overall audio composition.
  double get avgSnoreBandEnergyRatio {
    final windows = amplitudeTimeline.where((s) => s.sber != null).toList();
    if (windows.isEmpty) return 0.0;
    return windows.map((s) => s.sber!).reduce((a, b) => a + b) / windows.length;
  }

  /// Sleep efficiency: percentage of time in bed actually spent sleeping
  /// (i.e., not in awake stage).
  double get sleepEfficiencyPercent {
    if (amplitudeTimeline.isEmpty) return 0.0;
    final awakeWindows = amplitudeTimeline.where((s) => s.stage == SleepStage.awake).length;
    final efficiency = 1.0 - (awakeWindows / amplitudeTimeline.length);
    return (efficiency * 100).clamp(0.0, 100.0);
  }

  /// Snore-free percentage (complement of snoringPercentage).
  double get snoringFreePercent => (100.0 - snoringPercentage).clamp(0.0, 100.0);

  /// Backwards-compatible getter that returns [detectedApneaEvents] if available,
  /// otherwise falls back to the simple gap-based scanner.
  List<SuspectedApneaEvent> get suspectedApneaEvents {
    if (detectedApneaEvents.isNotEmpty) return detectedApneaEvents;

    // Simple gap scanner fallback (legacy)
    final apneas = <SuspectedApneaEvent>[];
    if (snoringEvents.length < 2) return apneas;

    for (int i = 0; i < snoringEvents.length - 1; i++) {
      final current = snoringEvents[i];
      final next = snoringEvents[i + 1];

      final currentEnd = current.timestamp + current.duration;
      final gap = next.timestamp - currentEnd;

      if (gap.inSeconds >= 10 && gap.inSeconds <= 120) {
        apneas.add(SuspectedApneaEvent(
          timestamp: currentEnd,
          gapDuration: gap,
          type: ApneaEventType.breathingPause,
          peakRecoveryAmplitude: next.amplitude,
          confidence: 0.5,
        ));
      }
    }
    return apneas;
  }

  /// AHI classification string for display
  String get ahiClassification {
    if (apneaHypopneaIndex < 5) return 'Normal';
    if (apneaHypopneaIndex < 15) return 'Mild OSA';
    if (apneaHypopneaIndex < 30) return 'Moderate OSA';
    return 'Severe OSA';
  }

  String get qualityLabel {
    switch (quality) {
      case SleepQuality.excellent: return 'Excellent';
      case SleepQuality.good:      return 'Good';
      case SleepQuality.fair:      return 'Fair';
      case SleepQuality.poor:      return 'Poor';
    }
  }

  String get qualityEmoji {
    switch (quality) {
      case SleepQuality.excellent: return '🌟';
      case SleepQuality.good:      return '😊';
      case SleepQuality.fair:      return '😐';
      case SleepQuality.poor:      return '😴';
    }
  }
}
