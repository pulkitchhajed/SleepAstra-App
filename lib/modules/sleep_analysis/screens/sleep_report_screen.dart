import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/sleep_report.dart';
import '../widgets/snore_audio_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/router/app_router.dart';
import 'snore_clips_screen.dart';

// Import dashboard charts
import '../widgets/charts/clinical_dashboard_charts.dart';
import '../widgets/charts/snore_frequency_profile_chart.dart';
import '../widgets/charts/snore_cadence_chart.dart';
import '../widgets/sleep_stages_chart_widget.dart';
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
  // Staggered section controllers
  late AnimationController _section1Ctrl;
  late AnimationController _section2Ctrl;
  late AnimationController _section3Ctrl;
  late Animation<double> _section1Fade;
  late Animation<double> _section2Fade;
  late Animation<double> _section3Fade;
  late Animation<Offset> _section1Slide;
  late Animation<Offset> _section2Slide;
  late Animation<Offset> _section3Slide;

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

    // Staggered sections
    _section1Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _section2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _section3Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _section1Fade = CurvedAnimation(parent: _section1Ctrl, curve: Curves.easeOut);
    _section2Fade = CurvedAnimation(parent: _section2Ctrl, curve: Curves.easeOut);
    _section3Fade = CurvedAnimation(parent: _section3Ctrl, curve: Curves.easeOut);
    _section1Slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _section1Ctrl, curve: Curves.easeOut));
    _section2Slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _section2Ctrl, curve: Curves.easeOut));
    _section3Slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _section3Ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _section1Ctrl.forward(); });
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) _section2Ctrl.forward(); });
    Future.delayed(const Duration(milliseconds: 700), () { if (mounted) _section3Ctrl.forward(); });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scoreController.dispose();
    _section1Ctrl.dispose();
    _section2Ctrl.dispose();
    _section3Ctrl.dispose();
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
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildAppBar(context, textPrimary, cardBorder, cardBg),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildRecordingTimes(textSec, textPrimary),
                        const SizedBox(height: 8),
                    _buildHeroCard(context, cardBg, cardBorder, textPrimary, textSec, isLight),
                    const SizedBox(height: 16),
                    _buildEfficiencyPillRow(cardBg, cardBorder, textPrimary, textSec),
                    const SizedBox(height: 16),
                    if (widget.report.snoreAudioClips.isNotEmpty) ...[
                      // ── Section 1: Snore Recordings + Insights ──
                      /*FadeTransition(
                        opacity: _section1Fade,
                        child: SlideTransition(
                          position: _section1Slide,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Snore Recordings', Icons.mic_rounded, textPrimary),
                              const SizedBox(height: 12),
                              ...widget.report.snoreAudioClips.take(5).map((clip) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: SnoreAudioPlayer(
                                    localPath: clip.localPath,
                                    audioUrl: clip.remoteUrl,
                                    recordedTime: widget.report.recordedAt.add(clip.timestamp),
                                  ),
                                );
                              }),
                              if (widget.report.snoreAudioClips.length > 5)
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SnoreClipsScreen(
                                          clips: widget.report.snoreAudioClips,
                                          recordedAt: widget.report.recordedAt,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text('See all ${widget.report.snoreAudioClips.length} recordings'),
                                ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),*/
                    ],
                    FadeTransition(
                      opacity: _section1Fade,
                      child: SlideTransition(
                        position: _section1Slide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildSectionHeader('Insights', Icons.lightbulb_rounded, textPrimary),
                            const SizedBox(height: 12),
                            _buildInsightsSection(cardBg, cardBorder, textPrimary, textSec),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                    // ── Section 2: Sleep Stages Graph ──
                    FadeTransition(
                      opacity: _section2Fade,
                      child: SlideTransition(
                        position: _section2Slide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Sleep Graphs', Icons.bar_chart_rounded, textPrimary),
                            const SizedBox(height: 8),
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
                          ],
                        ),
                      ),
                    ),
                    // ── Section 3: Snore Intensity + Actions ──
                    FadeTransition(
                      opacity: _section3Fade,
                      child: SlideTransition(
                        position: _section3Slide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SnoreIntensityTimelineChart(report: widget.report),
                            if (widget.report.snoreAudioClips.isNotEmpty)
                              _buildAudioClipsCard(cardBg, cardBorder, textPrimary, textSec),
                            if (widget.report.apneaHypopneaIndex > 0 || widget.report.detectedApneaEvents.isNotEmpty)
                              _buildAhiCard(cardBg, cardBorder, textPrimary, textSec),
                            const SizedBox(height: 32),
                            _buildActionButtons(context),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    ),
  );
}

  // ─── Custom AppBar ─────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, Color textPrimary, Color cardBorder, Color cardBg) {
    final dateStr = DateFormat('EEEE, d MMM').format(widget.report.recordedAt);
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Icon(Icons.arrow_back_ios_rounded,
                  color: textPrimary, size: 16),
            ),
          ),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Icon(Icons.share_rounded,
                color: textPrimary, size: 16),
          ),
        ],
      ),
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

  // ─── Sleep Efficiency Pill Row ─────────────────────────────────
  Widget _buildEfficiencyPillRow(Color cardBg, Color cardBorder, Color textPrimary, Color textSec) {
    final efficiency  = widget.report.sleepEfficiencyPercent;
    final snoringFree = widget.report.snoringFreePercent;
    // Breathing regularity derived from apnea events per hour (inverse of disruption)
    final apneaEvents = widget.report.suspectedApneaEvents.length;
    final hours       = widget.report.totalDuration.inSeconds / 3600.0;
    final eventsPerH  = hours > 0.1 ? apneaEvents / hours : 0.0;
    final regularity  = (100 - (eventsPerH * 5).clamp(0.0, 60.0)).clamp(40.0, 100.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _efficiencyPill(
            icon: Icons.bedtime_outlined,
            color: AppTheme.accentTeal,
            label: 'Sleep Efficiency',
            value: '${efficiency.toInt()}%',
            cardBg: cardBg, cardBorder: cardBorder, textPrimary: textPrimary, textSec: textSec,
          )),
          const SizedBox(width: 8),
          Expanded(child: _efficiencyPill(
            icon: Icons.air_rounded,
            color: AppTheme.primaryIndigo,
            label: 'Snore-Free',
            value: '${snoringFree.toInt()}%',
            cardBg: cardBg, cardBorder: cardBorder, textPrimary: textPrimary, textSec: textSec,
          )),
          const SizedBox(width: 8),
          Expanded(child: _efficiencyPill(
            icon: Icons.favorite_border_rounded,
            color: AppTheme.primaryGold,
            label: 'Regularity',
            value: '${regularity.toInt()}%',
            cardBg: cardBg, cardBorder: cardBorder, textPrimary: textPrimary, textSec: textSec,
          )),
        ],
      ),
    );
  }

  Widget _efficiencyPill({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSec,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: textSec, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
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

  // ─── Snore Audio Clips Card ──────────────────────────────────
  Widget _buildAudioClipsCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSec) {
    return const SizedBox.shrink();
    /*
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context, 
          AppRouter.snoreClips, 
          arguments: {
            'clips': widget.report.snoreAudioClips,
            'recordedAt': widget.report.recordedAt,
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headphones_rounded, color: AppTheme.primaryIndigo, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Listen to Snore Recordings',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.report.snoreAudioClips.length} audio clips saved',
                    style: TextStyle(color: textSec, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryIndigo, size: 16),
          ],
        ),
      ),
    );
    */
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

  // ─── AHI Clinical Summary Card ─────────────────────────────────
  Widget _buildAhiCard(Color cardBg, Color cardBorder, Color textPrimary, Color textSec) {
    final ahi      = widget.report.apneaHypopneaIndex;
    final label    = widget.report.ahiClassification;
    final events   = widget.report.detectedApneaEvents;
    final highConf = events.where((e) => e.confidence >= 0.75).length;
    final hasActi  = widget.report.actigraphyAvailable;

    // Colour coding by OSA severity
    final Color classColor = ahi < 5
        ? AppTheme.accentTeal
        : ahi < 15
            ? AppTheme.primaryGold
            : ahi < 30
                ? const Color(0xFFFB923C) // orange
                : AppTheme.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: classColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: classColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.monitor_heart_rounded, color: classColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AHI Analysis',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Apnea-Hypopnea Index',
                        style: TextStyle(color: textSec, fontSize: 11)),
                  ],
                ),
              ),
              // Actigraphy badge
              if (hasActi)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors_rounded, color: AppTheme.accentTeal, size: 11),
                      const SizedBox(width: 4),
                      Text('Motion', style: TextStyle(color: AppTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // AHI score row
          Row(
            children: [
              // Big AHI number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ahi.toStringAsFixed(1),
                      style: TextStyle(
                        color: classColor,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    Text('events / hour', style: TextStyle(color: textSec, fontSize: 11)),
                  ],
                ),
              ),
              // Classification badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: classColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: classColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: classColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Event stats row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: textPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ahiStat('Total Events', '${events.length}', textPrimary, textSec),
                Container(width: 1, height: 30, color: textSec.withValues(alpha: 0.15)),
                _ahiStat('High Confidence', '$highConf', textPrimary, textSec),
                Container(width: 1, height: 30, color: textSec.withValues(alpha: 0.15)),
                _ahiStat('Avg Gap', events.isEmpty ? '--' : '${(events.map((e) => e.gapDuration.inSeconds).reduce((a, b) => a + b) / events.length).round()}s', textPrimary, textSec),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // AHI scale reference
          _buildAhiScale(ahi, textSec),
          const SizedBox(height: 10),
          Text(
            'AHI is calculated using the Crescendo–Silence–Gasp clinical pattern. '
            'This is a screening tool only. Please consult a physician for a formal diagnosis.',
            style: TextStyle(color: textSec, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _ahiStat(String label, String value, Color textPrimary, Color textSec) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: textSec, fontSize: 10)),
      ],
    );
  }

  Widget _buildAhiScale(double ahi, Color textSec) {
    final stops = [
      (0.0, 5.0,  'Normal',   AppTheme.accentTeal),
      (5.0, 15.0, 'Mild',     AppTheme.primaryGold),
      (15.0, 30.0,'Moderate', const Color(0xFFFB923C)),
      (30.0, 50.0,'Severe',   AppTheme.error),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AHI Reference Scale', style: TextStyle(color: textSec, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: stops.map((stop) {
            final (lo, hi, name, color) = stop;
            final isActive = ahi >= lo && ahi < hi;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
                      : null,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(height: 3),
                    Text(name, style: TextStyle(color: color, fontSize: 8, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500), textAlign: TextAlign.center),
                    Text('${lo.toInt()}-${hi == 50.0 ? "30+" : hi.toInt()}', style: TextStyle(color: textSec, fontSize: 7)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
