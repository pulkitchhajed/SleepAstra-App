import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/sleep_report.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/router/app_router.dart';

// Import dashboard charts
import '../widgets/charts/clinical_dashboard_charts.dart';
import '../widgets/sleep_stages_chart_widget.dart';
import '../services/pdf_export_service.dart';
import '../../paywall/providers/subscription_provider.dart';

class SleepReportScreen extends StatefulWidget {
  final SleepReport report;
  const SleepReportScreen({super.key, required this.report});

  @override
  State<SleepReportScreen> createState() => _SleepReportScreenState();
}

class _SleepReportScreenState extends State<SleepReportScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scoreController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _scoreAnim = Tween<double>(begin: 0, end: widget.report.qualityScore).animate(CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0D0F1E);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.6);
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withValues(alpha: 0.25);

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          gradient: isLight ? null : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0F1E), Color(0xFF080A13)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, textPrimary, cardBorder, cardBg),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildRecordingTimes(textSec, textPrimary),
                    const SizedBox(height: 20),
                    _buildHeroCard(context, cardBg, cardBorder, textPrimary, textSec, isLight),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Insights', Icons.lightbulb_rounded, textPrimary),
                    const SizedBox(height: 12),
                    _buildInsightsSection(cardBg, cardBorder, textPrimary, textSec),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Sleep Graphs', Icons.bar_chart_rounded, textPrimary),
                    const SizedBox(height: 8),
                    // Charts
                    
                    // Sleep Stages
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.waves_rounded, color: AppTheme.accentTeal, size: 24),
                              const SizedBox(width: 12),
                              Text('Sleep Stages', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Your progression through sleep phases.', style: TextStyle(color: textSec, fontSize: 12)),
                          const SizedBox(height: 24),
                          SleepStagesChartWidget(
                            samples: widget.report.amplitudeTimeline,
                            totalDuration: widget.report.totalDuration,
                            recordedAt: widget.report.recordedAt,
                          ),
                        ],
                      ),
                    ),

                    // Snore Detection
                    SnoreIntensityTimelineChart(report: widget.report),
                    
                    // Suspect Apnea Events
                    ApneaTimelineChart(report: widget.report),

                    // --- Hidden Charts ---
                    /*
                    SnoreHeatmapTimeline(report: widget.report),
                    SnoreEventsPerHourChart(report: widget.report),
                    SeverityDistributionChart(report: widget.report),
                    ActivityHeatmapChart(report: widget.report),
                    FftSpectrumChart(report: widget.report),
                    */
                    const SizedBox(height: 32),
                    _buildActionButtons(context),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sliver AppBar ─────────────────────────────────────────────
  Widget _buildSliverAppBar(BuildContext context, Color textPrimary, Color cardBorder, Color cardBg) {
    final dateStr = DateFormat('EEEE, d MMM').format(widget.report.recordedAt);
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 0,
      flexibleSpace: Container(
        color: Colors.transparent,
      ),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
          ),
          child: Icon(Icons.arrow_back_ios_rounded,
              color: textPrimary, size: 16),
        ),
      ),
      title: Text(
        dateStr,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      actions: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRouter.settings),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.settings_outlined, color: textPrimary, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Recording times ───────────────────────────────────────────
  Widget _buildRecordingTimes(Color textSec, Color textPrimary) {
    // recordedAt = actual sleep START time (set by the recording timer/orphan recovery)
    final start = widget.report.recordedAt;
    final end = widget.report.recordedAt.add(widget.report.totalDuration);
    final fmt = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _timeChip(fmt.format(start), Icons.bedtime_rounded, 'Sleep', textSec, textPrimary),
          Container(
            height: 1,
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                textPrimary.withValues(alpha: 0.0),
                textPrimary.withValues(alpha: 0.15),
                textPrimary.withValues(alpha: 0.0),
              ]),
            ),
          ),
          _timeChip(fmt.format(end), Icons.wb_sunny_rounded, 'Wake', textSec, textPrimary),
        ],
      ),
    );
  }

  Widget _timeChip(String time, IconData icon, String label, Color textSec, Color textPrimary) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: textSec, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, color: textSec, size: 13),
            const SizedBox(width: 4),
            Text(time,
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // ─── Hero Card (score + metrics) ───────────────────────────────
  Widget _buildHeroCard(BuildContext context, Color cardBg, Color cardBorder, Color textPrimary, Color textSec, bool isLight) {
    final score = widget.report.qualityScore;
    final scoreLabel = score >= 85
        ? ('Great Sleep 🌙', AppTheme.accentTeal)
        : score >= 65
            ? ('Fair Sleep 😴', AppTheme.primaryGold)
            : ('Poor Sleep 😬', AppTheme.error);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: cardBg,
          gradient: isLight ? null : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1D33),
              Color(0xFF111428),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: cardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            if (!isLight)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Metric column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metricCard(
                        icon: Icons.bed_rounded,
                        iconColor: AppTheme.primaryIndigo,
                        label: 'Time in Bed',
                        value: _dur(widget.report.totalDuration),
                        textPrimary: textPrimary,
                        textSec: textSec,
                      ),
                      const SizedBox(height: 14),
                      _metricCard(
                        icon: Icons.graphic_eq_rounded,
                        iconColor: AppTheme.error,
                        label: 'Time Snoring',
                        value:
                            '${_dur(widget.report.snoringDuration)}  ${widget.report.snoringPercentage.toInt()}%',
                        textPrimary: textPrimary,
                        textSec: textSec,
                      ),
                      const SizedBox(height: 14),
                      _metricCard(
                        icon: Icons.hourglass_bottom_rounded,
                        iconColor: AppTheme.primaryGold,
                        label: 'Sleep Debt',
                        value:
                            '${widget.report.sleepDebtHours.toStringAsFixed(1)}h',
                        textPrimary: textPrimary,
                        textSec: textSec,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // ── Score gauge
                _buildScoreGauge(score, scoreLabel, textPrimary, textSec),
              ],
            ),
            const SizedBox(height: 20),
            // Score label badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scoreLabel.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                    color: scoreLabel.$2.withValues(alpha: 0.35), width: 1),
              ),
              child: Text(
                scoreLabel.$1,
                style: TextStyle(
                  color: scoreLabel.$2,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSec,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: textSec, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreGauge(
      double score, (String, Color) scoreLabel, Color textPrimary, Color textSec) {
    return SizedBox(
      width: 130,
      height: 130,
      child: AnimatedBuilder(
        animation: _scoreAnim,
        builder: (context, child) {
          final value = _scoreAnim.value;
          return Stack(alignment: Alignment.center, children: [
            // Glow ring
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scoreLabel.$2.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            CustomPaint(
                painter: _GaugePainter(score: value, trackColor: textSec.withValues(alpha: 0.2)),
                size: const Size(130, 130)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${value.toInt()}',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -1)),
              Text('Snore Score',
                  style: TextStyle(fontSize: 10, color: textSec)),
            ]),
          ]);
        },
      ),
    );
  }

  // ─── Section header ────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryIndigo, AppTheme.accentTeal]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: AppTheme.primaryIndigo, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Insights ──────────────────────────────────────────────────
  Widget _buildInsightsSection(Color cardBg, Color cardBorder, Color textPrimary, Color textSec) {
    if (widget.report.insights.isEmpty) return const SizedBox.shrink();
    
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    
    Widget content = Column(
      children: [
        ...widget.report.insights.take(3).map((e) => _insightCard(e, cardBg, cardBorder, textPrimary, textSec)),
      ],
    );

    if (!isPremium) {
      return Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Opacity(
              opacity: 0.5,
              child: content,
            ),
          ),
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRouter.paywall),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Unlock AI Insights',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }

  static const List<Color> _insightAccents = [
    AppTheme.accentTeal,
    AppTheme.primaryIndigo,
    AppTheme.primaryGold,
  ];

  Widget _insightCard(SleepInsight insight, Color cardBg, Color cardBorder, Color textPrimary, Color textSec) {
    final idx = widget.report.insights.indexOf(insight);
    final accent = _insightAccents[idx % _insightAccents.length];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent, accent.withValues(alpha: 0.3)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(insight.emoji,
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(insight.title,
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(insight.description,
                              style: TextStyle(
                                  color: textSec,
                                  fontSize: 12,
                                  height: 1.5)),
                        ],
                      ),
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

  // ─── Action buttons ────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(children: [
            // Secondary – outlined
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                    context, AppRouter.sleepAnalysis,
                    arguments: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fiber_manual_record_rounded,
                          color: AppTheme.accentTeal, size: 16),
                      SizedBox(width: 8),
                      Text('Record New',
                          style: TextStyle(
                              color: AppTheme.accentTeal,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Primary – gradient
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRouter.sleepHistory),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryIndigo, Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('View History',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────
  String _dur(Duration d) {
    if (d.inSeconds == 0) return '<1m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m == 0 && s > 0) return '${s}s';
    return '${m}m';
  }
}

// ─── Gauge painter for snore score ─────────────────────────────
class _GaugePainter extends CustomPainter {
  final double score;
  final Color trackColor;
  _GaugePainter({required this.score, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const sw = 10.0;

    // Background track
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        0.8 * 3.1415, 1.4 * 3.1415, false, bgPaint);

    // Colored segments
    final colors = [
      const Color(0xFF2DD4BF), // teal
      const Color(0xFFFACC15), // yellow
      const Color(0xFFFB923C), // orange
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    final sweep = 1.4 * 3.1415;
    double start = 0.8 * 3.1415;
    for (int i = 0; i < 3; i++) {
      final active = score > (i * 33);
      paint.color = active ? colors[i] : colors[i].withValues(alpha: 0.15);
      final seg = sweep / 3;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start + 0.05,
          seg - 0.1,
          false,
          paint);
      start += seg;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}


class SnoreHeatmapTimeline extends StatelessWidget {
  final SleepReport report;
  const SnoreHeatmapTimeline({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.35);
    final cardBorder = isLight ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.07);

    if (report.amplitudeTimeline.isEmpty) return const SizedBox.shrink();

    final maxDuration = report.totalDuration.inSeconds;
    if (maxDuration <= 0) return const SizedBox.shrink();

    final segmentsCount = 40; // 40 segments for timeline
    final segmentDuration = maxDuration / segmentsCount;
    final List<double> segmentMaxAmp = List.filled(segmentsCount, 0.0);
    
    // Each sample typically represents a 3-second window
    const sampleWindowSec = 3.0;

    for (int i = 0; i < segmentsCount; i++) {
      final double segStart = i * segmentDuration;
      final double segEnd = (i + 1) * segmentDuration;
      
      double maxAmp = 0.0;
      for (var s in report.amplitudeTimeline) {
        if (s.timeSeconds < 0) continue;
        if (s.timeSeconds >= segEnd) break; // Ordered by time, we can break early
        
        // Check if sample window overlaps with this segment
        if (s.timeSeconds + sampleWindowSec > segStart) {
          if (s.amplitude > maxAmp) {
            maxAmp = s.amplitude;
          }
        }
      }
      segmentMaxAmp[i] = maxAmp;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_week_rounded, color: AppTheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Snore Timeline Heatmap',
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(segmentsCount, (index) {
              final amp = segmentMaxAmp[index];
              Color heatColor;
              if (amp == 0) {
                heatColor = isLight ? AppTheme.textSecondaryLight.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05);
              } else if (amp < 0.1) {
                heatColor = AppTheme.accentTeal.withValues(alpha: 0.7);
              } else if (amp < 0.2) {
                heatColor = AppTheme.primaryGold.withValues(alpha: 0.8);
              } else if (amp < 0.3) {
                heatColor = Colors.orange.withValues(alpha: 0.9);
              } else {
                heatColor = AppTheme.error;
              }

              return Expanded(
                child: Container(
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: heatColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // recordedAt = sleep start; end = start + duration
              Text(DateFormat('h:mm a').format(report.recordedAt), style: TextStyle(color: textSec, fontSize: 10)),
              Text(
                DateFormat('h:mm a').format(report.recordedAt.add(report.totalDuration ~/ 2)),
                style: TextStyle(color: textSec, fontSize: 10),
              ),
              Text(DateFormat('h:mm a').format(report.recordedAt.add(report.totalDuration)), style: TextStyle(color: textSec, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }
}
