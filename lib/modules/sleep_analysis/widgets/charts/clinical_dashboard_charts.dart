// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/sleep_report.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/chart_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─── GRAPH 1: SNORE INTENSITY TIMELINE ─────────────────────────────
class SnoreIntensityTimelineChart extends StatelessWidget {
  final SleepReport report;
  const SnoreIntensityTimelineChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.35);
    final tooltipBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final gridLineColor = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.06);

    final rawSamples = report.amplitudeTimeline;
    if (rawSamples.isEmpty) {
      return const _EmptyChart(
        title: 'Sound Intensity Timeline',
        icon: Icons.show_chart_rounded,
        message: 'No audio data recorded',
      );
    }

    const int maxBars = 100;
    final int bucketSize = max(1, (rawSamples.length / maxBars).ceil());
    
    final List<BarChartGroupData> barGroups = [];
    double peak = 0.1;
    
    int bucketIndex = 0;
    for (int i = 0; i < rawSamples.length; i += bucketSize) {
      final chunk = rawSamples.skip(i).take(bucketSize);
      double maxAmp = 0.0;
      int snoreCount = 0;
      for (var s in chunk) {
        if (s.amplitude > maxAmp) maxAmp = s.amplitude;
        if (s.isSnoring) snoreCount++;
      }
      
      final x = chunk.first.timeSeconds;
      if (x < 0) continue;
      
      if (maxAmp > peak) peak = maxAmp;
      
      // If at least 15% of the time bucket is snoring, highlight it as a snore bucket
      final isSnoringBucket = (snoreCount / chunk.length) > 0.15;
      
      barGroups.add(BarChartGroupData(
        x: bucketIndex,
        barRods: [
          BarChartRodData(
            toY: maxAmp,
            color: isSnoringBucket ? AppTheme.error : AppTheme.primaryIndigo.withValues(alpha: 0.6),
            width: 3.0,
            borderRadius: BorderRadius.zero,
          ),
        ],
      ));
      bucketIndex++;
    }

    final maxY = min(1.0, peak * 1.5);

    return _ChartCard(
      title: 'Snore Intensity Timeline',
      subtitle: 'How loud snoring was throughout the night (approx. dB).',
      icon: Icons.show_chart_rounded,
      iconColor: AppTheme.primaryIndigo,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => tooltipBg,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final offsetSeconds = (groupIndex * bucketSize * (report.totalDuration.inSeconds / max(1, rawSamples.length))).toInt();
                final time = report.recordedAt.add(Duration(seconds: offsetSeconds));
                return BarTooltipItem(
                  '${(rod.toY * 100).toInt()} dB\n${DateFormat('hh:mm a').format(time)}',
                  TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          gridData: ChartTheme.gridData(isLight, horizontalInterval: 0.2),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: max(1, (barGroups.length / 4).floorToDouble()),
                getTitlesWidget: (value, meta) {
                  final groupIndex = value.toInt();
                  if (groupIndex < 0 || groupIndex >= barGroups.length) return const SizedBox.shrink();
                  
                  // Manually enforce interval to prevent label overlapping on short recordings
                  final int step = max(1, (barGroups.length / 4).floor());
                  if (groupIndex % step != 0 && groupIndex != barGroups.length - 1) {
                    return const SizedBox.shrink();
                  }

                  final offsetSeconds = (groupIndex * bucketSize * (report.totalDuration.inSeconds / max(1, rawSamples.length))).toInt();
                  // Adaptive label based on recording length
                  String label;
                  if (report.totalDuration.inMinutes < 10) {
                    final mins = offsetSeconds ~/ 60;
                    final secs = offsetSeconds % 60;
                    label = '$mins:${secs.toString().padLeft(2, '0')}';
                  } else if (report.totalDuration.inHours < 2) {
                    label = DateFormat('h:mm a').format(report.recordedAt.add(Duration(seconds: offsetSeconds)));
                  } else {
                    label = DateFormat('h a').format(report.recordedAt.add(Duration(seconds: offsetSeconds)));
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label,
                      style: ChartTheme.getAxisTextStyle(isLight),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: ChartTheme.borderData,
          barGroups: barGroups,
        ),
      ),
    );
  }
}

