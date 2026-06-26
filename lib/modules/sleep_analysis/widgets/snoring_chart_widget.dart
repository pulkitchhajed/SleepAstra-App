import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sleep_report.dart';
import '../../../core/theme/app_theme.dart';

/// Interactive bar chart showing snoring amplitude over time.
class SnoringChartWidget extends StatefulWidget {
  final List<AmplitudeSample> samples;
  final Duration totalDuration;

  const SnoringChartWidget({
    super.key,
    required this.samples,
    required this.totalDuration,
  });

  @override
  State<SnoringChartWidget> createState() => _SnoringChartWidgetState();
}

class _SnoringChartWidgetState extends State<SnoringChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Downsample to at most 60 bars for readability
  List<AmplitudeSample> get _displaySamples {
    final src = widget.samples;
    if (src.length <= 60) return src;
    final step = src.length / 60;
    final result = <AmplitudeSample>[];
    for (int i = 0; i < 60; i++) {
      result.add(src[(i * step).floor()]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final samples = _displaySamples;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _Legend(color: AppTheme.error, label: 'Snoring'),
            SizedBox(width: 16),
            _Legend(color: AppTheme.primaryIndigo, label: 'Quiet'),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            // Show at most 4 labels on the x-axis, always whole-number interval
            final labelInterval = samples.isEmpty
                ? 1.0
                : (samples.length / 4).ceil().toDouble();
            // Bar width scaled to actual available pixel width
            final barWidth = samples.isEmpty
                ? 4.0
                : (availableWidth / samples.length).clamp(2.0, 10.0);

            return SizedBox(
              height: 180,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (_, __) => BarChart(
                  BarChartData(
                    maxY: 1.0,
                    minY: 0.0,
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          _touchedIndex = response?.spot?.touchedBarGroupIndex;
                        });
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppTheme.surfaceElevated,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final s = samples[group.x.toInt()];
                          final timeMin = (s.timeSeconds / 60).toStringAsFixed(0);
                          return BarTooltipItem(
                            '${timeMin}m\n${(s.amplitude * 100).toStringAsFixed(0)}%',
                            const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: labelInterval,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= samples.length || idx < 0) {
                              return const SizedBox.shrink();
                            }
                            final mins = (samples[idx].timeSeconds / 60).round();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                '${mins}m',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.25,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppTheme.cardBorder,
                        strokeWidth: 0.5,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: samples.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final isTouched = i == _touchedIndex;
                      
                      Color color;
                      if (!s.isSnoring) {
                        color = AppTheme.primaryIndigo.withValues(alpha: isTouched ? 1.0 : 0.4);
                      } else {
                        switch (s.intensity) {
                          case SnoreIntensity.quiet:
                            color = AppTheme.primaryGold.withValues(alpha: isTouched ? 1.0 : 0.9);
                            break;
                          case SnoreIntensity.moderate:
                            color = Colors.orange.withValues(alpha: isTouched ? 1.0 : 0.9);
                            break;
                          case SnoreIntensity.loud:
                          default:
                            color = AppTheme.error.withValues(alpha: isTouched ? 1.0 : 0.9);
                            break;
                        }
                      }

                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: s.amplitude * _animation.value,
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                color.withValues(alpha: 0.7),
                                color,
                              ],
                            ),
                            width: barWidth * 1.5,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 1.0,
                              color: AppTheme.cardBorder.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

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
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}
