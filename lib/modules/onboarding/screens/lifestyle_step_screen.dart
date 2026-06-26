import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import 'stopbang_step_screen.dart';

class LifestyleStepScreen extends StatefulWidget {
  const LifestyleStepScreen({super.key});
  @override
  State<LifestyleStepScreen> createState() => _LifestyleStepScreenState();
}

class _LifestyleStepScreenState extends State<LifestyleStepScreen> {
  int _caffeineCups = 2;
  int _alcoholDays = 1;
  int _exerciseDays = 3;

  void _next() {
    final p = context.read<OnboardingProvider>();
    p.updateCaffeineCups(_caffeineCups);
    p.updateAlcoholDays(_alcoholDays);
    p.updateExerciseDays(_exerciseDays);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StopBangStepScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final surface     = isLight ? AppTheme.surfaceLight       : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border      = isLight ? AppTheme.cardBorderLight    : AppTheme.cardBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textSec),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepIndicator(6, 13, border),
              const SizedBox(height: 32),
              Text('Your Lifestyle',
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 8),
              Text('Daily habits strongly influence your sleep architecture.',
                  style: TextStyle(color: textSec, fontSize: 16)),
              const SizedBox(height: 40),

              _sliderSection(
                emoji: '☕', title: 'Caffeine Intake', subtitle: 'Cups per day',
                value: _caffeineCups.toDouble(), max: 10, divisions: 10,
                label: '$_caffeineCups cups',
                onChanged: (v) => setState(() => _caffeineCups = v.toInt()),
                color: const Color(0xFFD97706),
                surface: surface, textPrimary: textPrimary, textSec: textSec, border: border,
              ),
              const SizedBox(height: 32),

              _sliderSection(
                emoji: '🍷', title: 'Alcohol Consumption', subtitle: 'Days per week',
                value: _alcoholDays.toDouble(), max: 7, divisions: 7,
                label: '$_alcoholDays days',
                onChanged: (v) => setState(() => _alcoholDays = v.toInt()),
                color: const Color(0xFF9333EA),
                surface: surface, textPrimary: textPrimary, textSec: textSec, border: border,
              ),
              const SizedBox(height: 32),

              _sliderSection(
                emoji: '🏃', title: 'Exercise Frequency', subtitle: 'Days per week',
                value: _exerciseDays.toDouble(), max: 7, divisions: 7,
                label: '$_exerciseDays days',
                onChanged: (v) => setState(() => _exerciseDays = v.toInt()),
                color: AppTheme.accentTeal,
                surface: surface, textPrimary: textPrimary, textSec: textSec, border: border,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sliderSection({
    required String emoji, required String title, required String subtitle,
    required double value, required double max, required int divisions,
    required String label, required ValueChanged<double> onChanged,
    required Color color, required Color surface,
    required Color textPrimary, required Color textSec, required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(color: textSec, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.1),
              valueIndicatorColor: color,
            ),
            child: Slider(value: value, min: 0, max: max, divisions: divisions, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator(int current, int total, Color border) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            height: 4, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryIndigo : border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
