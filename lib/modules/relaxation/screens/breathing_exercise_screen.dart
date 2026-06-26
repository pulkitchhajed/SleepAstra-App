import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});
  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

enum BreathState { ready, inhale, hold, exhale }

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  BreathState _currentState = BreathState.ready;
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startExercise() {
    setState(() {
      _isActive = true;
    });
    _runCycle();
  }

  void _stopExercise() {
    _timer?.cancel();
    _controller.stop();
    setState(() {
      _isActive = false;
      _currentState = BreathState.ready;
      _secondsLeft = 0;
    });
  }

  void _runCycle() async {
    if (!_isActive) return;

    // Inhale (4s)
    setState(() {
      _currentState = BreathState.inhale;
      _secondsLeft = 4;
    });
    _controller.duration = const Duration(seconds: 4);
    _controller.forward();
    await _startCountdown(4);
    if (!_isActive) return;

    // Hold (7s)
    setState(() {
      _currentState = BreathState.hold;
      _secondsLeft = 7;
    });
    await _startCountdown(7);
    if (!_isActive) return;

    // Exhale (8s)
    setState(() {
      _currentState = BreathState.exhale;
      _secondsLeft = 8;
    });
    _controller.duration = const Duration(seconds: 8);
    _controller.reverse();
    await _startCountdown(8);
    if (!_isActive) return;

    // Loop
    _runCycle();
  }

  Future<void> _startCountdown(int seconds) async {
    for (int i = seconds; i > 0; i--) {
      if (!_isActive) break;
      setState(() => _secondsLeft = i);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0A0C16);
    
    String instruction = 'Ready to relax?';
    String timeLabel = '';
    Color circleColor = AppTheme.primaryIndigo;

    if (_currentState == BreathState.inhale) {
      instruction = 'Inhale';
      circleColor = AppTheme.accentTeal;
      timeLabel = '$_secondsLeft';
    } else if (_currentState == BreathState.hold) {
      instruction = 'Hold';
      circleColor = AppTheme.primaryGold;
      timeLabel = '$_secondsLeft';
    } else if (_currentState == BreathState.exhale) {
      instruction = 'Exhale';
      circleColor = const Color(0xFF8B5CF6);
      timeLabel = '$_secondsLeft';
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('4-7-8 Breathing', style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isActive ? _scaleAnimation.value : 1.0,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: circleColor.withValues(alpha: 0.2),
                          border: Border.all(color: circleColor.withValues(alpha: 0.5), width: 2),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleColor.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(color: circleColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    timeLabel,
                    style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Text(
              instruction,
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600, color: textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'A natural tranquilizer for the nervous system.',
              style: TextStyle(color: textPrimary.withValues(alpha: 0.6), fontSize: 16),
            ),
            const SizedBox(height: 60),
            GestureDetector(
              onTap: _isActive ? _stopExercise : _startExercise,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: _isActive ? AppTheme.error.withValues(alpha: 0.2) : AppTheme.primaryIndigo,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _isActive ? AppTheme.error : Colors.transparent),
                ),
                child: Text(
                  _isActive ? 'Stop' : 'Start',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isActive ? AppTheme.error : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
