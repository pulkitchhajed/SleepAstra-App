// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/sleep_report.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Snore Cadence Chart — shows individual snoring episodes as vertical bars.
///
/// Each bar represents one detected snoring event:
///   - Height  = peak amplitude during that event (louder = taller)
///   - Color   = SnoreIntensity level (quiet/moderate/loud/epic)
///   - Gap     = silence between events (proportional to time gap)
///
/// Useful for spotting apnea patterns (clustered bursts with long silent gaps)
/// versus positional snoring (evenly distributed events).
class SnoreCadenceChart extends StatefulWidget {
  final SleepReport report;
  const SnoreCadenceChart({super.key, required this.report});

  @override
  State<SnoreCadenceChart> createState() => _SnoreCadenceChartState();
}

class _SnoreCadenceChartState extends State<SnoreCadenceChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation  = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight     = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg      = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder  = isLight ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withOpacity(0.25);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec     = isLight ? AppTheme.textSecondaryLight : Colors.white.withOpacity(0.5);
    final gridColor   = isLight ? AppTheme.cardBorderLight : Colors.white.withOpacity(0.06);

    final events = widget.report.snoringEvents;
    final totalSec = widget.report.totalDuration.inSeconds;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(color: AppTheme.error.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
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
                  color: AppTheme.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: const Icon(Icons.view_column_rounded, color: AppTheme.error, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Snore Episode Pattern', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Each bar is one snoring burst — gaps show silent periods', style: TextStyle(color: textSec, fontSize: 11)),
                  ],
                ),
              ),
              // Event count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withOpacity(0.25)),
                ),
                child: Text('${events.length} events', style: const TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (events.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentTeal, size: 36),
                    const SizedBox(height: 8),
                    Text('No snoring episodes detected', style: TextStyle(color: textSec, fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            // Chart
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: _CadencePainter(
                      events: events,
                      totalSec: totalSec,
                      animationValue: _animation.value,
                      gridColor: gridColor,
                      textSec: textSec,
                    ),
                    size: Size.infinite,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Time axis labels
            _buildTimeAxis(totalSec, textSec),
            const SizedBox(height: 16),
            // Intensity legend
            _buildIntensityLegend(textSec),
            const SizedBox(height: 16),
            // Pattern analysis insight
            _buildPatternInsight(events, totalSec, textSec, textPrimary),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeAxis(int totalSec, Color textSec) {
    if (totalSec <= 0) return const SizedBox.shrink();
    final fmt = DateFormat('HH:mm');
    final start = widget.report.recordedAt;
    final end   = start.add(Duration(seconds: totalSec));
    final mid   = start.add(Duration(seconds: totalSec ~/ 2));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(fmt.format(start), style: TextStyle(color: textSec, fontSize: 10)),
        Text(fmt.format(mid),   style: TextStyle(color: textSec, fontSize: 10)),
        Text(fmt.format(end),   style: TextStyle(color: textSec, fontSize: 10)),
      ],
    );
  }

  Widget _buildIntensityLegend(Color textSec) {
    const items = [
      ('Quiet',    Color(0xFF2DD4BF)),
      ('Moderate', Color(0xFFFACC15)),
      ('Loud',     Color(0xFFFB923C)),
      ('Very Loud',Color(0xFFEF4444)),
    ];
    return Wrap(
      spacing: 16, runSpacing: 8,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: item.$2, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(item.$1, style: TextStyle(color: textSec, fontSize: 10)),
        ],
      )).toList(),
    );
  }

  Widget _buildPatternInsight(List<SnoringEvent> events, int totalSec, Color textSec, Color textPrimary) {
    if (events.length < 2) {
      return const SizedBox.shrink();
    }

    // Compute average gap between events
    double totalGap = 0;
    for (int i = 0; i < events.length - 1; i++) {
      final endOfCurrent = events[i].timestamp + events[i].duration;
      final gap = events[i + 1].timestamp - endOfCurrent;
      totalGap += gap.inSeconds.toDouble();
    }
    final avgGapSec = totalGap / (events.length - 1);
    final apneaSuspect = widget.report.suspectedApneaEvents.length;

    String patternLabel;
    Color patternColor;
    IconData patternIcon;

    if (apneaSuspect > 3) {
      patternLabel = '$apneaSuspect pauses of 10–120s detected — possible apnea pattern. Consult a specialist.';
      patternColor = AppTheme.error;
      patternIcon  = Icons.warning_amber_rounded;
    } else if (avgGapSec < 30) {
      patternLabel = 'Frequent, closely-spaced episodes (avg ${avgGapSec.toInt()}s gap) — may indicate continuous snoring.';
      patternColor = AppTheme.primaryGold;
      patternIcon  = Icons.repeat_rounded;
    } else {
      patternLabel = 'Intermittent pattern (avg ${avgGapSec.toInt()}s gap) — typical positional or mild snoring.';
      patternColor = AppTheme.accentTeal;
      patternIcon  = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: patternColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: patternColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(patternIcon, color: patternColor, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(patternLabel, style: TextStyle(color: patternColor, fontSize: 11, height: 1.5))),
        ],
      ),
    );
  }
}

class _CadencePainter extends CustomPainter {
  final List<SnoringEvent> events;
  final int totalSec;
  final double animationValue;
  final Color gridColor;
  final Color textSec;

  _CadencePainter({required this.events, required this.totalSec, required this.animationValue, required this.gridColor, required this.textSec});

  Color _intensityColor(double amplitude) {
    if (amplitude < 0.08)  return const Color(0xFF2DD4BF); // quiet - teal
    if (amplitude < 0.18)  return const Color(0xFFFACC15); // moderate - gold
    if (amplitude < 0.30)  return const Color(0xFFFB923C); // loud - orange
    return const Color(0xFFEF4444);                         // epic - red
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSec <= 0 || events.isEmpty) return;

    // Draw horizontal grid lines
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final double minBarWidth = 3.0;
    final double maxBarWidth = max(minBarWidth, (size.width / max(events.length, 1)) * 0.6);

    for (final event in events) {
      final x = (event.timestamp.inSeconds / totalSec) * size.width;
      final barH = (event.amplitude * size.height * animationValue).clamp(4.0, size.height);

      final paint = Paint()
        ..color = _intensityColor(event.amplitude)
        ..style = PaintingStyle.fill;

      final barW = maxBarWidth.clamp(minBarWidth, 20.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barW / 2, size.height - barH, barW, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);

      // Glow on top
      final glowPaint = Paint()
        ..color = _intensityColor(event.amplitude).withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(rect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CadencePainter old) =>
      old.animationValue != animationValue || old.events != events;
}
