import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import 'sleep_goals_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _age = 25;
  String _gender = 'male';
  double _weight = 70;
  double _height = 170;

  @override
  void initState() {
    super.initState();
    final p = context.read<OnboardingProvider>().profile;
    _age = p.age;
    _gender = p.gender;
    _weight = p.weightKg;
    _height = p.heightCm;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg         = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final surface    = isLight ? AppTheme.surfaceLight       : AppTheme.surface;
    final textPrimary  = isLight ? AppTheme.textPrimaryLight  : AppTheme.textPrimary;
    final textSec      = isLight ? AppTheme.textSecondaryLight: AppTheme.textSecondary;
    final border       = isLight ? AppTheme.cardBorderLight   : AppTheme.cardBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Your Profile', style: TextStyle(color: textPrimary)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
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
              _stepIndicator(4, 13, border),
              const SizedBox(height: 24),
              Text('Tell us about yourself',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 8),
              Text('This helps us calculate your BMI and personalise analysis.',
                  style: TextStyle(color: textSec, fontSize: 15)),
              const SizedBox(height: 32),

              // Age
              _label('Age: $_age years', textPrimary),
              Slider(
                value: _age.toDouble(),
                min: 13, max: 90,
                divisions: 77,
                activeColor: AppTheme.primaryIndigo,
                inactiveColor: isLight ? AppTheme.primaryIndigo.withValues(alpha: 0.15) : AppTheme.primaryIndigo.withValues(alpha: 0.25),
                onChanged: (v) => setState(() => _age = v.round()),
              ),
              const SizedBox(height: 16),

              // Gender
              _label('Gender', textPrimary),
              const SizedBox(height: 8),
              Row(
                children: ['male', 'female', 'other'].map((g) {
                  final selected = _gender == g;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryIndigo.withValues(alpha: 0.15)
                              : surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppTheme.primaryIndigo : border,
                          ),
                        ),
                        child: Text(
                          g[0].toUpperCase() + g.substring(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? AppTheme.primaryIndigo : textSec,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Weight
              _label('Weight: ${_weight.toStringAsFixed(1)} kg', textPrimary),
              Slider(
                value: _weight,
                min: 30, max: 200,
                activeColor: AppTheme.accentTeal,
                inactiveColor: isLight ? AppTheme.accentTeal.withValues(alpha: 0.15) : AppTheme.accentTeal.withValues(alpha: 0.25),
                onChanged: (v) => setState(() => _weight = v),
              ),
              const SizedBox(height: 16),

              // Height
              _label('Height: ${_height.toStringAsFixed(0)} cm', textPrimary),
              Slider(
                value: _height,
                min: 100, max: 220,
                activeColor: AppTheme.accentTeal,
                inactiveColor: isLight ? AppTheme.accentTeal.withValues(alpha: 0.15) : AppTheme.accentTeal.withValues(alpha: 0.25),
                onChanged: (v) => setState(() => _height = v),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    final provider = context.read<OnboardingProvider>();
    provider.updateAge(_age);
    provider.updateGender(_gender);
    provider.updateWeight(_weight);
    provider.updateHeight(_height);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SleepGoalsScreen()));
  }

  Widget _label(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }

  Widget _stepIndicator(int current, int total, Color border) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.only(right: 6),
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
