import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'modules/sleep_analysis/providers/sleep_analysis_provider.dart';
import 'modules/onboarding/providers/onboarding_provider.dart';
import 'modules/journal/providers/journal_provider.dart';
import 'modules/rewards/providers/rewards_provider.dart';
import 'modules/paywall/providers/subscription_provider.dart';
import 'modules/onboarding/screens/auth_screen.dart';
import 'modules/onboarding/screens/email_step_screen.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/firestore_service.dart';
import 'screens/main_nav_screen.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/animated_sleep_background.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env not found — developer must copy .env.example to .env and add their API key.
    // The app will run but AI features requiring GEMINI_API_KEY will be unavailable.
    debugPrint('[dotenv] WARNING: .env file not found. Copy .env.example to .env and add your GEMINI_API_KEY.');
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().init();
  
  // Request FCM permission and subscribe asynchronously so it doesn't block app launch
  FirebaseMessaging.instance.requestPermission().then((_) {
    return FirebaseMessaging.instance.subscribeToTopic('all_users');
  }).catchError((e) {
    debugPrint('FCM Init Error: $e');
  });
  
  runApp(const SnoreClinicsApp());
}

class SnoreClinicsApp extends StatelessWidget {
  const SnoreClinicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => SleepAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => RewardsProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _AppGate(),
    );
  }
}

/// Decides whether to show the onboarding flow or main app on cold launch.
class _AppGate extends StatefulWidget {
  const _AppGate();
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _ready = false;
  bool _authError = false;
  String? _lastUid = 'INITIAL_BOOT';
  int _lastSessionKey = -1;

  @override
  void initState() {
    super.initState();
    _waitForAuthAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    _syncSession(context, auth);
  }

  /// Waits for Firebase Auth to emit its first auth state event (restored or null),
  /// then loads the profile. This prevents a WelcomeScreen flash on cold start.
  Future<void> _waitForAuthAndLoad() async {
    try {
      await fba.FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _ready = true;
          _authError = true;
        });
      }
    }
  }

  void _syncSession(BuildContext context, AuthProvider auth) {
    if (_lastUid == auth.uid && _lastSessionKey == auth.sessionKey) return;
    _lastUid = auth.uid;
    _lastSessionKey = auth.sessionKey;

    // 1. INSTANT SYNCHRONOUS RESET:
    // Wipe all local memory immediately to prevent User A data
    // from being saved into User B's account during the loading window.
    context.read<OnboardingProvider>().reset();
    context.read<JournalProvider>().clear();
    context.read<SleepAnalysisProvider>().reset();
    context.read<RewardsProvider>().reset();

    // 2. TRIGGER ASYNC LOAD:
    Future.microtask(() async {
      if (!mounted) return;
      
      // Determine effective UID: Authenticated ID or Guest Device ID
      final effectiveUid = auth.uid ?? await FirestoreService.deviceUid;
      final email = auth.user?.email;
      
      if (!context.mounted) return;
      context.read<OnboardingProvider>().loadProfile(effectiveUid, userEmail: email);
      context.read<JournalProvider>().loadEntries(effectiveUid);
      context.read<SleepAnalysisProvider>().loadHistory(effectiveUid);
      context.read<RewardsProvider>().init(effectiveUid);
      context.read<SubscriptionProvider>().init(effectiveUid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final onboarding = context.watch<OnboardingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    
    // We wrap everything in MaterialApp HERE so we can force a hard reset
    // by changing the Key whenever the auth state changes.
    // This effectively wipes the Navigator stack and all local UI state.
    return MaterialApp(
      key: ValueKey('app_gate_${auth.uid}_${auth.sessionKey}'),
      title: 'SnoreClinics AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      onGenerateRoute: AppRouter.generateRoute,
      home: _buildHome(onboarding),
    );
  }

  Widget _buildHome(OnboardingProvider onboarding) {
    if (_authError) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Failed to connect to authentication service.', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _authError = false;
                    _ready = false;
                  });
                  _waitForAuthAndLoad();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready || !onboarding.isInitialized) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: AnimatedSleepBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
          ),
        ),
      );
    }

    final auth = context.read<AuthProvider>();
    // STATE 1: Not authenticated → show login screen
    if (!auth.isAuthenticated) return const AuthScreen();
    // STATE 2: Authenticated but profile incomplete → start onboarding
    if (!onboarding.isComplete) return const EmailStepScreen();
    // STATE 3: Authenticated + complete profile → main app
    return const MainNavScreen();
  }
}
