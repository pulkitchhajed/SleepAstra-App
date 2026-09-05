import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/onboarding_provider.dart';
import '../utils/circadian_utils.dart';
import 'setup_flow_screen.dart'; // fallback if edit needed

class SetupCompletedScreen extends StatefulWidget {
  const SetupCompletedScreen({super.key});

  @override
  State<SetupCompletedScreen> createState() => _SetupCompletedScreenState();
}

class _SetupCompletedScreenState extends State<SetupCompletedScreen> {
  int _subStep = 1;

  void _handleNext() {
    if (_subStep < 3) {
      setState(() => _subStep++);
    } else {
      // Go to main app (assuming main.dart manages this via AppGate)
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  void _handlePrev() {
    if (_subStep > 1) {
      setState(() => _subStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<OnboardingProvider>().profile;
    
    // Calculate synthesis text
    final firstName = profile.name.trim().isNotEmpty ? profile.name.trim().split(' ')[0] : 'friend';
    final hasAirwayFlags = profile.stopAnswers['snoring'] == true || profile.stopAnswers['observed'] == true;
    final hasFatigue = profile.stopAnswers['tiredness'] == true;
    final hasBP = profile.stopAnswers['pressure'] == true;

    String circadianP = '';
    if (profile.dailySleepDebtHours > 0) {
      circadianP = 'Your current routine provides ${CircadianUtils.formatDurationHours(profile.currentDurationHours)} of rest, generating a daily sleep debt of ${profile.sleepDebtHours} hours (${profile.weeklySleepDebtHours}h weekly deficit) relative to your ${CircadianUtils.formatDurationHours(profile.targetDurationHours)} target. To eliminate this deficit without circadian phase shock, SleepAstra recommends stepping your schedule to ${profile.recommendedBedtime} – ${profile.recommendedWakeTime} (${CircadianUtils.formatDurationHours(profile.recommendedDurationHours)}).';
    } else {
      circadianP = 'Your current ${CircadianUtils.formatDurationHours(profile.currentDurationHours)} schedule is in balanced alignment with your ${CircadianUtils.formatDurationHours(profile.targetDurationHours)} sleep target, allowing 4–5 restorative 90-minute ultradian sleep cycles anchored between ${profile.recommendedBedtime} and ${profile.recommendedWakeTime}.';
    }

    String clinicalP = '';
    if (hasAirwayFlags && hasFatigue) {
      clinicalP = 'Screening highlights mild airway resistance patterns (snoring/observed pauses) paired with daytime tiredness. SleepAstra will monitor nocturnal acoustic stability and suggest gentle head-of-bed elevation alongside light therapy timing.';
    } else if (hasFatigue) {
      clinicalP = 'Daytime fatigue was identified during screening. Your recovery algorithms will focus on balancing adenosine accumulation during wakefulness and optimizing cortisol clearance before your ${profile.recommendedBedtime} wind-down.';
    } else if (hasBP) {
      clinicalP = 'Given your cardiovascular profile, the engine emphasizes consistent nocturnal heart rate dipping and deeper parasympathetic nervous system tone throughout the night.';
    } else {
      clinicalP = 'Your screening baseline is clear. The protocol concentrates on fine-tuning your focus targets: ${profile.primarySleepGoals.join(', ').toLowerCase()}.';
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07111F),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _subStep == 1
                        ? _buildSlide1(firstName, circadianP, clinicalP)
                        : _subStep == 2
                            ? _buildSlide2(profile)
                            : _buildSlide3(profile),
                  ),
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _subStep > 1
                  ? IconButton(
                      onPressed: _handlePrev,
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(8),
                      ),
                    )
                  : const SizedBox(width: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Summary $_subStep / 3',
                  style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              final step = index + 1;
              final isActive = _subStep >= step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _subStep == step
                        ? const Color(0xFF3B5BDB)
                        : isActive
                            ? const Color(0xFF3B5BDB).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B5BDB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: const Color(0xFF3B5BDB).withValues(alpha: 0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _subStep == 3 ? 'Start Optimization Engine' : 'Next',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (_subStep < 3) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- Slide 1: AI Synthesis ---
  Widget _buildSlide1(String firstName, String circadianP, String clinicalP) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B5BDB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF60A5FA), size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'Circadian Profile Analysis',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            circadianP,
            style: GoogleFonts.inter(fontSize: 15, color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            clinicalP,
            style: GoogleFonts.inter(fontSize: 15, color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Slide 2: Circadian Schedule ---
  Widget _buildSlide2(dynamic profile) {
    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Optimized Schedule',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            'TARGET WINDOW',
            '${CircadianUtils.formatDurationHours(profile.recommendedDurationHours)} / night',
            Icons.schedule,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'BEDTIME',
                  CircadianUtils.formatTime12H(profile.recommendedBedtime),
                  Icons.nights_stay_rounded,
                  const Color(0xFF3B5BDB),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'WAKE UP',
                  CircadianUtils.formatTime12H(profile.recommendedWakeTime),
                  Icons.wb_sunny_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('SLEEP DEBT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${profile.sleepDebtHours > 0 ? profile.sleepDebtHours : "None"}', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('HOURS DAILY', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: profile.sleepDebtHours > 1 ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: profile.sleepDebtHours > 1 ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    profile.sleepDebtHours > 1 ? 'High Debt' : 'Optimal',
                    style: GoogleFonts.inter(color: profile.sleepDebtHours > 1 ? const Color(0xFFF87171) : const Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Slide 3: Focus Profile ---
  Widget _buildSlide3(dynamic profile) {
    return SingleChildScrollView(
      key: const ValueKey(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Focus Profile',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text('PRIMARY GOALS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 12),
          ...profile.primarySleepGoals.map<Widget>((goal) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF3B5BDB), size: 20),
                    const SizedBox(width: 12),
                    Text(goal, style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              )).toList(),
          const SizedBox(height: 32),
          Text('PHYSIOLOGICAL FLAGS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'BMI CATEGORY',
                  profile.bmiCategory,
                  Icons.accessibility_new_rounded,
                  profile.bmiCategory == 'Optimal' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'AIRWAY RISK',
                  (profile.stopAnswers['snoring'] == true || profile.stopAnswers['observed'] == true) ? 'Elevated' : 'Low',
                  Icons.air_rounded,
                  (profile.stopAnswers['snoring'] == true || profile.stopAnswers['observed'] == true) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
