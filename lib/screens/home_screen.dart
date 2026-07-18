import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../modules/journal/screens/morning_journal_screen.dart';
import '../modules/journal/screens/journal_list_screen.dart';
import '../modules/sleep_analysis/screens/sleep_stages_screen.dart';
import '../modules/sleep_analysis/screens/snore_tracking_screen.dart';


import '../core/theme/app_theme.dart';
import '../core/theme/chart_theme.dart';
import '../core/providers/theme_provider.dart';
import '../modules/onboarding/providers/onboarding_provider.dart';
import '../modules/onboarding/models/user_profile.dart';
import '../modules/sleep_analysis/models/sleep_report.dart';
import '../modules/sleep_analysis/providers/sleep_analysis_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/router/app_router.dart';
import '../core/services/firestore_service.dart';
import '../core/widgets/sleep_calendar_widget.dart';
import '../modules/paywall/providers/subscription_provider.dart';
import '../modules/blogs/widgets/blog_hub_widget.dart';

const _moods = [
  ('😊', 'Good', Color(0xFF34D399)),
  ('😐', 'Okay', Color(0xFFF97316)),
  ('😔', 'Bad', Color(0xFFF87171)),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SleepReport> _recent = [];
  String? _lastUid;

  void _openSleepFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SleepFlowSheet(onStart: (alarmTime) {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          AppRouter.sleepAnalysis,
          arguments: {
            'autoStart': false,
            'alarmTime': alarmTime,
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.uid != _lastUid) _lastUid = auth.uid;
    final profile = context.watch<OnboardingProvider>().profile;
    final sleepProvider = context.watch<SleepAnalysisProvider>();
    _recent = sleepProvider.history.take(7).toList();
    final themeProvider = context.watch<ThemeProvider>();
    final isLight = !themeProvider.isDarkMode;

    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final cardBg = isLight ? AppTheme.surfaceLight : const Color(0xFF0E1130);
    final cardBorder = isLight ? AppTheme.cardBorderLight : const Color(0xFF2A2D5E);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final uid = auth.uid ?? await FirestoreService.deviceUid;
            if (!context.mounted) return;
            await context.read<SleepAnalysisProvider>().loadHistory(uid);
          },
          color: AppTheme.primaryIndigo,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildHeader(profile.name, isLight, textPrimary, textSec, themeProvider),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 24),
                // ── Combined Sleep Score + Analyser Card ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCombinedSleepCard(isLight, textPrimary, textSec, cardBg, cardBorder),
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 16),
                // ── Daily Sleep Goal ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildDailyGoalCard(isLight, textPrimary, textSec, cardBg, cardBorder),
                ).animate().fadeIn(delay: 130.ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildMetricsRow(profile, isLight, textPrimary, textSec, cardBg, cardBorder),
                ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildWeeklyTrendChart(isLight, textPrimary, textSec, cardBg, cardBorder),
                ).animate().fadeIn(delay: 300.ms, duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCalendarSection(textPrimary),
                ).animate().fadeIn(delay: 350.ms, duration: 350.ms),
                const SizedBox(height: 24),
                // BlogHubWidget handles its own horizontal padding to bleed to edges
                BlogHubWidget(isLight: isLight).animate().fadeIn(delay: 400.ms, duration: 350.ms),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildAskNidraBanner(),
                ).animate().fadeIn(delay: 450.ms, duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildQuickAccess(isLight, textPrimary, textSec, cardBg, cardBorder),
                ).animate().fadeIn(delay: 500.ms, duration: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header (Greeting + Theme Toggle + Profile) ──────────────────────
  Widget _buildHeader(String name, bool isLight, Color textPrimary, Color textSec, ThemeProvider tp) {
    final h = DateTime.now().hour;
    String greeting = '';
    String subtext = '';

    if (h >= 5 && h < 12) {
      greeting = 'Good Morning';
      subtext = 'Fresh start, motivation';
    } else if (h >= 12 && h < 17) {
      greeting = 'Good Afternoon';
      subtext = 'Energy dip, consistency';
    } else if (h >= 17 && h < 21) {
      greeting = 'Good Evening';
      subtext = 'Workout time, stress relief';
    } else {
      greeting = 'Good Night';
      subtext = 'Wind down, recovery';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${name.isEmpty ? 'Friend' : name}',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(subtext, style: TextStyle(fontSize: 14, color: textSec)),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: textPrimary,
                size: 22,
              ),
              onPressed: () => tp.toggleTheme(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRouter.settings),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'F',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryIndigo,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  // ── Sleep Score Card (restored from original design) ──────────────────────
  // ── Combined Sleep Score + Sleep Sound Analyser Card ──────────────────────
  Widget _buildCombinedSleepCard(bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final hasData = _recent.isNotEmpty;
    final report = hasData ? _recent.first : null;
    final score = report?.qualityScore.toInt() ?? 0;

    final scoreColor = score >= 80
        ? const Color(0xFF2DDA93)
        : score >= 60
            ? const Color(0xFF38BDF8)
            : AppTheme.error;
    final scoreLabel = score >= 80 ? 'Good Sleep' : score >= 60 ? 'Fair Sleep' : 'Poor Sleep';

    final titleColor = isLight ? const Color(0xFF1A1D36) : Colors.white;
    final subtitleColor = isLight ? const Color(0xFF5C638A) : Colors.white.withValues(alpha: 0.65);
    final badgeBg = isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.1);
    final badgeBorder = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.2);
    final badgeText = isLight ? const Color(0xFF5C638A) : Colors.white;
    final badgeIcon = isLight ? const Color(0xFF8B5CF6) : Colors.white;
    final dividerColor = isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.08);

    final bgGradient = isLight
        ? const LinearGradient(colors: [Color(0xFFFAFBFE), Color(0xFFEFF2F9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(colors: [Color(0xFF1A1035), Color(0xFF0F1225)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    final isDaytime = isLight; // align celestial body with app theme, not clock

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: bgGradient,
        border: Border.all(
          color: isLight ? const Color(0xFFDDE3F0) : const Color(0xFF2A2D5E),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withValues(alpha: isLight ? 0.10 : 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // ── Subtle decorative backdrop only – small, top-right corner ──
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isDaytime
                        ? [const Color(0xFFFFE082).withValues(alpha: 0.35), Colors.transparent]
                        : [const Color(0xFF8B8BF8).withValues(alpha: 0.20), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Small celestial icon (decorative only, never overlaps content)
            Positioned(
              top: 18,
              right: 22,
              child: isDaytime
                  ? Icon(Icons.wb_sunny_rounded,
                      color: const Color(0xFFFFCA28).withValues(alpha: 0.85), size: 28)
                  : Icon(Icons.nightlight_round,
                      color: const Color(0xFF9B9EF8).withValues(alpha: 0.80), size: 26),
            ),
            // Tiny accent stars
            Positioned(
              top: 48,
              right: 26,
              child: Icon(Icons.star_rounded,
                  color: isDaytime
                      ? const Color(0xFFFFB300).withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.25),
                  size: 7),
            ),
            Positioned(
              top: 60,
              right: 52,
              child: Icon(Icons.star_rounded,
                  color: isDaytime
                      ? const Color(0xFF818CF8).withValues(alpha: 0.40)
                      : Colors.white.withValues(alpha: 0.20),
                  size: 5),
            ),

            // Subtle wave decoration at the bottom of the card
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 50),
                painter: _CardWavePainter(isLight: isLight),
              ),
            ),

            // ── All content – guaranteed to always be above decorations ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── SECTION 1: Sleep Score ────────────────────────────
                  GestureDetector(
                    onTap: () {
                      if (hasData) {
                        Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: score block
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sleep Score',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isLight ? const Color(0xFF6B7280) : Colors.white54,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    hasData ? '$score' : '--',
                                    style: GoogleFonts.outfit(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w800,
                                      color: hasData ? scoreColor : textSec,
                                      height: 1.0,
                                      letterSpacing: -2,
                                    ),
                                  ),
                                  if (hasData)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 3, bottom: 6),
                                      child: Text(
                                        '/100',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isLight ? const Color(0xFF9CA3AF) : const Color(0xFF5C638A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (hasData)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: scoreColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.check, color: scoreColor, size: 11),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      scoreLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: scoreColor,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'No recording yet',
                                  style: TextStyle(fontSize: 12, color: textSec),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 60), // Reserve space for the decorative icon top-right

                        // Full Report chip – aligned top so it never overlaps the score
                        if (hasData)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Full Report',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: scoreColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: scoreColor),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Divider ──────────────────────────────────────────────
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, dividerColor, Colors.transparent],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── SECTION 2: Sleep Sound Analyser ──────────────────────
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLight
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: isLight ? const Color(0xFF8B5CF6) : const Color(0xFFB483F6), size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'Understand. Improve. Sleep better.',
                          style: GoogleFonts.inter(
                            color: isLight ? const Color(0xFF6D28D9) : const Color(0xFFCBB4FC),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title row
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sleep Sound ',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isLight ? const Color(0xFF1A1D36) : Colors.white,
                            height: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: 'Analyser',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            foreground: Paint()
                              ..shader = const LinearGradient(
                                colors: [Color(0xFFB483F6), Color(0xFF6D28D9)],
                              ).createShader(const Rect.fromLTWH(0, 0, 130, 30)),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    "Start recording before you sleep. Stop when you wake up — we'll generate a full sleep quality report.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isLight ? const Color(0xFF5C638A) : Colors.white.withValues(alpha: 0.60),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Button
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: isLight ? 0.25 : 0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _openSleepFlow,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 18),
                              ),
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    'Start Recording',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Metrics Row ───────────────────────────────────────────────────────
  Widget _buildMetricsRow(UserProfile? profile, bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final report = _recent.isNotEmpty ? _recent.first : null;
    
    // Fallbacks if no history exists yet
    String durationStr = '--';
    String snoreStatusStr = '--';
    String snoreSubStr = '--';
    Color snoreColor = textSec;

    final durationValues = <double>[];
    final snoreValues = <double>[];

    if (_recent.isNotEmpty) {
      final recent7 = _recent.take(7).toList().reversed.toList();
      for (final r in recent7) {
        durationValues.add(r.totalDuration.inMinutes / 60.0);
        snoreValues.add(r.snoringEventCount.toDouble());
      }

      if (report != null) {
        // Sleep Duration
        durationStr = '${report.totalDuration.inHours}h ${report.totalDuration.inMinutes % 60}m';

        // Snoring Status — classify by DURATION not event count
        // <10 min = Minimal, 10-30 min = Moderate, >30 min = Heavy
        final snoreMins = report.snoringDuration.inMinutes;
        if (snoreMins == 0) {
          snoreStatusStr = 'None';
          snoreColor = AppTheme.accentTeal;
        } else if (snoreMins < 10) {
          snoreStatusStr = 'Minimal';
          snoreColor = AppTheme.accentTeal;
        } else if (snoreMins < 30) {
          snoreStatusStr = 'Moderate';
          snoreColor = AppTheme.primaryGold;
        } else {
          snoreStatusStr = 'Heavy';
          snoreColor = AppTheme.error;
        }
        snoreSubStr = '${report.snoringDuration.inHours}h ${report.snoringDuration.inMinutes % 60}m';
      }
    }

    final goalMinutes = profile?.goalDurationMinutes ?? 480;
    final goalText = goalMinutes % 60 == 0 ? 'Goal: ${goalMinutes ~/ 60}h' : 'Goal: ${goalMinutes ~/ 60}h ${goalMinutes % 60}m';

    return Row(
      children: [
        _buildMiniMetricCard('Sleep Duration', durationStr, goalText, AppTheme.primaryGold,
            _buildBarSparkline(AppTheme.primaryGold, durationValues), isLight, textPrimary, textSec, cardBg, cardBorder),
        const SizedBox(width: 16),
        _buildMiniMetricCard('Snoring Status', snoreStatusStr, snoreSubStr, snoreColor,
            _buildWaveSparkline(snoreColor, snoreValues), isLight, textPrimary, textSec, cardBg, cardBorder),
      ],
    );
  }

  Widget _buildMiniMetricCard(String title, String value, String sub, Color accent,
      Widget chart, bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration(
          borderRadius: BorderRadius.circular(16),
          isLightMode: isLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
            Text(sub, style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(height: 44, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildBarSparkline(Color color, List<double> values) {
    if (values.isEmpty) values = [0];
    final maxY = values.reduce(max) * 1.2;
    return BarChart(BarChartData(
      minY: 0, maxY: maxY == 0 ? 10 : maxY,
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      barTouchData: BarTouchData(enabled: false),
      barGroups: List.generate(values.length, (i) {
        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: values[i], color: color, width: 4, borderRadius: BorderRadius.circular(2)),
        ]);
      }),
    ));
  }

  Widget _buildWaveSparkline(Color color, List<double> values) {
    if (values.isEmpty) values = [0, 0];
    if (values.length == 1) values = [0, values[0]];
    final maxY = values.reduce(max) * 1.2;
    return LineChart(LineChartData(
      minY: 0, maxY: maxY == 0 ? 10 : maxY,
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
          isCurved: true, color: color, barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.2)),
        ),
      ],
    ));
  }

  // ── Weekly Trend Chart ────────────────────────────────────────────────
  Widget _buildWeeklyTrendChart(bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final recent7 = _recent.take(7).toList().reversed.toList();
    final scores = <double>[];
    for (var r in recent7) {
      scores.add(r.qualityScore);
    }
    // Pad to 7
    while (scores.length < 7) {
      scores.insert(0, 0); // pad at start
    }

    // Build date labels for the 7 slots ending today
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      if (i == 6) return 'Today';
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryIndigo, AppTheme.accentTeal],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.bar_chart_rounded,
                color: AppTheme.primaryIndigo, size: 18),
            const SizedBox(width: 8),
            Text(
              'Weekly Trend',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(
            borderRadius: BorderRadius.circular(20),
            isLightMode: isLight,
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              minY: 0,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final dayIndex = value.toInt();
                      final text = (dayIndex >= 0 && dayIndex < dayLabels.length) ? dayLabels[dayIndex] : '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(text, style: ChartTheme.getAxisTextStyle(isLight, isHighlight: dayIndex == 6)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: ChartTheme.gridData(isLight, horizontalInterval: 25),
              borderData: ChartTheme.borderData,
              barGroups: List.generate(7, (index) {
                final score = scores[index];
                final color = score >= 80 ? AppTheme.accentTeal : (score >= 60 ? AppTheme.primaryGold : AppTheme.error);
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: score,
                      color: score == 0 ? Colors.transparent : color,
                      width: 12,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      backDrawRodData: ChartTheme.backgroundBar(isLight, 100),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── Daily Goal Card ───────────────────────────────────────────────────
  Widget _buildDailyGoalCard(bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final hoursRecorded = _recent.isNotEmpty ? _recent.first.totalDuration.inHours : 0;
    final hoursRecordedDouble = _recent.isNotEmpty ? _recent.first.totalDuration.inMinutes / 60.0 : 0.0;
    const goalHours = 8.0;
    final progress = (hoursRecordedDouble / goalHours).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: BorderRadius.circular(20),
        isLightMode: isLight,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _GoalProgressPainter(
                    progress: progress,
                    isLight: isLight,
                    color: AppTheme.accentTeal,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nights_stay_rounded, color: AppTheme.accentTeal, size: 18),
                      const SizedBox(height: 2),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Sleep Goal',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hoursRecorded > 0
                      ? 'Recorded: ${hoursRecorded}h ${_recent.first.totalDuration.inMinutes % 60}m / 8h goal'
                      : 'Goal: 8h — Start recording tonight!',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSec,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: textSec.withValues(alpha: 0.5),
            size: 24,
          ),
        ],
      ),
    );
  }



  // ── Ask Nidra AI Banner ───────────────────────────────────────────────
  Widget _buildAskNidraBanner() {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;

    return GestureDetector(
      onTap: () {
        if (isPremium) {
          Navigator.pushNamed(context, AppRouter.nidraChat);
        } else {
          Navigator.pushNamed(context, AppRouter.paywall);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Nidra AI',
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text(
                    'Get personalized insights and recommendations for better sleep.',
                    style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 30),
                  if (!isPremium)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded, size: 10, color: AppTheme.primaryGold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sleep Calendar ─────────────────────────────────────────────────────
  Widget _buildCalendarSection(Color textPrimary) {
    final allReports = context.read<SleepAnalysisProvider>().history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryIndigo, AppTheme.accentTeal],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.calendar_month_rounded,
                color: AppTheme.primaryIndigo, size: 18),
            const SizedBox(width: 8),
            Text(
              'Sleep Calendar',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 21),
          child: Text(
            'Tap a dot to view your sleep report',
            style: TextStyle(
              fontSize: 12,
              color: textPrimary.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SleepCalendarWidget(reports: allReports),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _calLegend(AppTheme.accentTeal, 'Good (≥80)', textPrimary),
            const SizedBox(width: 16),
            _calLegend(AppTheme.primaryGold, 'Fair (60–79)', textPrimary),
            const SizedBox(width: 16),
            _calLegend(AppTheme.error, 'Poor (<60)', textPrimary),
          ],
        ),
      ],
    );
  }

  Widget _calLegend(Color color, String label, Color textPrimary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textPrimary.withValues(alpha: 0.45),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Quick Access ──────────────────────────────────────────────────────
  Widget _buildQuickAccess(bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryIndigo, AppTheme.accentTeal],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.bolt_rounded,
                color: AppTheme.primaryIndigo, size: 18),
            const SizedBox(width: 8),
            Text(
              'Quick Access',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickItem(Icons.book_rounded, 'Sleep Diary', AppTheme.primaryIndigo, textSec, cardBg, cardBorder,
                  () => Navigator.pushNamed(context, AppRouter.sleepHistory)),
              _quickItem(Icons.self_improvement_rounded, 'Yoga', AppTheme.accentTeal, textSec, cardBg, cardBorder,
                  () {
                    // Navigate to MainNavScreen and switch to Wellness tab (index 1)
                    Navigator.pushNamedAndRemoveUntil(context, AppRouter.mainNav, (r) => false, arguments: 1);
                  }),
              _quickItem(Icons.spa_rounded, 'Meditation', AppTheme.primaryGold, textSec, cardBg, cardBorder,
                  () => Navigator.pushNamed(context, AppRouter.relaxation)),
              _quickItem(Icons.mic_rounded, 'Snore Track', AppTheme.error, textSec, cardBg, cardBorder, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SnoreTrackingScreen()))),
              _quickItem(Icons.bar_chart_rounded, 'Sleep Stages', const Color(0xFF8B5CF6), textSec, cardBg, cardBorder,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepStagesScreen()))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickItem(IconData icon, String label, Color color, Color textSec, Color cardBg, Color cardBorder, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSec),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalProgressPainter extends CustomPainter {
  final double progress;
  final bool isLight;
  final Color color;

  _GoalProgressPainter({required this.progress, required this.isLight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 4; // padding for stroke
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, bgPaint);

    if (progress > 0) {
      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, glowPaint);

      // Progress arc
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.5), color],
          startAngle: -pi / 2,
          endAngle: -pi / 2 + 2 * pi * progress,
          transform: GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


