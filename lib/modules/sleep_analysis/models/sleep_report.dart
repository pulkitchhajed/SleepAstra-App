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

/// Represents a suspected sleep apnea event derived from snoring gaps
class SuspectedApneaEvent {
  final Duration timestamp;
  final Duration gapDuration;
  final ApneaEventType type;
  final double peakRecoveryAmplitude;

  const SuspectedApneaEvent({
    required this.timestamp,
    required this.gapDuration,
    required this.type,
    required this.peakRecoveryAmplitude,
  });
}

/// Amplitude sample for the timeline chart
class AmplitudeSample {
  final double timeSeconds; // x-axis
  final double amplitude; // y-axis (0.0 – 1.0)
  final bool isSnoring;
  final SleepStage stage;
  final SnoreIntensity intensity;
  final double? dominantFrequencyHz; // Added for FFT graph

  const AmplitudeSample({
    required this.timeSeconds,
    required this.amplitude,
    required this.isSnoring,
    this.stage = SleepStage.light,
    this.intensity = SnoreIntensity.none,
    this.dominantFrequencyHz,
  });
}

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
  });

  double get snoringPercentage =>
      totalDuration.inSeconds > 0
          ? (snoringDuration.inSeconds / totalDuration.inSeconds) * 100
          : 0;

  /// Dynamically computes suspected apnea events from snoring gaps.
  /// A gap of 10-120 seconds between snoring bursts indicates a possible breathing pause.
  List<SuspectedApneaEvent> get suspectedApneaEvents {
    final apneas = <SuspectedApneaEvent>[];
    if (snoringEvents.length < 2) return apneas;

    for (int i = 0; i < snoringEvents.length - 1; i++) {
      final current = snoringEvents[i];
      final next = snoringEvents[i + 1];

      final currentEnd = current.timestamp + current.duration;
      final gap = next.timestamp - currentEnd;

      // Clinical definition: A pause in breathing >= 10 seconds.
      // We cap at 120s because longer gaps are more likely just quiet sleep.
      if (gap.inSeconds >= 10 && gap.inSeconds <= 120) {
        apneas.add(SuspectedApneaEvent(
          timestamp: currentEnd,
          gapDuration: gap,
          type: ApneaEventType.breathingPause,
          peakRecoveryAmplitude: next.amplitude,
        ));
      }
    }
    return apneas;
  }

  String get qualityLabel {
    switch (quality) {
      case SleepQuality.excellent:
        return 'Excellent';
      case SleepQuality.good:
        return 'Good';
      case SleepQuality.fair:
        return 'Fair';
      case SleepQuality.poor:
        return 'Poor';
    }
  }

  String get qualityEmoji {
    switch (quality) {
      case SleepQuality.excellent:
        return '🌟';
      case SleepQuality.good:
        return '😊';
      case SleepQuality.fair:
        return '😐';
      case SleepQuality.poor:
        return '😴';
    }
  }
}
