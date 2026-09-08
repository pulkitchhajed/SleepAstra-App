import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../modules/onboarding/providers/onboarding_provider.dart';
import '../modules/sleep_analysis/providers/sleep_analysis_provider.dart';
import '../core/router/app_router.dart';

class DailySleepGoalScreen extends StatelessWidget {
  const DailySleepGoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    
    final profile = context.watch<OnboardingProvider>().profile;
    final goalMinutes = profile.goalDurationMinutes; // default 8h already handled in provider/profile
    final history = context.watch<SleepAnalysisProvider>().history;

    // Filter to last 7 days
    final recent7 = history.take(7).toList().reversed.toList();
    final today = recent7.isNotEmpty ? recent7.last : null;
    final todayMinutes = today?.totalDuration.inMinutes ?? 0;
    
    final progress = (todayMinutes / goalMinutes).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    // Dynamic color coding: 1-30% red, 31-60% orange, 61-100% green
    final Color goalColor;
    if (percent <= 30) {
      goalColor = const Color(0xFFEF4444); // Red
    } else if (percent <= 60) {
      goalColor = const Color(0xFFF97316); // Orange
    } else {
      goalColor = const Color(0xFF10B981); // Green
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Daily Sleep Goal', style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryIndigo),
            onPressed: () => Navigator.pushNamed(context, AppRouter.settings), // Navigate to settings to change goal
            tooltip: 'Edit Goal',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Progress
              SizedBox(
                height: 170,
                width: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _LargeGoalProgressPainter(
                        progress: progress,
                        isLight: isLight,
                        color: goalColor,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${todayMinutes ~/ 60}h ${todayMinutes % 60}m',
                            style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.w800, color: textPrimary, height: 1.1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'of ${goalMinutes ~/ 60}h goal',
                            style: TextStyle(fontSize: 13, color: textSec, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Stats Row
              Row(
                children: [
                  Expanded(child: _buildStatCard('Avg Duration (7d)', _calculateAvgDuration(recent7), Icons.timelapse_rounded, isLight, textPrimary, textSec)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Goal Hit Rate', _calculateHitRate(recent7, goalMinutes), Icons.flag_rounded, isLight, textPrimary, textSec)),
                ],
              ),
              const SizedBox(height: 12),
              
              // 7-Day Trend Chart
              Align(
                alignment: Alignment.centerLeft,
                child: Text('7-Day Trend', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
              ),
              const SizedBox(height: 8),
              Container(
                height: 165,
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                decoration: AppTheme.glassDecoration(borderRadius: BorderRadius.circular(18), isLightMode: isLight),
                child: _buildBarChart(recent7, goalMinutes, isLight, textSec),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isLight, Color textPrimary, Color textSec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.glassDecoration(borderRadius: BorderRadius.circular(16), isLightMode: isLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryIndigo, size: 22),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _calculateAvgDuration(List history) {
    if (history.isEmpty) return '0h 0m';
    int totalMins = 0;
    for (var r in history) {
      totalMins += r.totalDuration.inMinutes as int;
    }
    final avg = totalMins ~/ history.length;
    return '${avg ~/ 60}h ${avg % 60}m';
  }

  String _calculateHitRate(List history, int goalMinutes) {
    if (history.isEmpty) return '0%';
    int hits = 0;
    for (var r in history) {
      if ((r.totalDuration.inMinutes as int) >= goalMinutes) hits++;
    }
    return '${((hits / history.length) * 100).toInt()}%';
  }

  Widget _buildBarChart(List history, int goalMinutes, bool isLight, Color textSec) {
    final scores = <double>[];
    for (var r in history) {
      scores.add((r.totalDuration.inMinutes as int) / 60.0);
    }
    while (scores.length < 7) {
      scores.insert(0, 0);
    }

    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      if (i == 6) return 'Today';
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    });

    final goalHours = goalMinutes / 60.0;
    final maxScore = scores.isEmpty ? 0.0 : scores.reduce(max);
    final chartMaxY = max(10.0, max(goalHours, maxScore) * 1.15);
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        minY: 0,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goalHours,
              color: AppTheme.accentTeal.withValues(alpha: 0.6),
              strokeWidth: 1.5,
              dashArray: [5, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                style: const TextStyle(fontSize: 10, color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
                labelResolver: (line) => 'Goal',
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final dayIndex = value.toInt();
                final text = (dayIndex >= 0 && dayIndex < dayLabels.length) ? dayLabels[dayIndex] : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: dayIndex == 6 ? FontWeight.bold : FontWeight.normal,
                      color: textSec,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final score = scores[index];
          final dayPercent = ((score / goalHours) * 100).round();
          final Color barColor;
          if (dayPercent <= 30) {
            barColor = const Color(0xFFEF4444); // 1-30%: Red
          } else if (dayPercent <= 60) {
            barColor = const Color(0xFFF97316); // 31-60%: Orange
          } else {
            barColor = const Color(0xFF10B981); // 61-100%: Green
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: score.clamp(0.0, chartMaxY),
                color: score == 0 ? Colors.transparent : barColor,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: chartMaxY,
                  color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _LargeGoalProgressPainter extends CustomPainter {
  final double progress;
  final bool isLight;
  final Color color;

  _LargeGoalProgressPainter({required this.progress, required this.isLight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, bgPaint);

    if (progress > 0) {
      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, glowPaint);

      // Progress arc
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.6), color],
          stops: const [0.0, 1.0],
          startAngle: -pi / 2,
          endAngle: -pi / 2 + 2 * pi * progress,
          transform: GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
