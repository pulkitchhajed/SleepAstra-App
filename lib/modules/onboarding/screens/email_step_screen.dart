import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import 'name_step_screen.dart';

class EmailStepScreen extends StatefulWidget {
  const EmailStepScreen({super.key});
  @override
  State<EmailStepScreen> createState() => _EmailStepScreenState();
}

class _EmailStepScreenState extends State<EmailStepScreen> {
  late TextEditingController _ctrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final email = context.read<OnboardingProvider>().profile.email ?? '';
    _ctrl = TextEditingController(text: email);
    _isEditing = email.isEmpty;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _next() {
    final email = _ctrl.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      context.read<OnboardingProvider>().updateEmail(email);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NameStepScreen()));
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

    final provider = context.watch<OnboardingProvider>();
    final capturedEmail = provider.profile.email ?? '';

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
              _stepIndicator(2, 13, border),
              const SizedBox(height: 32),
              Text('Confirm your email',
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 8),
              Text('This is your Master Key for data recovery across all devices.',
                  style: TextStyle(color: textSec, fontSize: 16)),
              const SizedBox(height: 48),

              Container(
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
                        const Text('📧', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text('Primary Email',
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                        const Spacer(),
                        if (!_isEditing)
                          GestureDetector(
                            onTap: () => setState(() => _isEditing = true),
                            child: const Text('Edit',
                                style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing)
                      TextField(
                        controller: _ctrl,
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          hintStyle: TextStyle(color: textSec.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                      )
                    else
                      Text(
                        capturedEmail.isEmpty ? 'Not captured yet' : capturedEmail,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: capturedEmail.isEmpty ? Colors.red : textPrimary,
                        ),
                      ),
                  ],
                ),
              ),

              if (capturedEmail.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Successfully linked to your ${provider.authProviderLabel} account',
                      style: const TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],

              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: capturedEmail.isEmpty && !_isEditing ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Confirm & Continue',
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
