import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../modules/journal/screens/morning_journal_screen.dart';
import '../modules/sleep_analysis/screens/sleep_stages_screen.dart';
import '../modules/sleep_analysis/screens/snore_tracking_screen.dart';
import '../modules/rewards/widgets/rewards_balance_chip.dart';

import '../core/theme/app_theme.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(profile.name, isLight, textPrimary, textSec, themeProvider),
                const SizedBox(height: 20),
                _buildDailyGoalCard(isLight, textPrimary, textSec, cardBg, cardBorder),
                const SizedBox(height: 20),
                _buildHeroCard(isLight, textPrimary, textSec, cardBg, cardBorder),
                const SizedBox(height: 16),
                _buildMetricsRow(profile, isLight, textPrimary, textSec, cardBg, cardBorder),
                const SizedBox(height: 24),
                _buildWeeklyTrendChart(isLight, textPrimary, textSec, cardBg, cardBorder),
                const SizedBox(height: 24),
                _buildCalendarSection(textPrimary),
                const SizedBox(height: 24),
                BlogHubWidget(isLight: isLight),
                const SizedBox(height: 20),
                _buildAskNidraBanner(),
                const SizedBox(height: 20),
                _buildQuickAccess(isLight, textPrimary, textSec, cardBg, cardBorder),
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
    IconData timeIcon;
    Color iconColor;
    String subtext = '';

    if (h >= 5 && h < 12) {
      greeting = 'Good Morning';
      timeIcon = Icons.wb_sunny_rounded;
      iconColor = const Color(0xFFFDB813); // Sun color
      subtext = 'Fresh start, motivation';
    } else if (h >= 12 && h < 17) {
      greeting = 'Good Afternoon';
      timeIcon = Icons.wb_sunny_rounded;
      iconColor = const Color(0xFFFDB813);
      subtext = 'Energy dip, consistency';
    } else if (h >= 17 && h < 21) {
      greeting = 'Good Evening';
      timeIcon = Icons.nightlight_round;
      iconColor = isLight ? const Color(0xFF5C6BC0) : const Color(0xFF9FA8DA); // Evening color
      subtext = 'Workout time, stress relief';
    } else {
      greeting = 'Good Night';
      timeIcon = Icons.nightlight_round;
      iconColor = isLight ? const Color(0xFF3949AB) : const Color(0xFF7986CB); // Night color
      subtext = 'Wind down, recovery';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '$greeting, ${name.isEmpty ? 'Friend' : name}',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(timeIcon, color: iconColor, size: 22),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: TextStyle(fontSize: 14, color: textSec),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: textPrimary, size: 22,
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
    );
  }

  // ── Hero Sleep Score Card (Modern Design) ──────────────────────────────────
  Widget _buildHeroCard(bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final hasData = _recent.isNotEmpty;
    final report = hasData ? _recent.first : null;
    final score = report?.qualityScore.toInt() ?? 0;
    
    // The design uses a vivid teal/green for good scores, cyan/blue for fair.
    final scoreColor = score >= 80
        ? const Color(0xFF2DDA93)
        : score >= 60
            ? const Color(0xFF38BDF8)
            : AppTheme.error;
    final scoreLabel = score >= 80 ? 'Good Sleep' : score >= 60 ? 'Fair Sleep' : 'Poor Sleep';

    // Base colors matching the uploaded design precisely
    final bgLight = const Color(0xFFFAFBFE);
    final bgDark = const Color(0xFF0F1225);
    final cardBgColor = isLight ? bgLight : bgDark;

    return GestureDetector(
      onTap: () {
        if (hasData) {
          Navigator.pushNamed(context, AppRouter.sleepReport, arguments: report);
        } else {
          _openSleepFlow();
        }
      },
      child: Container(
        width: double.infinity,
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cardBgColor,
          border: Border.all(color: isLight ? Colors.white : const Color(0xFF1C1F3A), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryIndigo.withValues(alpha: isLight ? 0.06 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Background Waves
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeroCardBackgroundPainter(isLight: isLight),
                ),
              ),
              
              // 2. Stars & Moon
              Positioned(
                top: 24,
                right: 28,
                child: Icon(
                  Icons.nightlight_round,
                  color: isLight ? const Color(0xFFB0BAE3) : const Color(0xFF4A55A2),
                  size: 28,
                ),
              ),
              Positioned(
                top: 36,
                right: 90,
                child: Icon(Icons.star_rounded, color: isLight ? const Color(0xFFFFD54F) : Colors.white24, size: 10),
              ),
              Positioned(
                top: 60,
                right: 140,
                child: Icon(Icons.star_rounded, color: isLight ? const Color(0xFF818CF8) : Colors.white24, size: 8),
              ),
              
              // 3. Glowing Circle (behind pillow) — decorative ring only, score shown in left column
              if (hasData)
                Positioned(
                  right: 42,
                  bottom: 30,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(color: scoreColor, width: 6),
                      boxShadow: [
                        BoxShadow(
                          color: scoreColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Pillow Graphic
              if (hasData)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    width: 140,
                    height: 48, // Slightly taller for more plumpness
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isLight
                            ? [Colors.white, const Color(0xFFE8EEFC), const Color(0xFFD0D9F0)]
                            : [const Color(0xFF38407B), const Color(0xFF242954), const Color(0xFF161A3A)],
                        stops: const [0.1, 0.6, 1.0],
                      ),
                      boxShadow: [
                        // Soft drop shadow
                        BoxShadow(
                          color: isLight ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                        // Inner highlight (top edge)
                        BoxShadow(
                          color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.12),
                          blurRadius: 4,
                          spreadRadius: -1,
                          offset: const Offset(0, -2),
                        ),
                        // Inner shadow (bottom edge)
                        BoxShadow(
                          color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // Pillow crease details to make it plump
                    child: Stack(
                      children: [
                        // Main horizontal seam
                        Center(
                          child: Container(
                            width: 110,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  isLight ? Colors.black.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Soft top highlight
                        Positioned(
                          top: 6,
                          left: 24,
                          right: 24,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  isLight ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Left Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Left Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sleep Score',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isLight ? const Color(0xFF1A1D36) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                hasData ? '$score' : '--',
                                style: GoogleFonts.outfit(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w800,
                                  color: hasData ? scoreColor : textSec,
                                  height: 1.0,
                                  letterSpacing: -2,
                                ),
                              ),
                              if (hasData)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    '/100',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isLight ? const Color(0xFF8B94B2) : const Color(0xFF5C638A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (hasData) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: scoreColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check, color: scoreColor, size: 12),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  scoreLabel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scoreColor,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'Tap to view full report →',
                              style: TextStyle(
                                fontSize: 13,
                                color: isLight ? const Color(0xFF7A84A6) : const Color(0xFF6B729E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: _openSleepFlow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryIndigo,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '🌙 Start Recording',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Vertical Divider
                    Container(
                      width: 1,
                      height: double.infinity,
                      margin: const EdgeInsets.only(right: 140), // leave space for right graphic
                      color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        if (snoreMins < 10) {
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 10, color: textSec),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
            Text(sub, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SizedBox(height: 32, child: chart),
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
        Text(
          'Weekly Trend',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
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
                        child: Text(text,
                          style: TextStyle(
                            color: dayIndex == 6 ? AppTheme.primaryIndigo : textSec,
                            fontSize: 9,
                            fontWeight: dayIndex == 6 ? FontWeight.w700 : FontWeight.w500,
                          )),
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
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
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
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: isLight ? Colors.grey.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                      ),
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
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Icon(Icons.nights_stay_rounded, color: AppTheme.accentTeal, size: 24),
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
        ],
      ),
    );
  }

  // ── Basic Profile Row ─────────────────────────────────────────────────
  Widget _buildProfileRow(UserProfile? profile, bool isLight, Color textPrimary, Color textSec, Color cardBg, Color cardBorder) {
    final heightCm = profile?.heightCm ?? 0.0;
    final weightKg = profile?.weightKg ?? 0.0;
    final bmi = profile?.bmi ?? 0.0;
    final age = profile?.age ?? 0;

    // Convert cm to feet/inches for display
    String heightStr;
    if (heightCm > 0) {
      final totalInches = (heightCm / 2.54).round();
      final ft = totalInches ~/ 12;
      final inches = totalInches % 12;
      heightStr = '$ft\'$inches"';
    } else {
      heightStr = '--';
    }

    final weightStr = weightKg > 0 ? '${weightKg.toStringAsFixed(0)} kg' : '--';
    final bmiStr = bmi > 0 ? bmi.toStringAsFixed(1) : '--';
    final ageStr = age > 0 ? '$age yrs' : '--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _profileItem(heightStr, 'Height', textPrimary, textSec),
          _divider(isLight),
          _profileItem(weightStr, 'Weight', textPrimary, textSec),
          _divider(isLight),
          _profileItem(bmiStr, 'BMI', textPrimary, textSec),
          _divider(isLight),
          _profileItem(ageStr, 'Age', textPrimary, textSec),
        ],
      ),
    );
  }

  Widget _divider(bool isLight) => Container(
    width: 1, height: 32,
    color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
  );

  Widget _profileItem(String value, String label, Color textPrimary, Color textSec) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: textSec)),
      ],
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
        Text('Quick Access',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickItem(Icons.book_rounded, 'Sleep Diary', AppTheme.primaryIndigo, textSec, cardBg, cardBorder,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningJournalScreen()))),
              _quickItem(Icons.self_improvement_rounded, 'Yoga', AppTheme.accentTeal, textSec, cardBg, cardBorder, null),
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSec),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
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

class _HeroCardBackgroundPainter extends CustomPainter {
  final bool isLight;
  _HeroCardBackgroundPainter({required this.isLight});

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
