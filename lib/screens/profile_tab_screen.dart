import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/theme_provider.dart';
import '../modules/onboarding/providers/onboarding_provider.dart';
import '../modules/sleep_analysis/services/sleep_storage_service.dart';
import '../modules/sleep_analysis/models/sleep_report.dart';

import '../core/services/firestore_service.dart';

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});
  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  List<SleepReport> _sessions = [];
  double _sleepGoal = 8.0; 
  bool _isDraggingSlider = false;
  bool _isLoadingSessions = true;

  static const _settings = [
    ('👤', 'Account Settings',       'Email, password, security'),
    ('🔔', 'Notifications',          'Reminders & alerts'),
    ('📤', 'Export Health Data',      'Download your sleep reports'),
    ('🔒', 'Privacy & Data',         'Manage data sharing'),
    ('ℹ️', 'About SnoreClinics',     'v1.0.0 · Made with ❤️'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadSessions();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.uid ?? await FirestoreService.deviceUid;
      final sessions = await SleepStorageService().getAllReports(uid);
      if (mounted) {
        setState(() { 
          _sessions = sessions; 
          _isLoadingSessions = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final profile = context.watch<OnboardingProvider>().profile;

    final authProvider = context.read<AuthProvider>();

    // Use profile goal unless actively dragging
    final profileGoalHours = profile.goalDurationMinutes / 60.0;
    final displayGoal = _isDraggingSlider ? _sleepGoal : profileGoalHours.clamp(5.0, 12.0);

    final avgScore = _sessions.isEmpty
        ? '--'
        : (_sessions.map((s) => s.qualityScore).reduce((a, b) => a + b) / _sessions.length).toInt().toString();
    final streak = _calcStreak();

    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            children: [
              // ── Avatar Hero ──────────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Background orb
                  Container(
                    width: double.infinity,
                    height: 280,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 0.8,
                        colors: [
                          AppTheme.primaryIndigo.withValues(alpha: 0.3),
                          isLight ? AppTheme.backgroundLight : AppTheme.background,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        // Pulsing avatar ring
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Transform.scale(
                            scale: _pulse.value,
                            child: child,
                          ),
                          child: Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryIndigo.withValues(alpha: 0.6),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'S',
                                  style: GoogleFonts.outfit(
                                      fontSize: 36, fontWeight: FontWeight.w800, color: isLight ? AppTheme.textPrimaryLight : Colors.white),
                                ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.name.isEmpty ? 'Sleep Champion' : profile.name,
                          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (authProvider.user?.email == null || authProvider.user!.email!.isEmpty) ? 'sleep@snore.clinic' : authProvider.user!.email!,
                          style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 24),

                        // Stats badges row
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                          decoration: AppTheme.glassDecoration(opacity: 0.15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _isLoadingSessions
                              ? [const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())]
                              : [
                                  _statBadge('🔥', '$streak', 'Day Streak', const Color(0xFFF97316), isLight),
                                  Container(width: 1, height: 40, color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                                  _statBadge('⭐', avgScore, 'Avg Score', AppTheme.primaryIndigo, isLight),
                                  Container(width: 1, height: 40, color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder),
                                  _statBadge('📅', '${_sessions.length}', 'Sessions', AppTheme.accentTeal, isLight),
                                ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Sleep Goal Slider ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassDecoration(opacity: 0.12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🎯  Sleep Goal',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
                              const SizedBox(height: 2),
                              Text('Set your target sleep duration',
                                  style: TextStyle(fontSize: 12, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _formatGoal(displayGoal),
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF818CF8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: AppTheme.primaryIndigo,
                          inactiveTrackColor: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
                          thumbColor: AppTheme.primaryIndigo,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: displayGoal,
                          min: 5, max: 12, divisions: 14,
                          onChangeStart: (_) => setState(() => _isDraggingSlider = true),
                          onChanged: (v) {
                            setState(() => _sleepGoal = v);
                          },
                          onChangeEnd: (v) {
                            context.read<OnboardingProvider>().updateGoalDuration((v * 60).round());
                            setState(() => _isDraggingSlider = false);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('5h', style: TextStyle(fontSize: 11, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                          Text('12h', style: TextStyle(fontSize: 11, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          displayGoal >= 8
                              ? '✅ Excellent! 8+ hours supports full cognitive recovery.'
                              : displayGoal >= 7
                                  ? '👍 Good. Most adults need 7-9 hours for optimal health.'
                                  : '⚠️ Less than 7 hours may impact memory and mood.',
                          style: TextStyle(fontSize: 13, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Settings List ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings',
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
                    const SizedBox(height: 14),
                    ..._settings.map((s) => _settingItem(s.$1, s.$2, s.$3, isLight)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Sign Out ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated,
                        title: Text('Sign Out', style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
                        content: Text('Are you sure you want to sign out?', style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true), 
                            child: const Text('Sign Out', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await authProvider.signOut();
                        if (!context.mounted) return;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign out failed')));
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Text('Sign Out',
                          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Calculates the current day streak from consecutive days with a sleep session.
  int _calcStreak() {
    if (_sessions.isEmpty) return 0;

    // Unique dates (midnight-normalised), newest first
    final dates = _sessions
        .map((s) => DateTime(s.recordedAt.year, s.recordedAt.month, s.recordedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Streak is only active if there's a session today or yesterday
    if (dates.first != today && dates.first != yesterday) return 0;

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final expected = dates[i - 1].subtract(const Duration(days: 1));
      if (dates[i] == expected) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Widget _statBadge(String emoji, String value, String label, Color color, bool isLight) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
      ],
    );
  }

  Widget _settingItem(String emoji, String label, String sub, bool isLight) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label settings coming soon!'),
            backgroundColor: AppTheme.primaryIndigo,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: AppTheme.glassDecoration(opacity: 0.07, isLightMode: isLight),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 12, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatGoal(double h) {
    final hrs = h.floor();
    final mins = ((h - hrs) * 60).round();
    return mins > 0 ? '${hrs}h ${mins}m' : '${hrs}h';
  }
}
