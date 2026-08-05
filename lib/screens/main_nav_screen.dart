import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../modules/ai/screens/nidra_chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/rewards_screen.dart';
import '../screens/wellness_screen.dart';
import '../core/widgets/animated_sleep_background.dart';
import '../core/router/app_router.dart';
import '../modules/sleep_analysis/screens/sleep_history_screen.dart';
import '../modules/sleep_analysis/screens/sleep_analysis_screen.dart';
import '../modules/sleep_analysis/providers/sleep_analysis_provider.dart';

class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _currentIndex;
  late AnimationController _fabPulse;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _fabPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fabScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _fabPulse, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRedirectIfRecording();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRedirectIfRecording();
    }
  }

  Future<void> _checkAndRedirectIfRecording() async {
    if (!mounted) return;
    final sleepProv = context.read<SleepAnalysisProvider>();
    final isRecordingActive = await sleepProv.checkAndRestoreActiveRecordingState();

    if (isRecordingActive && !SleepAnalysisScreen.isScreenVisible && mounted) {
      Navigator.pushNamed(
        context,
        AppRouter.sleepAnalysis,
        arguments: {
          'autoStart': false,
          'isRestoringSession': true,
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabPulse.dispose();
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    WellnessScreen(),
    SleepHistoryScreen(),
    NidraChatScreen(),
    RewardsScreen(),
  ];

  final List<_NavItem> _items = const [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItem(Icons.spa_rounded, Icons.spa_outlined, 'Wellness'),
    _NavItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline, 'Nidra'),
    _NavItem(Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Rewards'),
  ];

  void _openReports() {
    if (context.read<SleepAnalysisProvider>().isRecording) {
      Navigator.pushNamed(
        context,
        AppRouter.sleepAnalysis,
        arguments: {'autoStart': false, 'isRestoringSession': true},
      );
      return;
    }
    setState(() => _currentIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Scaffold(
            backgroundColor: bg,
            extendBody: true,
            body: AnimatedSleepBackground(
              isLightMode: isLight,
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
              child: _buildNav(isLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNav(bool isLight) {
    final navBg = isLight 
        ? Colors.white.withValues(alpha: 0.85) 
        : AppTheme.background.withValues(alpha: 0.85);
    final borderColor = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;
    final shadowColor = isLight 
        ? Colors.black.withValues(alpha: 0.1) 
        : Colors.black.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      height: 74,
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.primaryIndigo.withValues(alpha: isLight ? 0.05 : 0.1),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, -2), // Top glow
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: _blurFilter(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left 2 tabs: Home, Wellness
              _buildNavItem(0, 0, isLight),
              _buildNavItem(1, 1, isLight),

              // ── Central My Sleep Button (Always Highlighted) ──
              GestureDetector(
                onTap: _openReports,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.45),
                              blurRadius: 14,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bedtime_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'My Sleep',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryIndigo,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right 2 tabs: Nidra, Rewards
              _buildNavItem(3, 2, isLight),
              _buildNavItem(4, 3, isLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int screenIndex, int itemIndex, bool isLight) {
    final item = _items[itemIndex];
    final selected = _currentIndex == screenIndex;
    final unselectedColor = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = screenIndex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? AppTheme.primaryIndigo : unselectedColor,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primaryIndigo : unselectedColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 12 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryIndigo.withValues(alpha: 0.5), blurRadius: 4)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ui.ImageFilter _blurFilter() {
    return ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}
