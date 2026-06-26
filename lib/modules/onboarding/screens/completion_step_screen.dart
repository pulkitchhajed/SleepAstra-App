import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../../screens/main_nav_screen.dart';

class CompletionStepScreen extends StatelessWidget {
  const CompletionStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded, size: 64, color: AppTheme.accentTeal),
                ),
              ),
              const SizedBox(height: 32),
              Text("You're all set!",
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 16),
              Text(
                'Your SnoreClinics profile is ready. Start tracking tonight to get deeper insights into your sleep health.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSec, fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.read<OnboardingProvider>().completeOnboarding();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavScreen()),
                        (r) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Enter SnoreClinics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
