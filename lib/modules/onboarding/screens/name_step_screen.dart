import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import 'profile_setup_screen.dart';

class NameStepScreen extends StatefulWidget {
  const NameStepScreen({super.key});
  @override
  State<NameStepScreen> createState() => _NameStepScreenState();
}

class _NameStepScreenState extends State<NameStepScreen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = context.read<OnboardingProvider>().profile.name;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _next() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) {
      context.read<OnboardingProvider>().updateName(name);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepIndicator(3, 13, border),
              const SizedBox(height: 32),
              Text('What should we call you?',
                  style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 8),
              Text("Let's start with your name.",
                  style: TextStyle(color: textSec, fontSize: 16)),
              const SizedBox(height: 40),
              TextField(
                controller: _ctrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: TextStyle(color: textSec.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                autofocus: true,
                onSubmitted: (_) => _next(),
              ),
              Container(height: 2, color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
              const Spacer(),
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
              Center(
                child: Consumer<OnboardingProvider>(
                  builder: (context, onboarding, _) => Opacity(
                    opacity: 0.3,
                    child: Text(
                      'Session UID: ${onboarding.profile.email ?? "No Email Linked"}',
                      style: TextStyle(color: textSec, fontSize: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
