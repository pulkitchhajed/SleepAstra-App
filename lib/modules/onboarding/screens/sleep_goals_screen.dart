import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import 'lifestyle_step_screen.dart';

class SleepGoalsScreen extends StatefulWidget {
  const SleepGoalsScreen({super.key});
  @override
  State<SleepGoalsScreen> createState() => _SleepGoalsScreenState();
}

class _SleepGoalsScreenState extends State<SleepGoalsScreen> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 30);
  int _goalHours = 8;

  @override
  void initState() {
    super.initState();
    final p = context.read<OnboardingProvider>().profile;

    final bedParts = p.bedtime.split(':');
    if (bedParts.length == 2) {
      _bedtime = TimeOfDay(hour: int.tryParse(bedParts[0]) ?? 22, minute: int.tryParse(bedParts[1]) ?? 30);
    }
    final wakeParts = p.wakeTime.split(':');
    if (wakeParts.length == 2) {
      _wakeTime = TimeOfDay(hour: int.tryParse(wakeParts[0]) ?? 6, minute: int.tryParse(wakeParts[1]) ?? 30);
    }
    _goalHours = (p.goalDurationMinutes / 60).round().clamp(4, 12);
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime(bool isBed) async {
    final initial = isBed ? _bedtime : _wakeTime;
    final isLight = context.read<ThemeProvider>().isDarkMode == false;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: isLight
              ? ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppTheme.primaryIndigo,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
                  timePickerTheme: TimePickerThemeData(
                    dialBackgroundColor: Colors.grey.shade100,
                  ),
                )
              : ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppTheme.primaryIndigo,
                    surface: AppTheme.surface,
                  ),
                ),
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(0.85)),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBed) {
          _bedtime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
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
        title: Text('Sleep Goals', style: TextStyle(color: textPrimary)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepIndicator(5, 13, border),
              const SizedBox(height: 24),
              Text('Set your sleep goals',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 8),
              Text("We'll notify you at the right time and track your progress.",
                  style: TextStyle(color: textSec, fontSize: 15)),
              const SizedBox(height: 40),

              _timeTile('🌙 Bedtime', _fmt(_bedtime), () => _pickTime(true),
                  surface: surface, textPrimary: textPrimary, border: border),
              const SizedBox(height: 16),
              _timeTile('☀️ Wake Time', _fmt(_wakeTime), () => _pickTime(false),
                  surface: surface, textPrimary: textPrimary, border: border),
              const SizedBox(height: 32),

              Text('Sleep Duration Goal: $_goalHours hours',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              Slider(
                value: _goalHours.toDouble(),
                min: 4, max: 12,
                divisions: 8,
                label: '$_goalHours h',
                activeColor: AppTheme.primaryGold,
                inactiveColor: isLight ? AppTheme.primaryGold.withValues(alpha: 0.15) : AppTheme.primaryGold.withValues(alpha: 0.25),
                onChanged: (v) => setState(() => _goalHours = v.round()),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: isLight ? 0.07 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Adults typically need 7–9 hours. Aim for consistency.',
                        style: TextStyle(color: textSec, fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    final p = context.read<OnboardingProvider>();
    p.updateBedtime(_fmt(_bedtime));
    p.updateWakeTime(_fmt(_wakeTime));
    p.updateGoalDuration(_goalHours * 60);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LifestyleStepScreen()));
  }

  Widget _timeTile(String label, String value, VoidCallback onTap,
      {required Color surface, required Color textPrimary, required Color border}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            Text(value, style: const TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator(int current, int total, Color border) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 4, margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < current ? AppTheme.primaryIndigo : border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