// ─── GRAPH 2: SNORE EVENTS PER HOUR ──────────────────────────────────
// ─── GRAPH 2: NOISE EVENTS PER HOUR (STACKED) ───────────────────────
class NoiseEventsPerHourChart extends StatelessWidget {
  final SleepReport report;
  const NoiseEventsPerHourChart({super.key, required this.report});

  // Ordered display groups (merge less-common into broader categories for legibility)
  static const _displayTypes = [
    NoiseType.snoring,
    NoiseType.talking,
    NoiseType.coughing,
    NoiseType.babyCrying,
    NoiseType.pets,
    NoiseType.music,
    NoiseType.environmental,
    NoiseType.movement,
    NoiseType.ambient,
  ];

  static const _colors = {
    NoiseType.snoring:       Color(0xFF8B5CF6), // purple
    NoiseType.talking:       Color(0xFF3B82F6), // blue
    NoiseType.coughing:      Color(0xFFEF4444), // red
    NoiseType.babyCrying:    Color(0xFFEC4899), // pink
    NoiseType.pets:          Color(0xFFF97316), // orange
    NoiseType.music:         Color(0xFF14B8A6), // teal
    NoiseType.environmental: Color(0xFF64748B), // slate
    NoiseType.movement:      Color(0xFFF59E0B), // amber
    NoiseType.ambient:       Color(0xFF94A3B8), // light slate
  };

  static const _labels = {
    NoiseType.snoring:       'Snoring',
    NoiseType.talking:       'Talking',
    NoiseType.coughing:      'Coughing',
    NoiseType.babyCrying:    'Crying',
    NoiseType.pets:          'Pets',
    NoiseType.music:         'Music',
    NoiseType.environmental: 'Environment',
    NoiseType.movement:      'Movement',
    NoiseType.ambient:       'Ambient',
  };

