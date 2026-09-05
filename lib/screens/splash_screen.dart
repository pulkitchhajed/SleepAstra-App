import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;

  // Glow
  late final Animation<double> _glowOpacity;
  // Logo — scale + fade only (no slide, so it stays perfectly centered)
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  // Pulse on the glow after it appears
  late final Animation<double> _glowPulse;
  // Tagline
  late final Animation<double> _taglineOpacity;
  // Skip hint
  late final Animation<double> _skipOpacity;

  @override
  void initState() {
    super.initState();

    // Auto-advance after 3.8 seconds
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) widget.onFinish();
    });

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 0–40%: glow fades in
    _glowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // 20–65%: logo fades + scales from 0.82 → 1.0 (always centered)
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.65, curve: Curves.easeOutBack),
      ),
    );

    // Glow slow pulse after appearing
    _glowPulse = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // 65–100%: tagline fades in
    _taglineOpacity = Tween<double>(begin: 0, end: 0.85).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    // 88–100%: skip hint fades in
    _skipOpacity = Tween<double>(begin: 0, end: 0.4).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.88, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final bgColor =
        isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC);
    final taglineColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final skipColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final glowColors = isDark
        ? [
            const Color(0xFF6366F1).withValues(alpha: 0.50),
            const Color(0xFF3872E0).withValues(alpha: 0.28),
            const Color(0xFF2DD4BF).withValues(alpha: 0.10),
            Colors.transparent,
          ]
        : [
            const Color(0xFF6366F1).withValues(alpha: 0.30),
            const Color(0xFF38BDF8).withValues(alpha: 0.18),
            Colors.transparent,
            Colors.transparent,
          ];
    const glowStops = [0.0, 0.40, 0.68, 1.0];

    return GestureDetector(
      onTap: widget.onFinish,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // ── Center cluster (glow + logo, always perfectly centered) ──
            AnimatedBuilder(
              animation: Listenable.merge([
                _glowOpacity,
                _glowPulse,
                _logoOpacity,
                _logoScale,
              ]),
              builder: (context, _) {
                return Center(
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow — same center as logo, scales outward equally
                        Opacity(
                          opacity: _glowOpacity.value,
                          child: Transform.scale(
                            scale: _glowPulse.value,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: glowColors,
                                  stops: glowStops,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Logo — scale + fade, NO slide, always dead-center
                        Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: isDark ? 0.40 : 0.22),
                                    blurRadius: 36,
                                    spreadRadius: 6,
                                    offset: Offset.zero,
                                  ),
                                ],
                              ),
                              child: Transform.translate(
                                offset: const Offset(12, 0), // Shift right to visually center
                                child: ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    1.4, 0, 0, 0, 15, // Red +40% + 15
                                    0, 1.4, 0, 0, 15, // Green +40% + 15
                                    0, 0, 1.4, 0, 15, // Blue +40% + 15
                                    0, 0, 0, 1, 0,    // Alpha
                                  ]),
                                  child: Image.asset(
                                    'assets/images/SleepAstra_logo_transparent.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Tagline — below center cluster ──
            Positioned(
              bottom: null,
              top: null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 320), // pushes below the 280 glow circle
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Sleep better. Live clearer.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.6,
                        color: taglineColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Skip hint ──
            Positioned(
              bottom: 28,
              child: FadeTransition(
                opacity: _skipOpacity,
                child: Text(
                  'Tap to skip',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: skipColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
