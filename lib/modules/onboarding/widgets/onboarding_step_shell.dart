import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable shell for every onboarding step screen.
/// Provides the SleepAstra dark background, back button, step counter,
/// animated progress bar, and a bottom Continue button.
class OnboardingStepShell extends StatefulWidget {
  final int currentStep;   // 1-indexed (e.g. 1 = first step)
  final int totalSteps;    // total number of setup steps (e.g. 8)
  final Widget child;      // the actual question content
  final String continueLabel;
  final bool continueEnabled;
  final VoidCallback? onContinue;
  final bool showBack;

  const OnboardingStepShell({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
    this.continueLabel = 'Continue',
    this.continueEnabled = true,
    this.onContinue,
    this.showBack = true,
  });

  @override
  State<OnboardingStepShell> createState() => _OnboardingStepShellState();
}

class _OnboardingStepShellState extends State<OnboardingStepShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: widget.currentStep / widget.totalSteps,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
    _progressCtrl.forward();
  }

  @override
  void didUpdateWidget(OnboardingStepShell old) {
    super.didUpdateWidget(old);
    if (old.currentStep != widget.currentStep) {
      _progressAnim = Tween<double>(
        begin: old.currentStep / widget.totalSteps,
        end: widget.currentStep / widget.totalSteps,
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
      _progressCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF080808),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    if (widget.showBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    Text(
                      '${widget.currentStep} / ${widget.totalSteps}',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Progress bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (_, __) => _SegmentedProgressBar(
                    total: widget.totalSteps,
                    progress: _progressAnim.value,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Content area ─────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: widget.child,
                ),
              ),

              // ── Continue button ───────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: AnimatedOpacity(
                  opacity: widget.continueEnabled ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          widget.continueEnabled ? widget.onContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5BDB),
                        disabledBackgroundColor: const Color(0xFF3B5BDB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.continueLabel,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Segmented progress bar ────────────────────────────────────────────────────

class _SegmentedProgressBar extends StatelessWidget {
  final int total;
  final double progress; // 0.0 to 1.0

  const _SegmentedProgressBar({required this.total, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final segmentProgress =
            ((progress * total) - i).clamp(0.0, 1.0);
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: segmentProgress,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3B5BDB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Helper widget: a large question label used on every setup step.
class OnboardingQuestion extends StatelessWidget {
  final String text;
  final String? subtitle;

  const OnboardingQuestion({super.key, required this.text, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white54,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
