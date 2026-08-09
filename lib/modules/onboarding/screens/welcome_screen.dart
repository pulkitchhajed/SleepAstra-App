import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'signup_step_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg         = isLight ? AppTheme.backgroundLight     : AppTheme.background;
    final textPrimary  = isLight ? AppTheme.textPrimaryLight  : AppTheme.textPrimary;
    final textSec      = isLight ? AppTheme.textSecondaryLight: AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Logo / Moon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryIndigo.withValues(alpha: 0.4),
                          AppTheme.primaryIndigo.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.6),
                          width: 1.5),
                    ),
                    child: const Center(
                        child: Text('🌙', style: TextStyle(fontSize: 56))),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 32),
                  Text(
                    'Sleep Astra',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryIndigo,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                  Text(
                    'Monitor your sleep, detect snoring & apnea risk, and get personalised AI-driven insights to sleep better.',
                    style: TextStyle(color: textSec, fontSize: 16, height: 1.5),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                  const Spacer(flex: 2),
                  // Features row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _featurePill('🎙️', 'Record', textSec).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                      _featurePill('🧠', 'AI Analysis', textSec).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                      _featurePill('📊', 'Insights', textSec).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                      _featurePill('💬', 'Nidra Chat', textSec).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupStepScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Get Started',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ).animate().fadeIn(delay: 650.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final auth = context.read<AuthProvider>();
                        await auth.signInWithGoogle(forceAccountPicker: false);
                      },
                      icon: Icon(Icons.login_rounded, size: 20, color: textPrimary),
                      label: Text('I already have an account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: AppTheme.primaryIndigo.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 750.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                  const SizedBox(height: 32),
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) => Opacity(
                      opacity: 0.3,
                      child: Text(
                        'ID: ${auth.uid?.substring(0, 8) ?? "Guest"} | ${auth.user?.email ?? "No Email"}',
                        style: TextStyle(color: textSec, fontSize: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
      );
  }

  Widget _featurePill(String emoji, String label, Color textSec) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: textSec, fontSize: 11)),
      ],
    );
  }
}
