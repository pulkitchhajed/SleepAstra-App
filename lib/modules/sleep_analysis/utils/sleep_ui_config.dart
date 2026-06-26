import 'package:flutter/material.dart';
import '../models/sleep_report.dart';
import '../../../core/theme/app_theme.dart';

extension SleepStageUI on SleepStage {
  String get displayName {
    switch (this) {
      case SleepStage.awake: return 'Awake';
      case SleepStage.light: return 'Light Sleep';
      case SleepStage.deep:  return 'Deep Sleep';
      case SleepStage.rem:   return 'REM';
    }
  }

  Color get color {
    switch (this) {
      case SleepStage.awake: return const Color(0xFFFCA5A5); // Soft blush/rose
      case SleepStage.light: return const Color(0xFF93C5FD); // Soft sky blue
      case SleepStage.deep:  return const Color(0xFF8B5CF6); // Soft purple
      case SleepStage.rem:   return const Color(0xFF5EEAD4); // Soft mint/teal
    }
  }

  /// The Y-value on a line chart for the stage
  double get chartYValue {
    switch (this) {
      case SleepStage.awake: return 3.0;
      case SleepStage.rem:   return 2.0;
      case SleepStage.light: return 1.0;
      case SleepStage.deep:  return 0.0;
    }
  }
}

extension SnoreIntensityUI on SnoreIntensity {
  String get displayName {
    switch (this) {
      case SnoreIntensity.none: return 'None';
      case SnoreIntensity.quiet: return 'Quiet';
      case SnoreIntensity.moderate: return 'Moderate';
      case SnoreIntensity.loud: return 'Loud';
      case SnoreIntensity.epic: return 'Epic';
    }
  }

  Color get color {
    switch (this) {
      case SnoreIntensity.none: return AppTheme.textSecondary;
      case SnoreIntensity.quiet: return AppTheme.primaryGold;
      case SnoreIntensity.moderate: return AppTheme.accentTeal;
      case SnoreIntensity.loud: return AppTheme.error;
      case SnoreIntensity.epic: return AppTheme.error.withValues(red: 255, green: 0, blue: 0); // brighter red
    }
  }
}

/// Helper class to hold calculated UI stats for a sleep report
class SleepStageStats {
  final int percentDeep;
  final int percentLight;
  final int percentRem;
  final int percentAwake;

  final Duration durationDeep;
  final Duration durationLight;
  final Duration durationRem;
  final Duration durationAwake;

  SleepStageStats({
    required this.percentDeep,
    required this.percentLight,
    required this.percentRem,
    required this.percentAwake,
    required this.durationDeep,
    required this.durationLight,
    required this.durationRem,
    required this.durationAwake,
  });
}

extension SleepReportUIStats on SleepReport {
  SleepStageStats calculateStageStats() {
    final totalSec = totalDuration.inSeconds.toDouble();
    if (totalSec == 0 || amplitudeTimeline.isEmpty) {
      return SleepStageStats(percentDeep: 0, percentLight: 0, percentRem: 0, percentAwake: 0, durationDeep: Duration.zero, durationLight: Duration.zero, durationRem: Duration.zero, durationAwake: Duration.zero);
    }

    int deepCount = 0;
    int lightCount = 0;
    int remCount = 0;
    int awakeCount = 0;

    for (final sample in amplitudeTimeline) {
      switch (sample.stage) {
        case SleepStage.deep: deepCount++; break;
        case SleepStage.light: lightCount++; break;
        case SleepStage.rem: remCount++; break;
        case SleepStage.awake: awakeCount++; break;
      }
    }

    final totalCount = deepCount + lightCount + remCount + awakeCount;
    if (totalCount == 0) {
      return SleepStageStats(percentDeep: 0, percentLight: 0, percentRem: 0, percentAwake: 0, durationDeep: Duration.zero, durationLight: Duration.zero, durationRem: Duration.zero, durationAwake: Duration.zero);
    }

    final nDeep = deepCount / totalCount;
    final nLight = lightCount / totalCount;
    final nRem = remCount / totalCount;
    final nAwake = awakeCount / totalCount;
    
    // Ensure percentages add up to exactly 100 in the UI
    int pDeep = (nDeep * 100).round();
    int pLight = (nLight * 100).round();
    int pRem = (nRem * 100).round();
    int pAwake = (nAwake * 100).round();
    
    final diff = 100 - (pDeep + pLight + pRem + pAwake);
    if (diff != 0) {
      if (pDeep >= pLight && pDeep >= pRem && pDeep >= pAwake) {
        pDeep += diff;
      } else if (pLight >= pDeep && pLight >= pRem && pLight >= pAwake) {
        pLight += diff;
      } else if (pRem >= pDeep && pRem >= pLight && pRem >= pAwake) {
        pRem += diff;
      } else {
        pAwake += diff;
      }
    }

    final deepDur = Duration(seconds: (totalSec * nDeep).toInt());
    final lightDur = Duration(seconds: (totalSec * nLight).toInt());
    final remDur = Duration(seconds: (totalSec * nRem).toInt());
    final awakeDur = Duration(seconds: (totalSec * nAwake).toInt());

    return SleepStageStats(
      percentDeep: pDeep,
      percentLight: pLight,
      percentRem: pRem,
      percentAwake: pAwake,
      durationDeep: deepDur,
      durationLight: lightDur,
      durationRem: remDur,
      durationAwake: awakeDur,
    );
  }
}