  static const _emojis = {
    NoiseType.snoring:       '😴',
    NoiseType.talking:       '🗣️',
    NoiseType.coughing:      '🤧',
    NoiseType.babyCrying:    '👶',
    NoiseType.pets:          '🐾',
    NoiseType.music:         '🎵',
    NoiseType.environmental: '🚗',
    NoiseType.movement:      '🔄',
    NoiseType.ambient:       '🌙',
  };

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.45);
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withValues(alpha: 0.25);

    final timeline = report.amplitudeTimeline;
    if (timeline.isEmpty) {
      return const _EmptyChart(
        title: 'Sound Activity Per Hour',
        icon: Icons.bar_chart_rounded,
        message: 'No audio data recorded',
      );
    }

    // Use 15-min buckets for recordings < 2 hours; hourly otherwise
    final totalMinutes = report.totalDuration.inMinutes;
    final useMinuteBuckets = totalMinutes < 120;
    final bucketSizeMin = useMinuteBuckets ? 15 : 60;
    final bucketCount = max(1, (totalMinutes / bucketSizeMin).ceil());
    final chartTitle = useMinuteBuckets ? 'Noise Duration (15-min buckets)' : 'Noise Duration Per Hour';

    final double sampleDurationMins = (report.totalDuration.inSeconds / 60.0) / max(1, timeline.length);

    // Build per-bucket durations per NoiseType
    final Map<int, Map<NoiseType, double>> hourlyData = {};
    for (int b = 0; b < bucketCount; b++) {
      hourlyData[b] = {for (var t in _displayTypes) t: 0.0};
    }

    for (final sample in timeline) {
      final bucketIndex = (sample.timeSeconds / (bucketSizeMin * 60)).floor().clamp(0, bucketCount - 1);
      final type = sample.noiseType;
      if (hourlyData[bucketIndex] != null) {
        hourlyData[bucketIndex]![type] = (hourlyData[bucketIndex]![type] ?? 0.0) + sampleDurationMins;
      }
    }

    // Build bar groups with stacked rods
    double globalMax = 0;
    final List<BarChartGroupData> barGroups = [];

    for (int b = 0; b < bucketCount; b++) {
      final counts = hourlyData[b]!;
      final total = counts.values.fold(0.0, (a, b) => a + b);
      if (total > globalMax) globalMax = total;

      final List<BarChartRodStackItem> stackItems = [];
      double fromY = 0;
      for (final type in _displayTypes) {
        final count = counts[type] ?? 0.0;
        if (count < 0.1) continue; // Ignore less than 6 seconds of noise
        stackItems.add(BarChartRodStackItem(fromY, fromY + count, _colors[type]!));
        fromY += count;
      }

      barGroups.add(BarChartGroupData(
        x: b,
        barRods: [
          BarChartRodData(
            toY: total,
            width: bucketCount > 8 ? 10 : 18,
            borderRadius: BorderRadius.circular(5),
            rodStackItems: stackItems,
            color: Colors.transparent,
          ),
        ],
      ));
    }

    // Which noise types actually appeared?
    final activeTypes = _displayTypes.where((t) {
      return hourlyData.values.any((m) => (m[t] ?? 0) > 0);
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryIndigo, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chartTitle,
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Noise type breakdown throughout the night',
                        style: TextStyle(color: textSec, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: max(5, globalMax * 1.15),
                gridData: ChartTheme.gridData(isLight),
                borderData: ChartTheme.borderData,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) => Text(
                        '${v.toInt()}m',
                        style: TextStyle(color: textSec, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: max(1, (bucketCount / 6).floorToDouble()),
                      getTitlesWidget: (v, m) {
                        final bucketIndex = v.toInt();
                        if (bucketIndex < 0 || bucketIndex >= bucketCount) return const SizedBox.shrink();

                        // Manually enforce interval to prevent label overlapping
                        final int step = max(1, (bucketCount / 6).floor());
                        if (bucketIndex % step != 0 && bucketIndex != bucketCount - 1) {
                          return const SizedBox.shrink();
                        }

                        final offsetSeconds = bucketIndex * bucketSizeMin * 60;
                        final time = report.recordedAt.add(Duration(seconds: offsetSeconds));
                        final label = useMinuteBuckets
                            ? DateFormat('h:mm').format(time)
                            : DateFormat('h a').format(time);
                        return SideTitleWidget(
                          meta: m,
                          child: Text(
                            label,
                            style: TextStyle(color: textSec, fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isLight
                        ? AppTheme.surfaceLight
                        : const Color(0xFF1A1D33),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bucketIndex = group.x;
                      final offsetSeconds = bucketIndex * bucketSizeMin * 60;
                      final time = report.recordedAt.add(Duration(seconds: offsetSeconds));
                      final timeLabel = useMinuteBuckets
                          ? DateFormat('h:mm a').format(time)
                          : DateFormat('h a').format(time);
                      final counts = hourlyData[bucketIndex]!;
                      final lines = _displayTypes
                          .where((t) => (counts[t] ?? 0.0) >= 0.1)
                          .map((t) => '${_emojis[t]} ${_labels[t]}: ${counts[t]!.toStringAsFixed(1)}m')
                          .join('\n');
                      return BarTooltipItem(
                        '$timeLabel\n$lines',
                        TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: activeTypes.map((type) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _colors[type],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_emojis[type]} ${_labels[type]}',
                    style: TextStyle(color: textSec, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


// ─── GRAPH 3: SEVERITY DISTRIBUTION ──────────────────────────────────
class SeverityDistributionChart extends StatelessWidget {
  final SleepReport report;
  const SeverityDistributionChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.snoringEvents.isEmpty) {
      return const _EmptyChart(
        title: 'Severity Distribution',
        icon: Icons.pie_chart_rounded,
        message: 'No snoring detected in this recording',
      );
    }

    int mild = 0, mod = 0, sev = 0, epic = 0;
    for (var s in report.amplitudeTimeline) {
      if (!s.isSnoring) continue;
      switch (s.intensity) {
        case SnoreIntensity.quiet: mild++; break;
        case SnoreIntensity.moderate: mod++; break;
        case SnoreIntensity.loud: sev++; break;
        case SnoreIntensity.epic: epic++; break;
        default: break;
      }
    }
    final total = mild + mod + sev + epic;
    if (total == 0) {
      return const _EmptyChart(
        title: 'Severity Distribution',
        icon: Icons.pie_chart_rounded,
        message: 'No snoring detected in this recording',
      );
    }

    List<PieChartSectionData> sections = [];
    void addSec(int val, Color color, String label) {
      if (val > 0) {
        sections.add(PieChartSectionData(
          value: val.toDouble(),
          color: color,
          title: '${(val / total * 100).toInt()}%',
          radius: 55,
          titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ));
      }
    }

    addSec(mild, AppTheme.accentTeal, 'Mild');
    addSec(mod, AppTheme.primaryGold, 'Moderate');
    addSec(sev, Colors.orange, 'Severe');
    addSec(epic, AppTheme.error, 'Very Severe');

    return _ChartCard(
      title: 'Severity Breakdown',
      subtitle: '% of snoring time at each volume level.',
      icon: Icons.pie_chart_rounded,
      iconColor: AppTheme.primaryGold,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 36,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Legend(color: AppTheme.accentTeal, label: 'Mild'),
              const SizedBox(height: 8),
              _Legend(color: AppTheme.primaryGold, label: 'Moderate'),
              const SizedBox(height: 8),
              _Legend(color: Colors.orange, label: 'Severe'),
              const SizedBox(height: 8),
              _Legend(color: AppTheme.error, label: 'Very Severe'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── GRAPH 4: ACTIVITY HEATMAP ───────────────────────────────────────
class ActivityHeatmapChart extends StatelessWidget {
  final SleepReport report;
  const ActivityHeatmapChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.3);

    if (report.amplitudeTimeline.isEmpty || report.snoringEvents.isEmpty) {
      return const _EmptyChart(
        title: 'Snoring Hotspots',
        icon: Icons.grid_view_rounded,
        message: 'No snoring detected in this recording',
      );
    }

    // Use ceil so a 7h15m recording gets 8 columns (not 9 with the +1 hack).
    // The +1 previously caused the last column to accumulate overflow samples,
    // making it appear artificially brighter.
    final hours = max(1, (report.totalDuration.inSeconds / 3600.0).ceil());
    const segmentsPerHour = 6; // 10-minute segments

    List<List<double>> grid =
        List.generate(hours, (_) => List.filled(segmentsPerHour, 0.0));
    List<List<int>> counts =
        List.generate(hours, (_) => List.filled(segmentsPerHour, 0));

    for (var s in report.amplitudeTimeline) {
      if (!s.isSnoring) continue;
      final h = (s.timeSeconds / 3600).floor();
      final seg = ((s.timeSeconds % 3600) / 600).floor();
      if (h >= 0 && h < hours && seg >= 0 && seg < segmentsPerHour) {
        grid[h][seg] += s.amplitude;
        counts[h][seg]++;
      }
    }

    for (int h = 0; h < hours; h++) {
      for (int s = 0; s < segmentsPerHour; s++) {
        if (counts[h][s] > 0) {
          grid[h][s] = grid[h][s] / counts[h][s];
        }
      }
    }

    return _ChartCard(
      title: 'Snoring Hotspots',
      subtitle: '10-minute intensity segments. Darker red = more severe.',
      icon: Icons.grid_view_rounded,
      iconColor: AppTheme.error,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / hours;
          final cellHeight = constraints.maxHeight / segmentsPerHour;

          return Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  segmentsPerHour,
                  (i) => Text(
                    '${i * 10}m',
                    style: TextStyle(
                        color: textSec, fontSize: 9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          for (int h = 0; h < hours; h++)
                            for (int s = 0; s < segmentsPerHour; s++)
                              Positioned(
                                left: h * cellWidth,
                                top: s * cellHeight,
                                width: cellWidth - 3,
                                height: cellHeight - 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _heatColor(grid[h][s], isLight),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(hours, (h) {
                        final time = report.recordedAt
                            .add(Duration(hours: h));
                        return Text(
                          DateFormat('h a').format(time),
                          style: TextStyle(
                              color: textSec,
                              fontSize: 9),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _heatColor(double amplitude, bool isLight) {
    if (amplitude == 0) return isLight ? AppTheme.textSecondaryLight.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);
    if (amplitude < 0.1) return AppTheme.accentTeal.withValues(alpha: 0.7);
    if (amplitude < 0.2) return AppTheme.primaryGold.withValues(alpha: 0.8);
    if (amplitude < 0.3) return Colors.orange.withValues(alpha: 0.9);
    return AppTheme.error;
  }
}

// ─── GRAPH 5: FREQUENCY SPECTRUM (FFT) ───────────────────────────────
class FftSpectrumChart extends StatelessWidget {
  final SleepReport report;
  const FftSpectrumChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.35);
    final gridLineColor = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.06);

    final freqs = report.amplitudeTimeline
        .where((s) => s.isSnoring && s.dominantFrequencyHz != null)
        .map((s) => s.dominantFrequencyHz!)
        .toList();

    if (freqs.isEmpty) {
      return _ChartCard(
        title: 'Frequency Spectrum',
        subtitle: 'No frequency data available for this session.',
        icon: Icons.equalizer_rounded,
        iconColor: const Color(0xFF8B5CF6),
        child: Center(
          child: Text(
            'Data recorded before FFT update',
            style: TextStyle(color: textSec),
          ),
        ),
      );
    }

    final Map<int, int> bins = {};
    for (var f in freqs) {
      final bin = (f / 50).floor() * 50;
      if (bin <= 1000) {
        bins[bin] = (bins[bin] ?? 0) + 1;
      }
    }

    final List<BarChartGroupData> barGroups = [];
    double maxCount = 0;

    final sortedBins = bins.keys.toList()..sort();
    for (int i = 0; i < sortedBins.length; i++) {
      final b = sortedBins[i];
      final c = bins[b]!;
      if (c > maxCount) maxCount = c.toDouble();
      barGroups.add(BarChartGroupData(
        x: b,
        barRods: [
          BarChartRodData(
            toY: c.toDouble(),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return _ChartCard(
      title: 'Frequency Spectrum',
      subtitle: 'Distribution of snoring pitch. Lower Hz = deeper snore.',
      icon: Icons.equalizer_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: max(5, maxCount * 1.2),
          gridData: ChartTheme.gridData(isLight),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  if (v % 200 == 0) {
                    return Text(
                      '${v.toInt()}Hz',
                      style: ChartTheme.getAxisTextStyle(isLight),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: ChartTheme.borderData,
          barGroups: barGroups,
        ),
      ),
    );
  }
}

// ─── GRAPH 6: SUSPECTED APNEA TIMELINE ───────────────────────────────
class ApneaTimelineChart extends StatelessWidget {
  final SleepReport report;
  const ApneaTimelineChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.35);
    final tooltipBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final gridLineColor = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.06);

    final apneas = report.suspectedApneaEvents;

    if (apneas.isEmpty) {
      return _ChartCard(
        title: 'Suspected Apnea Events',
        subtitle: 'Breathing pauses ≥ 10s.',
        icon: Icons.air_rounded,
        iconColor: AppTheme.accentTeal,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                'No apnea events detected!',
                style: TextStyle(
                    color: AppTheme.accentTeal,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final List<FlSpot> spots = [];
    double maxGap = 10;

    for (var a in apneas) {
      final hoursIn = a.timestamp.inSeconds / 3600;
      spots.add(FlSpot(hoursIn, a.gapDuration.inSeconds.toDouble()));
      if (a.gapDuration.inSeconds > maxGap) {
        maxGap = a.gapDuration.inSeconds.toDouble();
      }
    }

    return _ChartCard(
      title: 'Suspected Apnea Events',
      subtitle: 'Breathing pauses (gaps ≥ 10s between snores).',
      icon: Icons.air_rounded,
      iconColor: Colors.orange,
      child: ScatterChart(
        ScatterChartData(
          minX: 0,
          maxX: max(0.1, report.totalDuration.inSeconds / 3600),
          minY: 0,
          maxY: max(20, maxGap * 1.2),
          gridData: ChartTheme.gridData(isLight),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, m) => Text(
                  '${v.toInt()}s',
                  style: TextStyle(
                      color: textSec, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: max(1, (report.totalDuration.inSeconds / 3600 / 5).floorToDouble()),
                getTitlesWidget: (v, m) {
                  final int maxHours = max(1, (report.totalDuration.inSeconds / 3600).ceil());
                  final int step = max(1, (maxHours / 5).floor());
                  
                  if (v.toInt() % step != 0) {
                    return const SizedBox.shrink();
                  }

                  final time = report.recordedAt
                      .add(Duration(hours: v.toInt()));
                  return SideTitleWidget(
                    meta: m,
                    child: Text(
                      DateFormat('h a').format(time),
                      style: TextStyle(
                          color: textSec, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: ChartTheme.borderData,
          scatterSpots: spots
              .map((s) => ScatterSpot(
                    s.x,
                    s.y,
                    dotPainter: FlDotCirclePainter(
                      radius: 7,
                      color:
                          s.y >= 30 ? AppTheme.error : Colors.orange,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ))
              .toList(),
          scatterTouchData: ScatterTouchData(
            touchTooltipData: ScatterTouchTooltipData(
              getTooltipColor: (_) => tooltipBg,
              getTooltipItems: (spot) => ScatterTooltipItem(
                '${spot.y.toInt()}s Pause\n${spot.x.toStringAsFixed(1)}h in',
                textStyle: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SHARED: Chart Card ──────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final Color iconColor;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.35);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.07);

    return Container(
      height: 290,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        gradient: isLight ? null : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D33), Color(0xFF111428)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardBorder,
          width: 0.8,
        ),
        boxShadow: [
          if (!isLight)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          BoxShadow(
            color: iconColor.withValues(alpha: 0.06),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border:
                        Border.all(color: iconColor.withValues(alpha: 0.25), width: 0.8),
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textSec,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconColor.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GRAPH 7: NOISE CLASSIFICATION BREAKDOWN ─────────────────────────
class NoiseClassificationChart extends StatefulWidget {
  final SleepReport report;
  const NoiseClassificationChart({super.key, required this.report});

  @override
  State<NoiseClassificationChart> createState() => _NoiseClassificationChartState();
}

class _NoiseClassificationChartState extends State<NoiseClassificationChart> {
  int? _touchedIndex;

  static const _noiseColors = {
    NoiseType.snoring:       Color(0xFF8B5CF6), // purple
    NoiseType.talking:       Color(0xFF3B82F6), // blue
    NoiseType.coughing:      Color(0xFFEF4444), // red
    NoiseType.babyCrying:    Color(0xFFEC4899), // pink
    NoiseType.pets:          Color(0xFFF97316), // orange
    NoiseType.music:         Color(0xFF14B8A6), // teal
    NoiseType.environmental: Color(0xFF64748B), // slate
    NoiseType.movement:      Color(0xFFF59E0B), // amber
    NoiseType.ambient:       Color(0xFF94A3B8), // slate light
  };

  static const Map<NoiseType, String> _noiseLabels = {
    NoiseType.snoring:       'Snoring',
    NoiseType.talking:       'Talking',
    NoiseType.coughing:      'Coughing',
    NoiseType.babyCrying:    'Crying',
    NoiseType.pets:          'Pets',
    NoiseType.music:         'Music',
    NoiseType.environmental: 'Environmental',
    NoiseType.movement:      'Movement',
    NoiseType.ambient:       'Ambient',
  };

  static const Map<NoiseType, String> _noiseDescs = {
    NoiseType.snoring:       'Periodic low-frequency vibrations (60–300 Hz)',
    NoiseType.talking:       'Higher-pitch vocal activity detected (>300 Hz)',
    NoiseType.coughing:      'Abrupt broadband percussive bursts',
    NoiseType.babyCrying:    'High-pitched harmonic cries',
    NoiseType.pets:          'Dog barking, cat meowing, etc.',
    NoiseType.music:         'Music, radio, or TV playback',
    NoiseType.environmental: 'Vehicles, wind, sirens, etc.',
    NoiseType.movement:      'Aperiodic wideband rustling (tossing & turning)',
    NoiseType.ambient:       'Low-level constant background noise',
  };

  static const Map<NoiseType, String> _noiseEmojis = {
    NoiseType.snoring:       '😴',
    NoiseType.talking:       '🗣️',
    NoiseType.coughing:      '🤧',
    NoiseType.babyCrying:    '👶',
    NoiseType.pets:          '🐶',
    NoiseType.music:         '🎵',
    NoiseType.environmental: '🚗',
    NoiseType.movement:      '🔄',
    NoiseType.ambient:       '🌙',
  };

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.45);

    final timeline = widget.report.amplitudeTimeline;
    if (timeline.isEmpty) {
      return const _EmptyChart(
        title: 'Noise Breakdown',
        icon: Icons.donut_large_rounded,
        message: 'No audio data recorded',
      );
    }
    // Also check if all sounds are ambient (truly silent recording)
    final hasAnyNonAmbient = timeline.any((s) => s.noiseType != NoiseType.ambient || s.amplitude > 0.01);
    if (!hasAnyNonAmbient) {
      return const _EmptyChart(
        title: 'Noise Breakdown',
        icon: Icons.donut_large_rounded,
        message: 'No significant sounds detected',
      );
    }

    final counts = <NoiseType, int>{
      for (var type in NoiseType.values) type: 0,
    };
    for (final s in timeline) {
      counts[s.noiseType] = (counts[s.noiseType] ?? 0) + 1;
    }

    final totalWindows = timeline.length;
    if (totalWindows == 0) {
      return const _EmptyChart(
        title: 'Noise Breakdown',
        icon: Icons.donut_large_rounded,
        message: 'No snoring detected in this recording',
      );
    }

    // ── Duration per noise type ───────────────────────────────────────────
    // For Snoring we use the authoritative snoringDuration from the model,
    // which is the sum of all SnoringEvent.duration values — the most
    // accurate figure and the same one used by the report card percentage.
    // For every other type we derive duration proportionally from totalDuration
    // so all entries are consistent and the math always sums cleanly.
    final totalDurSec = widget.report.totalDuration.inSeconds.toDouble();
    final snoreDurSec = widget.report.snoringDuration.inSeconds.toDouble();
    final nonSnoreWindows = totalWindows - (counts[NoiseType.snoring] ?? 0);

    Duration _durationFor(NoiseType type, int count) {
      if (type == NoiseType.snoring) {
        return widget.report.snoringDuration;
      }
      if (nonSnoreWindows == 0 || count == 0) return Duration.zero;
      final nonSnoreSec = totalDurSec - snoreDurSec;
      return Duration(seconds: ((count / nonSnoreWindows) * nonSnoreSec).round());
    }

    // Build pie sections
    final displayOrder = [
      NoiseType.snoring,
      NoiseType.coughing,
      NoiseType.babyCrying,
      NoiseType.talking,
      NoiseType.pets,
      NoiseType.music,
      NoiseType.environmental,
      NoiseType.movement,
      NoiseType.ambient,
    ];

    final sections = <PieChartSectionData>[];
    int displayIdx = 0;
    for (final type in displayOrder) {
      final count = counts[type] ?? 0;
      if (count == 0) { displayIdx++; continue; }
      final pct = count / totalWindows;
      final isTouched = _touchedIndex == displayIdx;
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: _noiseColors[type]!,
        radius: isTouched ? 72 : 58,
        title: pct >= 0.05 ? '${(pct * 100).round()}%' : '',
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _noiseColors[type]!.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: _noiseColors[type]!.withValues(alpha: 0.5), blurRadius: 8)],
                ),
                child: Text(
                  _noiseLabels[type]!,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.2,
      ));
      displayIdx++;
    }

    // Active type for description
    NoiseType? activeType;
    if (_touchedIndex != null) {
      int dIdx = 0;
      for (final type in displayOrder) {
        if ((counts[type] ?? 0) == 0) { dIdx++; continue; }
        if (dIdx == _touchedIndex) { activeType = type; break; }
        dIdx++;
      }
    }

    return _ChartCard(
      title: 'Noise Breakdown',
      subtitle: 'What sounds were detected during your sleep.',
      icon: Icons.donut_large_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Donut chart
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 38,
                sectionsSpace: 3,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (response == null || response.touchedSection == null) {
                        _touchedIndex = null;
                        return;
                      }
                      _touchedIndex = response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend + description
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...displayOrder.map((type) {
                  final count = counts[type] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  final pct = count / totalWindows;
                  final dur = _durationFor(type, count);
                  final durStr = dur.inHours > 0
                      ? '${dur.inHours}h ${dur.inMinutes.remainder(60)}m'
                      : '${dur.inMinutes}m';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _noiseColors[type],
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _noiseColors[type]!.withValues(alpha: 0.5), blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_noiseEmojis[type]} ${_noiseLabels[type]}',
                                style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '$durStr  ·  ${(pct * 100).round()}% of sleep',
                                style: TextStyle(color: textSec, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Tap hint / active description
                if (activeType != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _noiseColors[activeType]!.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _noiseColors[activeType]!.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _noiseDescs[activeType]!,
                      style: TextStyle(
                        color: _noiseColors[activeType],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ] else
                  Text('Tap a section for details', style: TextStyle(color: textSec, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED: Empty Chart ─────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? message;

  const _EmptyChart({required this.title, required this.icon, this.message});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.25);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.07);

    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        gradient: isLight ? null : const LinearGradient(
          colors: [Color(0xFF1A1D33), Color(0xFF111428)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textSec, size: 28),
            const SizedBox(height: 8),
            Text(
              message ?? 'No data for $title',
              style: TextStyle(
                  color: textSec, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED: Legend ──────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.watch<ThemeProvider>().isDarkMode == false ? AppTheme.textSecondaryLight : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