// ── 2-Step Sleep Flow Bottom Sheet ────────────────────────────────────
class _SleepFlowSheet extends StatefulWidget {
  final Function(TimeOfDay? alarmTime) onStart;
  const _SleepFlowSheet({required this.onStart});
  @override
  State<_SleepFlowSheet> createState() => _SleepFlowSheetState();
}

class _SleepFlowSheetState extends State<_SleepFlowSheet> {
  late final PageController _pageController;
  int _step = 0;
  int? _mood;
  TimeOfDay _alarm = const TimeOfDay(hour: 7, minute: 0);
  bool _vibration = true;
  bool _soundAlarm = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final border = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                onPressed: _step > 0
                    ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                    : () => Navigator.pop(context),
              ),
              Row(children: List.generate(2, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _step ? 24 : 8, height: 8,
                decoration: BoxDecoration(
                  color: i == _step ? AppTheme.primaryIndigo : border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ))),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _step = page),
              children: [_moodStep(isLight), _alarmStep(isLight)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodStep(bool isLight) {
    final textP = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textS = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return Column(
      key: const ValueKey(0),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              Text('How are you feeling?', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: textP)),
              const SizedBox(height: 8),
              Text('Your mood affects your sleep quality.', style: TextStyle(color: textS)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_moods.length, (i) {
                  final (emoji, label, color) = _moods[i];
                  final sel = _mood == i;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      decoration: BoxDecoration(
                        color: sel ? color.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? color : border, width: sel ? 2 : 1),
                      ),
                      child: Column(children: [
                        Text(emoji, style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? color : textS)),
                      ]),
                    ),
                  );
                }),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: _nextBtn('Next →', _mood != null
              ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
              : null),
        ),
      ],
    );
  }

  Widget _alarmStep(bool isLight) {
    final textP = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textS = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Text('Set Your Alarm', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: textP)),
        const SizedBox(height: 8),
        Text('When do you want to wake up?', style: TextStyle(color: textS)),
        const SizedBox(height: 32),
        AnimatedOpacity(
          opacity: _soundAlarm ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onTap: _soundAlarm ? () async {
              final t = await showTimePicker(context: context, initialTime: _alarm,
                  builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: AppTheme.primaryIndigo, surface: AppTheme.surface),
                  ), child: child!));
              if (t != null) setState(() => _alarm = t);
            } : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
              ),
              child: Text(_alarm.format(context),
                  style: GoogleFonts.outfit(fontSize: 52, fontWeight: FontWeight.w800, color: textP)),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _toggleRow('Vibration', _vibration, (v) => setState(() => _vibration = v), isLight, textP, border),
        const SizedBox(height: 12),
        _toggleRow('Enable Alarm', _soundAlarm, (v) => setState(() => _soundAlarm = v), isLight, textP, border),
        const SizedBox(height: 40),
        _nextBtn('🌙  Start Sleep Session', () => widget.onStart(_soundAlarm ? _alarm : null)),
      ]),
    );
  }

  Widget _nextBtn(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      opacity: onTap != null ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primaryIndigo.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
      ),
    ),
  );

  Widget _toggleRow(String label, bool val, ValueChanged<bool> onChange, bool isLight, Color textP, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textP, fontWeight: FontWeight.w500)),
          Switch(value: val, onChanged: onChange,
              activeThumbColor: AppTheme.primaryIndigo, inactiveTrackColor: border),
        ],
      ),
    );
  }
}

