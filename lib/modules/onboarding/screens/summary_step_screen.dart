import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../ai/services/gemini_service.dart';
import 'permissions_screen.dart';

class SummaryStepScreen extends StatefulWidget {
  const SummaryStepScreen({super.key});
  @override
  State<SummaryStepScreen> createState() => _SummaryStepScreenState();
}

class _SummaryStepScreenState extends State<SummaryStepScreen> {
  bool _loading = true;
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final p = context.read<OnboardingProvider>().profile;
    final gemini = GeminiService();
    final res = await gemini.analyzeProfile(p);
    if (mounted) {
      setState(() {
        _analysis = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

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
        child: _loading
          ? _buildLoading(isLight)
          : _buildResult(context, isLight),
      ),
    );
  }

  Widget _buildLoading(bool isLight) {
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryIndigo),
          const SizedBox(height: 24),
          Text('Nidra is analyzing your profile...',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 8),
          Text('Generating your personalized sleep blueprint',
              style: TextStyle(color: textSec, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, bool isLight) {
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border      = isLight ? AppTheme.cardBorderLight    : AppTheme.cardBorder;

    final risk = _analysis?['riskLevel'] ?? 'Low';
    final riskColor = risk == 'High' ? AppTheme.error : (risk == 'Medium' ? AppTheme.primaryGold : AppTheme.accentTeal);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIndicator(12, 13, border),
          const SizedBox(height: 32),
          Text('Your Sleep Blueprint',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
          const SizedBox(height: 8),
          Text('Based on your clinical and lifestyle data.',
              style: TextStyle(color: textSec, fontSize: 16)),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: isLight ? 0.06 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/nidra.png', width: 24, height: 24,
                        errorBuilder: (_,__,___) => const Icon(Icons.auto_awesome, color: AppTheme.primaryIndigo)),
                    const SizedBox(width: 8),
                    const Text('Nidra AI Analysis',
                        style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_analysis?['summary'] ?? '',
                    style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.monitor_heart, color: riskColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            children: [
                              const TextSpan(text: 'Sleep Apnea Risk: '),
                              TextSpan(text: risk, style: TextStyle(color: riskColor, fontWeight: FontWeight.w700)),
                            ]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_analysis?['recommendation'] ?? '',
                          style: TextStyle(color: textSec, fontSize: 14, height: 1.4)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen())),
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
