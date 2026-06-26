import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../sleep_analysis/providers/sleep_analysis_provider.dart';
import '../../sleep_analysis/models/sleep_report.dart';

class SleepStagesScreen extends StatefulWidget {
  const SleepStagesScreen({super.key});

  @override
  State<SleepStagesScreen> createState() => _SleepStagesScreenState();
}

class _SleepStagesScreenState extends State<SleepStagesScreen> {
  int _selectedTab = 1; // 0 = Day, 1 = Week, 2 = Month
  DateTime _currentDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SleepAnalysisProvider>().history;
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0D0F1E);
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.05);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Sleep Stages', style: TextStyle(color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs
            _buildTabs(cardBg, textPrimary),
            const SizedBox(height: 24),

            // Date Range & Nav
            _buildDateNav(textPrimary, textSec),
            const SizedBox(height: 32),

            // Average Duration
            _buildAverageSleep(history, textPrimary, textSec),
            const SizedBox(height: 32),

            // Chart
            _buildChart(history, cardBorder, textPrimary, textSec),
            const SizedBox(height: 40),

            // Legend & Percentages (mocking percentages for the view)
            _buildLegend(history, textPrimary, textSec),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(Color cardBg, Color textPrimary) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tabItem(0, 'Day', textPrimary),
          _tabItem(1, 'Week', textPrimary),
          _tabItem(2, 'Month', textPrimary),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, Color textPrimary) {
    final sel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primaryIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: sel ? Colors.white : textPrimary.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNav(Color textPrimary, Color textSec) {
    String dateRange = '';
    if (_selectedTab == 0) {
      dateRange = DateFormat('MMM d, yyyy').format(_currentDate);
    } else if (_selectedTab == 1) {
      final mon = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      dateRange = '${DateFormat('MMM d').format(mon)} – ${DateFormat('MMM d, yyyy').format(sun)}';
    } else {
      dateRange = DateFormat('MMMM yyyy').format(_currentDate);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: textSec),
          onPressed: () {
            setState(() {
              if (_selectedTab == 0) _currentDate = _currentDate.subtract(const Duration(days: 1));
              if (_selectedTab == 1) _currentDate = _currentDate.subtract(const Duration(days: 7));
              if (_selectedTab == 2) _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
            });
          },
        ),
        Text(
          dateRange,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, color: textSec),
          onPressed: () {
            setState(() {
              if (_selectedTab == 0) _currentDate = _currentDate.add(const Duration(days: 1));
              if (_selectedTab == 1) _currentDate = _currentDate.add(const Duration(days: 7));
              if (_selectedTab == 2) _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
            });
          },
        ),
      ],
    );
  }

  List<DateTime> _getDatesToAnalyze() {
    if (_selectedTab == 0) {
      return [_currentDate];
    } else if (_selectedTab == 1) {
      final mon = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
      return List.generate(7, (i) => mon.add(Duration(days: i)));
    } else {
      final daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
      return List.generate(daysInMonth, (i) => DateTime(_currentDate.year, _currentDate.month, i + 1));
    }
  }

  Widget _buildAverageSleep(List<SleepReport> history, Color textPrimary, Color textSec) {
    double totalHours = 0;
    int count = 0;

    final dates = _getDatesToAnalyze();
    for (final d in dates) {
      final r = history.cast<SleepReport?>().firstWhere(
        (x) => x != null && x.recordedAt.year == d.year && x.recordedAt.month == d.month && x.recordedAt.day == d.day,
        orElse: () => null,
      );
      if (r != null) {
        totalHours += r.totalDuration.inMinutes / 60.0;
        count++;
      }
    }

    final avg = count > 0 ? totalHours / count : 0.0;
    final h = avg.floor();
    final m = ((avg - h) * 60).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_selectedTab == 0 ? 'Total Sleep' : 'Average Sleep', style: TextStyle(color: textSec, fontSize: 13)),
        const SizedBox(height: 4),
        Text('${h}h ${m}m', style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildChart(List<SleepReport> history, Color cardBorder, Color textPrimary, Color textSec) {
    final dates = _getDatesToAnalyze();
    final bars = <BarChartGroupData>[];
    double maxTotal = 8.0;

    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final r = history.cast<SleepReport?>().firstWhere(
        (x) => x != null && x.recordedAt.year == d.year && x.recordedAt.month == d.month && x.recordedAt.day == d.day,
        orElse: () => null,
      );

      double deepHrs = 0;
      double lightHrs = 0;
      double remHrs = 0;
      double awakeHrs = 0;

      if (r != null) {
        final totalHrs = r.totalDuration.inMinutes / 60.0;
        if (totalHrs > maxTotal) maxTotal = totalHrs;

        deepHrs = totalHrs * r.deepSleepPercent;
        remHrs = totalHrs * r.remSleepPercent;
        lightHrs = totalHrs * r.lightSleepPercent;
        awakeHrs = totalHrs - (deepHrs + remHrs + lightHrs);
        if (awakeHrs < 0) awakeHrs = 0;
      }

      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: deepHrs + lightHrs + remHrs + awakeHrs,
            width: _selectedTab == 2 ? 6 : (_selectedTab == 1 ? 24 : 40),
            borderRadius: BorderRadius.circular(4),
            rodStackItems: [
              BarChartRodStackItem(0, deepHrs, const Color(0xFF1E3A8A)), // Deep
              BarChartRodStackItem(deepHrs, deepHrs + lightHrs, const Color(0xFF6366F1)), // Light
              BarChartRodStackItem(deepHrs + lightHrs, deepHrs + lightHrs + remHrs, const Color(0xFF8B5CF6)), // REM
              BarChartRodStackItem(deepHrs + lightHrs + remHrs, deepHrs + lightHrs + remHrs + awakeHrs, const Color(0xFFF59E0B)), // Awake
            ],
            color: Colors.transparent,
          )
        ]
      ));
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxTotal * 1.1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: cardBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= dates.length) return const SizedBox();
                  
                  String label = '';
                  if (_selectedTab == 0) {
                    label = DateFormat('EEE').format(dates[idx]);
                  } else if (_selectedTab == 1) {
                    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    label = labels[idx % 7];
                  } else {
                    if (idx == 0 || idx == 4 || idx == 9 || idx == 14 || idx == 19 || idx == 24 || idx == dates.length - 1) {
                      label = '${idx + 1}';
                    }
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
          ),
          barGroups: bars,
        ),
      ),
    );
  }

  Widget _buildLegend(List<SleepReport> history, Color textPrimary, Color textSec) {
    int count = 0;
    double deepHrs = 0;
    double lightHrs = 0;
    double remHrs = 0;
    double awakeHrs = 0;

    final dates = _getDatesToAnalyze();
    for (final d in dates) {
      final r = history.cast<SleepReport?>().firstWhere(
        (x) => x != null && x.recordedAt.year == d.year && x.recordedAt.month == d.month && x.recordedAt.day == d.day,
        orElse: () => null,
      );
      if (r != null) {
        final totalHrs = r.totalDuration.inMinutes / 60.0;
        deepHrs += totalHrs * r.deepSleepPercent;
        remHrs += totalHrs * r.remSleepPercent;
        lightHrs += totalHrs * r.lightSleepPercent;
        awakeHrs += max(0, totalHrs - (totalHrs * r.deepSleepPercent + totalHrs * r.remSleepPercent + totalHrs * r.lightSleepPercent));
        count++;
      }
    }

    if (count > 0) {
      deepHrs /= count;
      lightHrs /= count;
      remHrs /= count;
      awakeHrs /= count;
    }

    final total = deepHrs + lightHrs + remHrs + awakeHrs;
    final deepPct = total > 0 ? (deepHrs / total * 100).round() : 0;
    final lightPct = total > 0 ? (lightHrs / total * 100).round() : 0;
    final remPct = total > 0 ? (remHrs / total * 100).round() : 0;
    final awakePct = total > 0 ? (awakeHrs / total * 100).round() : 0;

    return Column(
      children: [
        _legendRow('Deep Sleep', const Color(0xFF1E3A8A), _formatDuration(deepHrs), '$deepPct%', textPrimary, textSec),
        const SizedBox(height: 12),
        _legendRow('Light Sleep', const Color(0xFF6366F1), _formatDuration(lightHrs), '$lightPct%', textPrimary, textSec),
        const SizedBox(height: 12),
        _legendRow('REM Sleep', const Color(0xFF8B5CF6), _formatDuration(remHrs), '$remPct%', textPrimary, textSec),
        const SizedBox(height: 12),
        _legendRow('Awake', const Color(0xFFF59E0B), _formatDuration(awakeHrs), '$awakePct%', textPrimary, textSec),
      ],
    );
  }

  String _formatDuration(double hrs) {
    if (hrs == 0) return '0h 0m';
    final h = hrs.floor();
    final m = ((hrs - h) * 60).round();
    return '${h}h ${m}m';
  }

  Widget _legendRow(String label, Color color, String duration, String percentage, Color textPrimary, Color textSec) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 1,
          child: Text(duration, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Text(percentage, style: TextStyle(color: textSec, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
