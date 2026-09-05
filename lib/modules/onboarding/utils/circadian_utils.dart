class CircadianUtils {
  static double calculateSleepDuration(String bedtime, String wakeTime) {
    if (bedtime.isEmpty || wakeTime.isEmpty) return 8.0;
    try {
      final bParts = bedtime.split(':');
      final wParts = wakeTime.split(':');
      final bH = int.parse(bParts[0]);
      final bM = int.parse(bParts[1]);
      final wH = int.parse(wParts[0]);
      final wM = int.parse(wParts[1]);

      int diffMinutes = (wH * 60 + wM) - (bH * 60 + bM);
      if (diffMinutes <= 0) diffMinutes += 24 * 60;
      return double.parse((diffMinutes / 60).toStringAsFixed(2));
    } catch (_) {
      return 8.0;
    }
  }

  static String formatDurationHours(double hours) {
    if (hours.isNaN) return '0h';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String formatTime12H(String time24) {
    if (time24.isEmpty) return '';
    try {
      final parts = time24.split(':');
      int h = int.parse(parts[0]);
      final int m = int.parse(parts[1]);
      final ampm = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      final mFormatted = m < 10 ? '0$m' : '$m';
      return '$h:$mFormatted $ampm';
    } catch (_) {
      return time24;
    }
  }

  static int timeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final parts = timeStr.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return (h * 60) + m;
  }

  static String minutesToTime(int mins) {
    int normalized = mins.round() % 1440;
    if (normalized < 0) normalized += 1440;
    final h = normalized ~/ 60;
    final m = normalized % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class CircadianAnalysisResult {
  final double currentDuration;
  final double targetDuration;
  final double dailyDebt;
  final double weeklyDebt;
  final String recommendedBedtime;
  final String recommendedWakeTime;
  final double recommendedDuration;
  final String transitionStrategy;
  final String debtCategory;

  CircadianAnalysisResult({
    required this.currentDuration,
    required this.targetDuration,
    required this.dailyDebt,
    required this.weeklyDebt,
    required this.recommendedBedtime,
    required this.recommendedWakeTime,
    required this.recommendedDuration,
    required this.transitionStrategy,
    required this.debtCategory,
  });

  static CircadianAnalysisResult compute(
    String currentBed,
    String currentWake,
    String targetBed,
    String targetWake,
  ) {
    final currentDuration = CircadianUtils.calculateSleepDuration(currentBed, currentWake);
    final targetDuration = CircadianUtils.calculateSleepDuration(targetBed, targetWake);

    final rawDebt = targetDuration - currentDuration;
    final dailyDebt = rawDebt > 0 ? double.parse(rawDebt.toStringAsFixed(2)) : 0.0;
    final weeklyDebt = double.parse((dailyDebt * 7).toStringAsFixed(1));

    final curBedMins = CircadianUtils.timeToMinutes(currentBed);
    final tgtBedMins = CircadianUtils.timeToMinutes(targetBed);
    int bedDiff = tgtBedMins - curBedMins;
    if (bedDiff > 720) bedDiff -= 1440;
    if (bedDiff < -720) bedDiff += 1440;

    final curWakeMins = CircadianUtils.timeToMinutes(currentWake);
    final tgtWakeMins = CircadianUtils.timeToMinutes(targetWake);
    int wakeDiff = tgtWakeMins - curWakeMins;
    if (wakeDiff > 720) wakeDiff -= 1440;
    if (wakeDiff < -720) wakeDiff += 1440;

    const maxStepShift = 45;
    final stepBedShift = bedDiff.abs() <= maxStepShift ? bedDiff : bedDiff.sign * maxStepShift;
    final stepWakeShift = wakeDiff.abs() <= maxStepShift ? wakeDiff : wakeDiff.sign * maxStepShift;

    final recBedMins = curBedMins + stepBedShift;
    final recWakeMins = curWakeMins + stepWakeShift;

    final recommendedBedtime = CircadianUtils.minutesToTime(recBedMins);
    final recommendedWakeTime = CircadianUtils.minutesToTime(recWakeMins);
    final recommendedDuration = CircadianUtils.calculateSleepDuration(recommendedBedtime, recommendedWakeTime);

    String debtCategory = 'Optimal';
    if (dailyDebt >= 2.0) {
      debtCategory = 'Severe';
    } else if (dailyDebt >= 1.0) {
      debtCategory = 'Moderate';
    } else if (dailyDebt > 0.25) {
      debtCategory = 'Mild';
    }

    String transitionStrategy = 'Circadian Synchronized';
    if (bedDiff.abs() > 15 || wakeDiff.abs() > 15) {
      final shiftDir = bedDiff < 0 ? 'Advance' : 'Delay';
      final shiftAmt = stepBedShift.abs();
      transitionStrategy = 'Phase $shiftDir (${shiftAmt}m stepping window)';
    }

    return CircadianAnalysisResult(
      currentDuration: currentDuration,
      targetDuration: targetDuration,
      dailyDebt: dailyDebt,
      weeklyDebt: weeklyDebt,
      recommendedBedtime: recommendedBedtime,
      recommendedWakeTime: recommendedWakeTime,
      recommendedDuration: recommendedDuration,
      transitionStrategy: transitionStrategy,
      debtCategory: debtCategory,
    );
  }
}