// Custom painter for the Sleep Score card — soft wave/landscape background
class _SleepScoreCardPainter extends CustomPainter {
  final bool isLight;
  _SleepScoreCardPainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    // Back wave
    final backWavePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? [const Color(0xFFEEF2FC), const Color(0xFFDFE6F5)]
            : [const Color(0xFF191C36), const Color(0xFF11142B)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6));

    final backPath = Path();
    backPath.moveTo(0, size.height * 0.65);
    backPath.quadraticBezierTo(size.width * 0.25, size.height * 0.55, size.width * 0.5, size.height * 0.7);
    backPath.quadraticBezierTo(size.width * 0.75, size.height * 0.85, size.width, size.height * 0.65);
    backPath.lineTo(size.width, size.height);
    backPath.lineTo(0, size.height);
    backPath.close();
    canvas.drawPath(backPath, backWavePaint);

    // Front wave
    final frontWavePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLight
            ? [const Color(0xFFDFE7F8), const Color(0xFFC5D5F0)]
            : [const Color(0xFF1F2342), const Color(0xFF151833)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4));

    final frontPath = Path();
    frontPath.moveTo(0, size.height * 0.85);
    frontPath.quadraticBezierTo(size.width * 0.2, size.height * 1.0, size.width * 0.55, size.height * 0.8);
    frontPath.quadraticBezierTo(size.width * 0.8, size.height * 0.65, size.width, size.height * 0.75);
    frontPath.lineTo(size.width, size.height);
    frontPath.lineTo(0, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, frontWavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Paints a subtle wave at the bottom of the hero card.
class _CardWavePainter extends CustomPainter {
  final bool isLight;
  _CardWavePainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isLight
          ? const Color(0xFF8B5CF6).withValues(alpha: 0.05)
          : const Color(0xFF6366F1).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.1,
      size.width * 0.5, size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.9,
      size.width, size.height * 0.4,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CardWavePainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}
