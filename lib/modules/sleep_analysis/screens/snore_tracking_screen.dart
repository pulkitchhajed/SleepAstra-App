import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/chart_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../sleep_analysis/providers/sleep_analysis_provider.dart';
import '../../sleep_analysis/models/sleep_report.dart';

class SnoreTrackingScreen extends StatefulWidget {
  const SnoreTrackingScreen({super.key});

  @override
  State<SnoreTrackingScreen> createState() => _SnoreTrackingScreenState();
}

class _SnoreTrackingScreenState extends State<SnoreTrackingScreen> {
  int _selectedTab = 1; // 0 = Day, 1 = Week, 2 = Month
  DateTime _currentDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SleepAnalysisProvider>().history;
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0D0F1E);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.05);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Snore Tracking', style: TextStyle(color: textPrimary)),
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
            _buildTabs(isLight, textPrimary).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            const SizedBox(height: 24),
            _buildDateNav(textPrimary, textSec).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 32),
            _buildTotalSnoring(history, textPrimary, textSec).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            const SizedBox(height: 32),
            _buildChart(history, cardBorder, textSec, isLight).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            const SizedBox(height: 40),
            _buildStatsList(history, textPrimary, textSec, cardBorder).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(bool isLight, Color textPrimary) {
    return Container(
      decoration: AppTheme.glassDecoration(isLightMode: isLight),
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

  Widget _buildTotalSnoring(List<SleepReport> history, Color textPrimary, Color textSec) {
    double totalMins = 0;
    final dates = _getDatesToAnalyze();
    for (final d in dates) {
      final r = history.cast<SleepReport?>().firstWhere(
        (x) => x != null && x.recordedAt.year == d.year && x.recordedAt.month == d.month && x.recordedAt.day == d.day,
        orElse: () => null,
      );
      if (r != null) {
        totalMins += r.snoringDuration.inSeconds / 60.0;
      }
    }

    final h = (totalMins / 60).floor();
    final m = (totalMins % 60).round();
    
    String badge = 'Light';
    Color badgeColor = AppTheme.accentTeal;
    if (totalMins > 120) { badge = 'Heavy'; badgeColor = AppTheme.error; }
    else if (totalMins > 45) { badge = 'Moderate'; badgeColor = AppTheme.primaryGold; }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Snoring', style: TextStyle(color: textSec, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${h}h ${m}m', style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<SleepReport> history, Color cardBorder, Color textSec, bool isLight) {
    final dates = _getDatesToAnalyze();
    final bars = <BarChartGroupData>[];
    double maxTotal = 1.0;
    bool hasData = false;

    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final r = history.cast<SleepReport?>().firstWhere(
        (x) => x != null && x.recordedAt.year == d.year && x.recordedAt.month == d.month && x.recordedAt.day == d.day,
        orElse: () => null,
      );

      double snoreHrs = 0;
      if (r != null) {
        hasData = true;
        snoreHrs = r.snoringDuration.inSeconds / 3600.0;
        if (snoreHrs > maxTotal) maxTotal = snoreHrs;
      }

      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: snoreHrs,
            width: _selectedTab == 2 ? 4 : (_selectedTab == 1 ? 12 : 30),
            color: AppTheme.error,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: ChartTheme.backgroundBar(isLight, maxTotal * 1.2),
          )
        ]
      ));
    }

    if (!hasData) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_off_rounded, size: 48, color: textSec.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No snore data for this period', style: TextStyle(color: textSec, fontSize: 16)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxTotal * 1.2,
          gridData: ChartTheme.gridData(isLight),
          borderData: ChartTheme.borderData,
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
                    child: Text(label, style: ChartTheme.getAxisTextStyle(isLight)),
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

  Widget _buildStatsList(List<SleepReport> history, Color textPrimary, Color textSec, Color cardBorder) {
    int maxEventMin = 0;
    int totalEvents = 0;
    double totalHours = 0;
    
    final dates = _getDatesToAnalyze();
    for (final d in dates) {
      final r = history.cast<SleepReport?>().firstWhere(
        (x) => x != null && x.recordedAt.year == d.year && x.recordedAt.month == d.month && x.recordedAt.day == d.day,
        orElse: () => null,
      );
      if (r != null) {
        totalHours += r.totalDuration.inMinutes / 60.0;
        totalEvents += r.snoringEventCount;
        for (var ev in r.snoringEvents) {
          if (ev.duration.inMinutes > maxEventMin) {
            maxEventMin = ev.duration.inMinutes;
          }
        }
      }
    }

    final freq = totalHours > 0 ? (totalEvents / totalHours).round() : 0;
    
    String intensity = 'Light';
    if (freq > 20) {
      intensity = 'Heavy';
    } else if (freq > 5) {
      intensity = 'Moderate';
    }

    return Column(
      children: [
        _statRow('Longest event', '${maxEventMin == 0 && totalEvents > 0 ? "< 1" : maxEventMin} min', textPrimary, textSec),
        Divider(color: cardBorder, height: 24),
        _statRow('Snore intensity', intensity, textPrimary, textSec),
        Divider(color: cardBorder, height: 24),
        _statRow('Snore frequency', '$freq events/hr', textPrimary, textSec),
      ],
    );
  }

  Widget _statRow(String label, String value, Color textPrimary, Color textSec) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textSec, fontSize: 15)),
        Text(value, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
