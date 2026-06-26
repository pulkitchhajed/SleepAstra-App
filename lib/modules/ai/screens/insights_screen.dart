import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

import '../../sleep_analysis/models/sleep_report.dart';
import '../../sleep_analysis/providers/sleep_analysis_provider.dart';
import '../../sleep_analysis/utils/sleep_ui_config.dart';
import '../services/gemini_service.dart';
import '../../journal/providers/journal_provider.dart';
import 'nidra_chat_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<SleepReport> _reports = [];
  bool _loading = true;
  int _selectedIdx = 0;
  Map<String, dynamic>? _aiSummary;
  final _gemini = GeminiService();
  String? _lastUid;
  int _lastHistoryCount = -1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    if (_reports.isEmpty || _selectedIdx >= _reports.length) return;
    final selectedReport = _reports[_selectedIdx];
    final now = DateTime.now();
    int calendarIndex = -1;
    for (int i = 0; i < 14; i++) {
      final date = now.subtract(Duration(days: 13 - i));
      if (selectedReport.recordedAt.year == date.year &&
          selectedReport.recordedAt.month == date.month &&
          selectedReport.recordedAt.day == date.day) {
        calendarIndex = i;
        break;
      }
    }
    if (calendarIndex != -1) {
      final targetOffset = max(0.0, (calendarIndex * 62.0) - 100.0);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _load(List<SleepReport> data) async {
    setState(() => _loading = true);
    Map<String, dynamic>? summary;
    if (data.isNotEmpty) {
      final journals = context.read<JournalProvider>().entries;
      summary = await _gemini.analyzeSession(data.first, journals.isNotEmpty ? journals.first : null);
    }
    if (mounted) {
      setState(() {
        _reports = data;
        _aiSummary = summary;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final history = context.watch<SleepAnalysisProvider>().history;
    
    if (auth.uid != _lastUid || history.length != _lastHistoryCount) {
      _lastUid = auth.uid;
      _lastHistoryCount = history.length;
      _reports = history;
      if (_reports.isNotEmpty) {
        _load(_reports);
      } else {
        _loading = false;
        _aiSummary = null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo))
            : _reports.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: () => _load(_reports),
                    color: AppTheme.primaryIndigo,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 20),
                          _calendarStrip(),
                          const SizedBox(height: 20),
                          _scoreCard(),
                          const SizedBox(height: 24),
                          _sectionHeader('Sleep Stages'),
                          _sleepStagesChart(),
                          const SizedBox(height: 24),
                          _sectionHeader('Snoring Analysis'),
                          _snoringAnalysisCard(),
                          const SizedBox(height: 24),
                          _sectionHeader('Sleep Trend'),
                          _trendChart(),
                          const SizedBox(height: 40),
                          _nidraFloatingButton(),
                          const SizedBox(height: 16),
                          _helpLink(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sleep Insights', style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w800, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
        const SizedBox(height: 4),
        Text('Your personal sleep analytics', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 14)),
      ],
    ),
  );

  Widget _calendarStrip() {
    final now = DateTime.now();
    final calendarDays = List.generate(14, (i) {
      return now.subtract(Duration(days: 13 - i));
    });

    return SizedBox(
      height: 82,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        itemBuilder: (_, i) {
          final date = calendarDays[i];
          final reportIndex = _reports.indexWhere((r) =>
              r.recordedAt.year == date.year &&
              r.recordedAt.month == date.month &&
              r.recordedAt.day == date.day);
          
          final hasReport = reportIndex != -1;
          final sel = hasReport && _selectedIdx == reportIndex;
          
          if (!hasReport) {
            return Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : (Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues))(alpha: 0.01),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder).withValues(alpha: 0.2), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EEE').format(date),
                      style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary).withValues(alpha: 0.3), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${date.day}',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary).withValues(alpha: 0.2))),
                  const SizedBox(height: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            );
          }
          
          final r = _reports[reportIndex];
          final c = r.qualityScore >= 80 ? AppTheme.accentTeal : r.qualityScore >= 60 ? AppTheme.primaryGold : AppTheme.error;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedIdx = reportIndex);
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primaryIndigo.withValues(alpha: 0.15) : (Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : (Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues))(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sel ? AppTheme.primaryIndigo : (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder), width: sel ? 2 : 1),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(DateFormat('EEE').format(date),
                    style: TextStyle(fontSize: 11, color: sel ? AppTheme.primaryIndigo : (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${date.day}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: sel ? (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary) : (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                const SizedBox(height: 6),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)] : null,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _scoreCard() {
    final r = _reports[_selectedIdx];
    final score = r.qualityScore.toInt();
    final c = score >= 80 ? AppTheme.accentTeal : score >= 60 ? AppTheme.primaryGold : AppTheme.error;
    final nidraInsight = _aiSummary?['recommendation'] as String? ??
        (score >= 80
            ? 'Excellent recovery! Your deep sleep cycle was well-structured. Keep your consistent bedtime.'
            : score >= 60
                ? 'Moderate night — try limiting caffeine after 2 PM for better REM sleep.'
                : 'Poor sleep detected. Consider a relaxing wind-down routine before bed.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration(opacity: 0.12, isLightMode: Theme.of(context).brightness == Brightness.light),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SLEEP SCORE', style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('$score', style: GoogleFonts.outfit(fontSize: 56, fontWeight: FontWeight.w900, color: c)),
                    const SizedBox(width: 4),
                    Text('/100', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 16)),
                  ]),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Duration', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
                  const SizedBox(height: 4),
                  Text(_fmtDur(r.totalDuration),
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentTeal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4))),
                    child: Text('✓ Optimal', style: TextStyle(fontSize: 11, color: AppTheme.accentTeal, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final stats = r.calculateStageStats();
                return Row(children: [
                  _miniStat('Deep Sleep', '${stats.percentDeep}%', const Color(0xFF3B82F6)),
                  const SizedBox(width: 10),
                  _miniStat('REM Sleep', '${stats.percentRem}%', AppTheme.primaryIndigo),
                  const SizedBox(width: 10),
                  _miniStat('Restlessness', r.snoringEventCount < 5 ? 'Low' : r.snoringEventCount < 15 ? 'Medium' : 'High',
                      r.snoringEventCount < 5 ? AppTheme.accentTeal : r.snoringEventCount < 15 ? AppTheme.primaryGold : AppTheme.error),
                ]);
              }
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://snoreclinics.org/'), mode: LaunchMode.externalApplication),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: AppTheme.primaryIndigo, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Image.asset('assets/images/nidra.png', width: 16, height: 16),
                          const SizedBox(width: 8),
                          Text('Nidra Insight', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontWeight: FontWeight.w700)),
                        ]),
                        const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.primaryIndigo),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MarkdownBody(
                      data: nidraInsight,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 13, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary), height: 1.5),
                        strong: TextStyle(fontSize: 13, color: AppTheme.accentTeal, fontWeight: FontWeight.bold, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.language_rounded, size: 14, color: AppTheme.primaryIndigo),
                        const SizedBox(width: 6),
                        Text(
                          'For more information - go to SnoreClinics.org',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryIndigo,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.primaryIndigo.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String val, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : (Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues))(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
  );

  Widget _sleepStagesChart() {
    final r = _reports[_selectedIdx];
    final totalSec = r.totalDuration.inSeconds.toDouble();
    if (totalSec == 0) return const SizedBox();

    final stats = r.calculateStageStats();

    // ── Downsampled Chart Spots (Exactly the same step chart logic) ──
    const int targetPoints = 60;
    final int bucketSize = max(1, (r.amplitudeTimeline.length / targetPoints).ceil());
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < r.amplitudeTimeline.length; i += bucketSize) {
      final chunk = r.amplitudeTimeline.skip(i).take(bucketSize);
      if (chunk.isEmpty) break;
      
      // Use mode (most frequent stage) to eliminate high-frequency noise
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
          // Step Line Chart inside visual glass card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration(opacity: 0.08, isLightMode: Theme.of(context).brightness == Brightness.light),
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
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0: return Text('Deep', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? Colors.black38 : (Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)), fontSize: 11));
                            case 1: return Text('Light', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? Colors.black38 : (Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)), fontSize: 11));
                            case 2: return Text('REM', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? Colors.black38 : (Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)), fontSize: 11));
                            case 3: return Text('Awake', style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? Colors.black38 : (Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)), fontSize: 11));
                          }
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
                      color: (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white).withValues(alpha: 0.5),
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

          // 2x2 Pie/Circular grid metrics matching exactly
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: AppTheme.glassDecoration(opacity: 0.08, isLightMode: Theme.of(context).brightness == Brightness.light),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _stagePie(SleepStage.deep.displayName, stats.percentDeep, stats.durationDeep, SleepStage.deep.color)),
                  Expanded(child: _stagePie(SleepStage.light.displayName, stats.percentLight, stats.durationLight, SleepStage.light.color)),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _stagePie(SleepStage.rem.displayName, stats.percentRem, stats.durationRem, SleepStage.rem.color)),
                  Expanded(child: _stagePie(SleepStage.awake.displayName, stats.percentAwake, stats.durationAwake, SleepStage.awake.color)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagePie(String title, int percentValue, Duration duration, Color color) {
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
                  color: (Theme.of(context).brightness == Brightness.light ? Colors.black12 : (Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10)),
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
              Text(title, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('$percentValue%', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
              Text(_wordDur(duration), style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
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

  Widget _snoringAnalysisCard() {
    final r = _reports[_selectedIdx];
    final timeline = r.amplitudeTimeline;

    // Calculate metrics
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
    
    // Map amplitude (0-1) to dB (40-80 roughly, since snoring is loud)
    // Actually, the requirements say Y axis is 0 to 80 dB.
    // If amplitude is 0.0, dB is 0. If 1.0, dB is 80.
    final avgDb = snoreCount > 0 ? (sumSnoreAmp / snoreCount) * 80.0 : 0.0;
    final maxDb = maxAmp * 80.0;

    // Prepare chart spots
    const int targetBars = 40;
    final int bucketSize = max(1, (timeline.length / targetBars).ceil());
    final List<BarChartGroupData> barGroups = [];
    
    for (int i = 0; i < timeline.length; i += bucketSize) {
      final chunk = timeline.skip(i).take(bucketSize);
      if (chunk.isEmpty) break;
      
      final chunkMaxAmp = chunk.map((s) => s.isSnoring ? s.amplitude : 0.0).reduce((a, b) => a > b ? a : b);
      final db = chunkMaxAmp * 80.0;
      
      // Color based on dB
      Color barColor = const Color(0xFF3B82F6); // blue for < 60
      if (db >= 60) {
        barColor = const Color(0xFFEF4444); // red for >= 60
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
        decoration: AppTheme.glassDecoration(opacity: 0.08, isLightMode: Theme.of(context).brightness == Brightness.light),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chart
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
                        color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder).withValues(alpha: 0.4),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 60,
                        color: const Color(0xFFFACC15), // Yellow
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
                            style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 10),
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
                          // Value is index in the timeline
                          if (value < 0 || value >= timeline.length) return const SizedBox();
                          final s = timeline[value.toInt()];
                          final spotTime = startDateTime.add(Duration(seconds: s.timeSeconds.toInt()));
                          final format = DateFormat('HH:00'); 
                          // Try to show only on the hour, approximate
                          if (spotTime.minute < (totalSec / targetBars / 60) * 1.5) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(format.format(spotTime), style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 9)),
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
            // Metrics 2x2 grid
            Row(
              children: [
                Expanded(child: _snoreMetric('Snore Time', snoreTimeStr)),
                Expanded(child: _snoreMetric('Frequency', '${frequency.toStringAsFixed(1)} /h')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _snoreMetric('Avg. Snore', '${avgDb.toInt()} dB')),
                Expanded(child: _snoreMetric('Max. Snore', '${maxDb.toInt()} dB')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snoreMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary), fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _trendChart() {
    final reversed = _reports.reversed.take(7).toList();
    final spots = reversed.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.qualityScore)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration(opacity: 0.08, isLightMode: Theme.of(context).brightness == Brightness.light),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              child: LineChart(LineChartData(
                minY: 0, maxY: 100,
                gridData: FlGridData(show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder).withValues(alpha: 0.4), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= reversed.length) return const SizedBox();
                    return Text(DateFormat('d/M').format(reversed[i].recordedAt),
                        style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 9));
                  })),
                ),
                lineBarsData: [LineChartBarData(
                  spots: spots, isCurved: true,
                  gradient: const LinearGradient(colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)]),
                  barWidth: 2.5, dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true,
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [AppTheme.primaryIndigo.withValues(alpha: 0.3), AppTheme.primaryIndigo.withValues(alpha: 0.0)])),
                )],
              )),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _trendStat('Avg Duration', _avgDur(), const Color(0xFF818CF8)),
              _trendStat('Efficiency', '${(_avgScore()).toInt()}%', AppTheme.accentTeal),
              _trendStat('Sessions', '${_reports.length}', AppTheme.primaryGold),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _trendStat(String label, String val, Color c) => Column(children: [
    Text(val, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary))),
  ]);

  Widget _emptyState() => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('📊', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 20),
      Text('No data to analyze', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary))),
      const SizedBox(height: 10),
      Text(
        'Record your first sleep session on the Home tab to start tracking your sleep stages, snore detection, and trends.',
        style: TextStyle(color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary), fontSize: 14, height: 1.6),
        textAlign: TextAlign.center,
      ),
    ])),
  );

  String _fmtDur(Duration d) {
    final h = d.inHours; final m = d.inMinutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }

  double _avgScore() => _reports.isEmpty ? 0 :
      _reports.map((r) => r.qualityScore).reduce((a, b) => a + b) / _reports.length;

  String _avgDur() {
    if (_reports.isEmpty) return '0h';
    final avg = _reports.map((r) => r.totalDuration.inMinutes).reduce((a, b) => a + b) ~/ _reports.length;
    return '${avg ~/ 60}h ${avg % 60}m';
  }

  Widget _nidraFloatingButton() {
    return Center(
      child: GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: const NidraChatScreen(isModal: true),
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryIndigo, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/nidra.png', width: 32, height: 32),
              const SizedBox(width: 12),
              Text(
                'Ask Nidra AI',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse('https://snoreclinics.org/'), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryIndigo),
              const SizedBox(width: 10),
              Text(
                'For more information - go to SnoreClinics.org',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.primaryIndigo.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded, size: 15, color: AppTheme.primaryIndigo),
            ],
          ),
        ),
      ),
    );
  }
}
