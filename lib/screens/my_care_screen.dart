import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../modules/sleep_analysis/models/sleep_report.dart';
import '../modules/sleep_analysis/providers/sleep_analysis_provider.dart';
import '../modules/sleep_analysis/utils/sleep_ui_config.dart';

class MyCareScreen extends StatefulWidget {
  const MyCareScreen({super.key});

  @override
  State<MyCareScreen> createState() => _MyCareScreenState();
}

class _MyCareScreenState extends State<MyCareScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLight = themeProvider.isDarkMode == false;
    final history = context.watch<SleepAnalysisProvider>().history;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: history.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monitor_heart_rounded, size: 64, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'No Data Available',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Record a sleep session to view insights.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isLight),
                    const SizedBox(height: 24),
                    _sectionHeader('Sleep Stages', isLight),
                    _sleepStagesChart(history.first, isLight),
                    const SizedBox(height: 24),
                    _sectionHeader('Snoring Analysis', isLight),
                    _snoringAnalysisCard(history.first, isLight),
                    const SizedBox(height: 24),
                    _sectionHeader('7-Day Trend', isLight),
                    _trendChart(history, isLight),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isLight) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Care',
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Advanced clinical insights & tracking',
            style: TextStyle(
              color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isLight) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
      ),
    ),
  );

  Widget _sleepStagesChart(SleepReport r, bool isLight) {
    final totalSec = r.totalDuration.inSeconds.toDouble();
    if (totalSec == 0) return const SizedBox();

    final stats = r.calculateStageStats();

    const int targetPoints = 60;
    final int bucketSize = max(1, (r.amplitudeTimeline.length / targetPoints).ceil());
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < r.amplitudeTimeline.length; i += bucketSize) {
      final chunk = r.amplitudeTimeline.skip(i).take(bucketSize);
      if (chunk.isEmpty) break;
      
      final counts = <SleepStage, int>{};
      for (final s in chunk) {
        counts[s.stage] = (counts[s.stage] ?? 0) + 1;
      }
      final dominant = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      
      final avgTime = chunk.map((c) => c.timeSeconds).reduce((a, b) => a + b) / chunk.length;
      spots.add(FlSpot(avgTime, dominant.chartYValue));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
            ),
            child: SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 3,
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: 1,
                        getTitlesWidget: (v, m) {
                          if (v == 0) return Text('Deep', style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 11));
                          if (v == 1) return Text('Light', style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 11));
                          if (v == 2) return Text('REM', style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 11));
                          if (v == 3) return Text('Awake', style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 11));
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                      isStepLineChart: true,
                      color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary.withValues(alpha: 0.5),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            SleepStage.awake.color.withValues(alpha: 0.4),
                            SleepStage.rem.color.withValues(alpha: 0.4),
                            SleepStage.light.color.withValues(alpha: 0.4),
                            SleepStage.deep.color.withValues(alpha: 0.4),
                          ],
                          stops: const [0.0, 0.33, 0.66, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _stagePie(SleepStage.deep.displayName, stats.percentDeep, stats.durationDeep, SleepStage.deep.color, isLight)),
                  Expanded(child: _stagePie(SleepStage.light.displayName, stats.percentLight, stats.durationLight, SleepStage.light.color, isLight)),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _stagePie(SleepStage.rem.displayName, stats.percentRem, stats.durationRem, SleepStage.rem.color, isLight)),
                  Expanded(child: _stagePie(SleepStage.awake.displayName, stats.percentAwake, stats.durationAwake, SleepStage.awake.color, isLight)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagePie(String title, int percentValue, Duration duration, Color color, bool isLight) {
    final double fraction = percentValue / 100.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 16,
              startDegreeOffset: 270,
              sections: [
                PieChartSectionData(
                  color: color,
                  value: max(1.0, fraction * 360),
                  title: '',
                  radius: 6,
                ),
                PieChartSectionData(
                  color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white10,
                  value: max(1.0, (1.0 - fraction) * 360),
                  title: '',
                  radius: 6,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('$percentValue%', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
              Text(_wordDur(duration), style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  String _wordDur(Duration d) {
    if (d.inSeconds == 0) return '<1m';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m == 0 && s > 0) return '${s}s';
    return '${m}m';
  }

  Widget _snoringAnalysisCard(SleepReport r, bool isLight) {
    final timeline = r.amplitudeTimeline;

    final snoreTimeStr = _durExact(r.snoringDuration);
    final hours = r.totalDuration.inMinutes / 60.0;
    final frequency = hours > 0 ? (r.snoringEventCount / hours) : 0.0;
    
    double maxAmp = 0.0;
    double sumSnoreAmp = 0.0;
    int snoreCount = 0;
    for (var s in timeline) {
      if (s.isSnoring) {
        snoreCount++;
        sumSnoreAmp += s.amplitude;
        if (s.amplitude > maxAmp) maxAmp = s.amplitude;
      }
    }
    
    final avgDb = snoreCount > 0 ? (sumSnoreAmp / snoreCount) * 80.0 : 0.0;
    final maxDb = maxAmp * 80.0;

    const int targetBars = 40;
    final int bucketSize = max(1, (timeline.length / targetBars).ceil());
    final List<BarChartGroupData> barGroups = [];
    
    for (int i = 0; i < timeline.length; i += bucketSize) {
      final chunk = timeline.skip(i).take(bucketSize);
      if (chunk.isEmpty) break;
      
      final chunkMaxAmp = chunk.map((s) => s.isSnoring ? s.amplitude : 0.0).reduce((a, b) => a > b ? a : b);
      final db = chunkMaxAmp * 80.0;
      
      Color barColor = const Color(0xFF3B82F6);
      if (db >= 60) {
        barColor = const Color(0xFFEF4444);
      }
      
      if (db > 0) {
        barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: db,
              color: barColor,
              width: 4,
              borderRadius: BorderRadius.circular(2),
            )
          ],
        ));
      } else {
        barGroups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: 0, width: 4)]));
      }
    }

    final startDateTime = r.recordedAt.subtract(r.totalDuration);
    final totalSec = r.totalDuration.inSeconds.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: 80,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder.withValues(alpha: 0.4),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 60,
                        color: const Color(0xFFFACC15),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: false,
                        ),
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 10),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= timeline.length) return const SizedBox();
                          final s = timeline[value.toInt()];
                          final spotTime = startDateTime.add(Duration(seconds: s.timeSeconds.toInt()));
                          final format = DateFormat('HH:00'); 
                          if (spotTime.minute < (totalSec / targetBars / 60) * 1.5) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(format.format(spotTime), style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 9)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _snoreMetric('Snore Time', snoreTimeStr, isLight)),
                Expanded(child: _snoreMetric('Frequency', '${frequency.toStringAsFixed(1)} /h', isLight)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _snoreMetric('Avg. Snore', '${avgDb.toInt()} dB', isLight)),
                Expanded(child: _snoreMetric('Max. Snore', '${maxDb.toInt()} dB', isLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snoreMetric(String title, String value, bool isLight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _durExact(Duration d) {
    if (d.inSeconds == 0) return '0 minutes';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h hours $m minutes';
    return '$m minutes $s seconds';
  }

  Widget _trendChart(List<SleepReport> reports, bool isLight) {
    final reversed = reports.take(7).toList().reversed.toList();
    final spots = reversed.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.qualityScore)).toList();
    
    double sumDuration = 0;
    double sumScore = 0;
    for (var r in reversed) {
      sumDuration += r.totalDuration.inHours + (r.totalDuration.inMinutes % 60) / 60.0;
      sumScore += r.qualityScore;
    }
    
    final avgDur = reversed.isEmpty ? '0h' : '${(sumDuration / reversed.length).toStringAsFixed(1)}h';
    final avgScore = reversed.isEmpty ? '0' : (sumScore / reversed.length).toInt().toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLight ? AppTheme.surfaceLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              child: LineChart(LineChartData(
                minY: 0, maxY: 100,
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder.withValues(alpha: 0.4), strokeWidth: 1)
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= reversed.length) return const SizedBox();
                    return Text(DateFormat('d/M').format(reversed[i].recordedAt),
                        style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 9));
                  })),
                ),
                lineBarsData: [LineChartBarData(
                  spots: spots, isCurved: true,
                  gradient: const LinearGradient(colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)]),
                  barWidth: 2.5, dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [AppTheme.primaryIndigo.withValues(alpha: 0.3), AppTheme.primaryIndigo.withValues(alpha: 0.0)]
                    ),
                  ),
                )],
              )),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _trendStat('Avg Duration', avgDur, const Color(0xFF818CF8), isLight),
              _trendStat('Efficiency', '$avgScore%', AppTheme.accentTeal, isLight),
              _trendStat('Sessions', '${reversed.length}', AppTheme.primaryGold, isLight),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _trendStat(String title, String val, Color color, bool isLight) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}
