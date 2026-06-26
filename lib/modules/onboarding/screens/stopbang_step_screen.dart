import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/onboarding_provider.dart';
import 'summary_step_screen.dart';

class StopBangStepScreen extends StatefulWidget {
  const StopBangStepScreen({super.key});
  @override
  State<StopBangStepScreen> createState() => _StopBangStepScreenState();
}

class _StopBangStepScreenState extends State<StopBangStepScreen> {
  final Map<int, bool?> _answers = {};
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final _questions = [
    {'title': 'Snoring', 'desc': 'Do you snore loudly (louder than talking or loud enough to be heard through closed doors)?'},
    {'title': 'Tired', 'desc': 'Do you often feel tired, fatigued, or sleepy during daytime?'},
    {'title': 'Observed', 'desc': 'Has anyone observed you stop breathing during your sleep?'},
    {'title': 'Blood Pressure', 'desc': 'Do you have or are you being treated for high blood pressure?'},
    {'title': 'Neck Size', 'desc': 'Is your neck circumference greater than 40cm (16 inches)?'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() {
    final p = context.read<OnboardingProvider>().profile;
    final bool bmiRisk    = p.bmi > 35;
    final bool ageRisk    = p.age > 50;
    final bool genderRisk = p.gender.toLowerCase() == 'male';

    int score = 0;
    if (bmiRisk) score++;
    if (ageRisk) score++;
    if (genderRisk) score++;
    for (var v in _answers.values) {
      if (v == true) score++;
    }

    context.read<OnboardingProvider>().updateStopBangScore(score);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryStepScreen()));
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
          onPressed: () {
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepIndicator(_currentPage + 7, 13, border),
                  const SizedBox(height: 32),
                  Text('Know your Sleep Health',
                      style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
                  const SizedBox(height: 8),
                  Text('Takes less than a minute.',
                      style: TextStyle(color: textSec, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _questions.length,
                itemBuilder: (context, i) {
                  final q = _questions[i];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: border),
                            boxShadow: [
                              BoxShadow(
                                color: isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q['title']!,
                                  style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              Text(q['desc']!,
                                  style: TextStyle(color: textSec, fontSize: 15, height: 1.5)),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(child: _toggleBtn(i, true, 'Yes', border, textSec)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _toggleBtn(i, false, 'No', border, textSec)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _answers[_currentPage] != null ? _nextPage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    disabledBackgroundColor: surface,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: _answers[_currentPage] != null ? 4 : 0,
                  ),
                  child: Text(
                    _currentPage < _questions.length - 1 ? 'Next Question' : 'Analyze Profile',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _answers[_currentPage] != null ? Colors.white : textSec,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(int idx, bool val, String label, Color border, Color textSec) {
    final sel = _answers[idx] == val;
    return GestureDetector(
      onTap: () => setState(() => _answers[idx] = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primaryIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppTheme.primaryIndigo : border, width: 1.5),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color: sel ? Colors.white : textSec,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          )),
        ),
      ),
    );
  }

  Widget _stepIndicator(int current, int total, Color border) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 6, margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryIndigo : border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
