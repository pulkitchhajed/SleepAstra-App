import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sleep_report.dart';
import '../utils/sleep_ui_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/chart_theme.dart';

class SleepStagesChartWidget extends StatelessWidget {
  final List<AmplitudeSample> samples;
  final Duration totalDuration;
  final DateTime recordedAt;

  const SleepStagesChartWidget({
    super.key,
    required this.samples,
    required this.totalDuration,
    required this.recordedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (samples.isEmpty) return const SizedBox.shrink();

    // Downsample to at most 100 points for the hypnogram
    final displaySamples = _getDisplaySamples();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _LegendItem(color: SleepStage.deep.color, label: SleepStage.deep.displayName),
             _LegendItem(color: SleepStage.light.color, label: SleepStage.light.displayName),
             _LegendItem(color: SleepStage.rem.color, label: SleepStage.rem.displayName),
             _LegendItem(color: SleepStage.awake.color, label: SleepStage.awake.displayName),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 3,
              gridData: ChartTheme.gridData(isLight, horizontalInterval: 1),
              borderData: ChartTheme.borderData,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      String label = '';
                      switch (value.toInt()) {
                        case 0: label = SleepStage.deep.displayName; break;
                        case 1: label = SleepStage.light.displayName; break;
                        case 2: label = SleepStage.rem.displayName; break;
                        case 3: label = SleepStage.awake.displayName; break;
                      }
                      return Text(label, style: ChartTheme.getAxisTextStyle(isLight));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: max(1, (displaySamples.length / 4).floorToDouble()),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= displaySamples.length) return const SizedBox.shrink();

                      // Manually enforce interval to prevent label overlapping
                      final int step = max(1, (displaySamples.length / 4).floor());
                      if (idx % step != 0 && idx != displaySamples.length - 1) {
                        return const SizedBox.shrink();
                      }

                      final sampleSec = displaySamples[idx].timeSeconds.toInt();
                      // Adaptive label: elapsed mm:ss for very short recordings,
                      // h:mm a for < 2 h, h a for full-night sessions
                      String label;
                      if (totalDuration.inMinutes < 10) {
                        // Show elapsed time as m:ss
                        final mins = sampleSec ~/ 60;
                        final secs = sampleSec % 60;
                        label = '$mins:${secs.toString().padLeft(2, '0')}';
                      } else if (totalDuration.inHours < 2) {
                        label = DateFormat('h:mm a').format(recordedAt.add(Duration(seconds: sampleSec)));
                      } else {
                        label = DateFormat('h a').format(recordedAt.add(Duration(seconds: sampleSec)));
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
              lineBarsData: [
                LineChartBarData(
                  spots: displaySamples.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.stage.chartYValue);
                  }).toList(),
                  isCurved: false,
                  color: AppTheme.accentTeal,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.accentTeal.withValues(alpha: 0.3),
                        AppTheme.accentTeal.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: ChartTheme.lineTouchData(isLight),
            ),
          ),
        ),
      ],
    );
  }

  List<AmplitudeSample> _getDisplaySamples() {
    if (samples.length <= 100) return samples;
    final step = samples.length / 100;
    return List.generate(100, (i) => samples[(i * step).floor()]);
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}
