import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'modules/onboarding/screens/setup_flow_screen.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/firestore_service.dart';
import 'screens/main_nav_screen.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/animated_sleep_background.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? _getRouteFromMessage(RemoteMessage message) {
  final action = message.data['onTapAction'];
  if (action == null) return null;
  switch (action) {
    case 'Settings': return AppRouter.settings;
    case 'Sleep Analysis': return AppRouter.sleepAnalysis;
    case 'Sleep History': return AppRouter.sleepHistory;
    case 'Morning Journal': return AppRouter.morningJournal;
    case 'Evening Journal': return AppRouter.eveningJournal;
    case 'Insights': return AppRouter.insights;
    case 'Nidra Chat': return AppRouter.nidraChat;
    case 'Breathing': return AppRouter.breathing;
    case 'Relaxation': return AppRouter.relaxation;
    case 'Video Library': return AppRouter.videoLibrary;
    case 'Daily Sleep Goal': return AppRouter.dailySleepGoal;
    case 'App home': return AppRouter.mainNav;
    default: return AppRouter.mainNav;
  }
}

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
    // .env is gitignored (contains real API keys) and won't exist on a fresh clone.
    // Copy .env.example -> .env and add your GEMINI_API_KEY to enable AI features.
    // The app runs fine without it — AI-dependent features will gracefully degrade.
    debugPrint('[dotenv] .env not found — AI features require a local .env with GEMINI_API_KEY.');
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
  
  // Handle notification tap when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final route = _getRouteFromMessage(message);
    if (route != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed(route);
    }
  });

  // Handle notification tap when app is terminated
  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    final route = _getRouteFromMessage(initialMsg);
    if (route != null) {
      // Delay push to allow navigator to mount
      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed(route);
        }
      });
    }
  }
  
  runApp(const SleepAstraApp());
}

class SleepAstraApp extends StatelessWidget {
  const SleepAstraApp({super.key});

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
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Sleep Astra',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            onGenerateRoute: AppRouter.generateRoute,
            home: const _AppGate(),
          );
        },
      ),
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
  bool _hasSeenSplash = false;
  bool _splashComplete = false;
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
      final prefs = await SharedPreferences.getInstance();
      _hasSeenSplash = prefs.getBool('has_seen_splash') ?? false;
      if (_hasSeenSplash) {
        _splashComplete = true;
      }
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

  bool _isSyncing = false;

  void _syncSession(BuildContext context, AuthProvider auth) {
    if (_lastUid == auth.uid && _lastSessionKey == auth.sessionKey) return;
    _lastUid = auth.uid;
    _lastSessionKey = auth.sessionKey;

    _isSyncing = true;

    // 1. ASYNC RESET AND LOAD
    Future.microtask(() async {
      try {
        if (!mounted) return;
        
        // Wipe all local memory to prevent User A data
        // from being saved into User B's account during the loading window.
        context.read<OnboardingProvider>().reset();
        context.read<JournalProvider>().clear();
        context.read<SleepAnalysisProvider>().reset();
        context.read<RewardsProvider>().reset();

        // Determine effective UID: Authenticated ID or Guest Device ID
        final effectiveUid = auth.uid ?? await FirestoreService.deviceUid;
        final email = auth.user?.email;
        
        if (!context.mounted) return;
        await context.read<OnboardingProvider>().loadProfile(effectiveUid, userEmail: email);
        context.read<JournalProvider>().loadEntries(effectiveUid);
        context.read<SleepAnalysisProvider>().loadHistory(effectiveUid);
        context.read<RewardsProvider>().init(effectiveUid);
        context.read<SubscriptionProvider>().init(effectiveUid);
      } catch (e) {
        debugPrint("Error syncing session: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isSyncing = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final onboarding = context.watch<OnboardingProvider>();
    
    return _buildHome(auth, onboarding);
  }

  Widget _buildHome(AuthProvider auth, OnboardingProvider onboarding) {
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

    // Wait for Firebase Auth to resolve on cold start
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
        ),
      );
    }

    // STATE 1: Not authenticated → show login screen IMMEDIATELY.
    // This check MUST come before _isSyncing so that logout redirects
    // to AuthScreen right away instead of waiting for a guest profile load.
    if (!auth.isAuthenticated) return const AuthScreen();

    // Still loading the authenticated user's profile
    if (_isSyncing || !onboarding.isInitialized) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
        ),
      );
    }

    if (!_hasSeenSplash && !_splashComplete) {
      return SplashScreen(
        onFinish: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_seen_splash', true);
          if (mounted) {
            setState(() {
              _hasSeenSplash = true;
              _splashComplete = true;
            });
          }
        },
      );
    }

    // STATE 2: Authenticated but profile incomplete → start onboarding
    if (!onboarding.isComplete) return const SetupFlowScreen();
    // STATE 3: Authenticated + complete profile → main app
    return const MainNavScreen();
  }
}
