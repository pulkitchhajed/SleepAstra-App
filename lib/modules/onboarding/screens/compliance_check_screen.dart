import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';

class ComplianceCheckScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  
  const ComplianceCheckScreen({super.key, required this.onAccepted});

  @override
  State<ComplianceCheckScreen> createState() => _ComplianceCheckScreenState();
}

class _ComplianceCheckScreenState extends State<ComplianceCheckScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final surface     = isLight ? AppTheme.surfaceLight       : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border      = isLight ? AppTheme.cardBorderLight    : AppTheme.cardBorder;

    final canProceed = _termsAccepted && _privacyAccepted;

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
              const SizedBox(height: 12),
              Text('Legal & Privacy',
                  style: GoogleFonts.playfairDisplay(fontSize: 34, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 12),
              Text('To use Sleep Astra, you must review and accept our core policies.',
                  style: GoogleFonts.plusJakartaSans(color: textSec, fontSize: 16)),
              const SizedBox(height: 48),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    _buildCheckboxRow(
                      value: _termsAccepted,
                      title: 'Terms of Service',
                      subtitle: 'I agree to the Terms of Service.',
                      onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                      textPrimary: textPrimary,
                      textSec: textSec,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppTheme.cardBorder),
                    ),
                    _buildCheckboxRow(
                      value: _privacyAccepted,
                      title: 'Privacy Policy',
                      subtitle: 'I acknowledge the Privacy Policy and how my data is handled.',
                      onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
                      textPrimary: textPrimary,
                      textSec: textSec,
                    ),
                  ],
                ),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: canProceed ? widget.onAccepted : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed ? AppTheme.primaryIndigo : AppTheme.primaryIndigo.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    elevation: canProceed ? 4 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Accept & Continue',
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool?> onChanged,
    required Color textPrimary,
    required Color textSec,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryIndigo,
            side: BorderSide(color: AppTheme.cardBorder, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.plusJakartaSans(color: textSec, fontSize: 14)),
            ],
          ),
        )
      ],
    );
  }
}
