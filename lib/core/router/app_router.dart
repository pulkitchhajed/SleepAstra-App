import 'package:flutter/material.dart';
import '../../screens/main_nav_screen.dart';
import '../../modules/sleep_analysis/screens/sleep_analysis_screen.dart';
import '../../modules/sleep_analysis/screens/sleep_report_screen.dart';
import '../../modules/sleep_analysis/screens/sleep_history_screen.dart';
import '../../modules/sleep_analysis/models/sleep_report.dart';
import '../../modules/sleep_analysis/screens/snore_clips_screen.dart';
import '../../modules/onboarding/screens/auth_screen.dart';
import '../../modules/journal/screens/evening_journal_screen.dart';
import '../../modules/journal/screens/morning_journal_screen.dart';
import '../../modules/journal/screens/journal_list_screen.dart';
import '../../modules/ai/screens/insights_screen.dart';
import '../../modules/ai/screens/nidra_chat_screen.dart';
import '../../modules/relaxation/screens/breathing_exercise_screen.dart';
import '../../modules/relaxation/screens/relaxation_screen.dart';
import '../../modules/settings/screens/settings_screen.dart';
import '../../modules/paywall/screens/paywall_screen.dart';
import '../../modules/paywall/screens/subscription_success_screen.dart';
import '../../modules/videos/screens/video_list_screen.dart';
import '../../modules/admin/screens/admin_dashboard_screen.dart';
import '../../screens/daily_sleep_goal_screen.dart';

class AppRouter {
  static const String home          = '/';
  static const String mainNav       = '/main';
  static const String onboarding    = '/onboarding';
  static const String sleepAnalysis = '/sleep-analysis';
  static const String sleepReport   = '/sleep-report';
  static const String sleepHistory  = '/sleep-history';
  static const String snoreClips    = '/snore-clips';
  static const String eveningJournal = '/journal/evening';
  static const String morningJournal = '/journal/morning';
  static const String journalList   = '/journal';
  static const String insights      = '/insights';
  static const String nidraChat     = '/nidra';
  static const String breathing     = '/breathing';
  static const String relaxation    = '/relaxation';
  static const String settings      = '/settings';
  // Videos & Admin
  static const String videoLibrary  = '/videos';
  static const String adminDashboard = '/admin';
  static const String welcome       = '/welcome';
  static const String dailySleepGoal = '/daily_sleep_goal';
  // Legacy routes kept for backward compatibility
  static const String paywall       = '/paywall';
  static const String subscriptionSuccess = '/subscription-success';

  static Route<dynamic> generateRoute(RouteSettings s) {
    switch (s.name) {
      case home:
        return _fadeRoute(const MainNavScreen(), s);
      case mainNav:
        final idx = s.arguments as int? ?? 0;
        return _fadeRoute(MainNavScreen(initialIndex: idx), s);
      case onboarding:
      case welcome:
        return _fadeRoute(const AuthScreen(), s);
      case sleepAnalysis:
        bool autoStart = false;
        TimeOfDay? alarmTime;
        final args = s.arguments;
        if (args is bool) {
          autoStart = args;
        } else if (args is Map<String, dynamic>) {
          autoStart = args['autoStart'] as bool? ?? false;
          alarmTime = args['alarmTime'] as TimeOfDay?;
        }
        return _slideRoute(SleepAnalysisScreen(autoStart: autoStart, initialAlarmTime: alarmTime), s);
      case sleepReport:
        final report = s.arguments as SleepReport?;
        if (report == null) return _fadeRoute(const MainNavScreen(), s);
        return _slideRoute(SleepReportScreen(report: report), s);
      case sleepHistory:
        return _slideRoute(const SleepHistoryScreen(), s);
      case snoreClips:
        final args = s.arguments as Map<String, dynamic>? ?? {};
        final clips = args['clips'] as List<SnoreAudioClip>? ?? [];
        final recordedAt = args['recordedAt'] as DateTime? ?? DateTime.now();
        return _slideRoute(SnoreClipsScreen(clips: clips, recordedAt: recordedAt), s);
      case eveningJournal:
        return _slideRoute(const EveningJournalScreen(), s);
      case morningJournal:
        return _slideRoute(const MorningJournalScreen(), s);
      case journalList:
        return _slideRoute(const JournalListScreen(), s);
      case insights:
        return _slideRoute(const InsightsScreen(), s);
      case nidraChat:
        return _slideRoute(const NidraChatScreen(), s);
      case breathing:
        return _slideRoute(const BreathingExerciseScreen(), s);
      case relaxation:
        return _slideRoute(const RelaxationScreen(), s);
      case settings:
        return _slideRoute(const SettingsScreen(), s);
      case videoLibrary:
        return _slideRoute(const VideoListScreen(), s);
      case adminDashboard:
        return _slideRoute(const AdminDashboardScreen(), s);
      case dailySleepGoal:
        return _slideRoute(const DailySleepGoalScreen(), s);
      case paywall:
        return _slideRoute(const PaywallScreen(), s);
      case subscriptionSuccess:
        return _fadeRoute(const SubscriptionSuccessScreen(), s);
      default:
        return _fadeRoute(const MainNavScreen(), s);
    }
  }

  static PageRouteBuilder _fadeRoute(Widget page, RouteSettings s) =>
      PageRouteBuilder(
        settings: s,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      );

  static PageRouteBuilder _slideRoute(Widget page, RouteSettings s) =>
      PageRouteBuilder(
        settings: s,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeInOutCubic))
              .animate(a),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 360),
      );
}
