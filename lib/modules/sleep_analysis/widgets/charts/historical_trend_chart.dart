import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_report.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/chart_theme.dart';
import '../../../../core/providers/theme_provider.dart';

class HistoricalTrendChart extends StatelessWidget {
  final List<SleepReport> history;

  const HistoricalTrendChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    if (history.length < 2) return const SizedBox.shrink();

    // Sort ascending for chart (oldest to newest)
    final sorted = List<SleepReport>.from(history)..sort((SleepReport a, SleepReport b) => a.recordedAt.compareTo(b.recordedAt));

    // Limit to last 14 sessions for readable chart
    final displayHistory = sorted.length > 14 ? sorted.sublist(sorted.length - 14) : sorted;

    final List<FlSpot> scoreSpots = [];
    final List<FlSpot> eventSpots = [];
    double maxEvents = 10; // Minimum y-axis for events

    for (int i = 0; i < displayHistory.length; i++) {
      final r = displayHistory[i];
      scoreSpots.add(FlSpot(i.toDouble(), r.qualityScore));
      final events = r.snoringEventCount.toDouble();
      eventSpots.add(FlSpot(i.toDouble(), events));
      if (events > maxEvents) maxEvents = events;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Trends',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Legend(color: AppTheme.accentTeal, label: 'Sleep Score (0-100)'),
              const SizedBox(width: 16),
              _Legend(color: AppTheme.error, label: 'Snore Events'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: max(100, maxEvents * 1.2), // fit both lines on same graph nicely
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => cardBg,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= displayHistory.length) return null;
                        final r = displayHistory[idx];
                        if (spot.barIndex == 0) {
                          return LineTooltipItem(
                            '${r.qualityScore.toInt()} Score\n${DateFormat('MMM d').format(r.recordedAt)}',
                            const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
                          );
                        } else {
                          return LineTooltipItem(
                            '${r.snoringEventCount} Events\n${DateFormat('MMM d').format(r.recordedAt)}',
                            const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
                          );
                        }
                      }).toList();
                    },
                  ),
                ),
                gridData: ChartTheme.gridData(isLight),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (displayHistory.length / 5).ceil().toDouble(), // Show max ~5 dates
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayHistory.length) return const SizedBox.shrink();
                        final date = displayHistory[idx].recordedAt;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            DateFormat('M/d').format(date),
                            style: ChartTheme.getAxisTextStyle(isLight),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: ChartTheme.borderData,
                lineBarsData: [
                  LineChartBarData(
                    spots: scoreSpots,
                    isCurved: true,
                    color: AppTheme.accentTeal,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: cardBg,
                        strokeWidth: 2,
                        strokeColor: AppTheme.accentTeal,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: eventSpots,
                    isCurved: true,
                    color: AppTheme.error,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: cardBg,
                        strokeWidth: 2,
                        strokeColor: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: textSec, fontSize: 12),
        ),
      ],
    );
  }
}
