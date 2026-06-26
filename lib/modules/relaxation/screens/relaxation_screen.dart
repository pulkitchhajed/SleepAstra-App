import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../sleep_analysis/providers/sleep_analysis_provider.dart';
import '../../sleep_analysis/models/sleep_report.dart';

class RelaxationScreen extends StatefulWidget {
  const RelaxationScreen({super.key});
  @override
  State<RelaxationScreen> createState() => _RelaxationScreenState();
}

class _RelaxationScreenState extends State<RelaxationScreen> with TickerProviderStateMixin {
  final int _targetCycles = 5;
  int _cycles = 0;
  int _phaseIdx = 0;
  bool _running = false;
  bool _done = false;

  late int _countdown;
  late final List<_Particle> _particles;
  late final AnimationController _ringCtrl;
  late final AnimationController _orbitCtrl;

  static const _phases = [
    _Phase('Inhale', 4, 1.45, Color(0xFF6366F1), 'Breathe in slowly through your nose'),
    _Phase('Hold',   4, 1.45, Color(0xFF3B82F6), 'Hold gently, stay relaxed'),
    _Phase('Exhale', 4, 1.0,  AppTheme.accentTeal, 'Breathe out slowly through your mouth'),
  ];

  @override
  void initState() {
    super.initState();
    _countdown = _phases[0].duration;

    final rng = Random();
    _particles = List.generate(18, (i) => _Particle(
      x: 0.1 + rng.nextDouble() * 0.8,
      delay: rng.nextDouble() * 8,
      dur: 6 + rng.nextDouble() * 8,
      size: 3 + rng.nextDouble() * 5,
      op: 0.2 + rng.nextDouble() * 0.5,
    ));

    _ringCtrl = AnimationController(vsync: this);
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      setState(() => _running = false);
      _ringCtrl.stop();
    } else {
      setState(() => _running = true);
      _runPhase();
    }
  }

  Future<void> _runPhase() async {
    while (_running && mounted) {
      final p = _phases[_phaseIdx];
      
      // Animate ring
      _ringCtrl.duration = Duration(seconds: p.duration);
      if (_phaseIdx == 0) {
        _ringCtrl.forward(from: 0);
      } else if (_phaseIdx == 2) {
        _ringCtrl.reverse(from: 1);
      }

      // Tick seconds
      for (int i = p.duration; i > 0; i--) {
        if (!_running || !mounted) return;
        setState(() => _countdown = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!_running || !mounted) return;

      // Next phase
      setState(() {
        _phaseIdx = (_phaseIdx + 1) % _phases.length;
        _countdown = _phases[_phaseIdx].duration;
        if (_phaseIdx == 0) {
          _cycles++;
          if (_cycles >= _targetCycles) {
            _running = false;
            _done = true;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDone(context);

    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final particleColor = isLight ? AppTheme.primaryIndigo.withValues(alpha: 0.08) : Colors.white;
    final phase = _phases[_phaseIdx];

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Particles
          ..._particles.map((p) => _ParticleWidget(p, particleColor)),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSec),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Builder(
                        builder: (context) {
                          final history = context.watch<SleepAnalysisProvider>().history;
                          final streak = _calcStreak(history);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.25)),
                            ),
                            child: Row(children: [
                              const Text('🔥'), const SizedBox(width: 6),
                              Text('$streak Day', style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w700, fontSize: 13)),
                            ]),
                          );
                        }
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Text('Cycle ${_cycles + 1} of $_targetCycles',
                    style: TextStyle(color: textSec, fontSize: 13)),
                const SizedBox(height: 40),

                // Ring
                SizedBox(
                  width: 280, height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) {
                          final scale = _running ? 1.0 + (_ringCtrl.value * 0.45) : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 200, height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _running ? phase.color : AppTheme.primaryIndigo.withValues(alpha: 0.4), width: 2),
                                boxShadow: _running ? [
                                  BoxShadow(color: phase.color.withValues(alpha: 0.6), blurRadius: 60),
                                  BoxShadow(color: phase.color.withValues(alpha: 0.3), blurRadius: 120),
                                ] : [BoxShadow(color: AppTheme.primaryIndigo.withValues(alpha: 0.3), blurRadius: 20)],
                              ),
                              child: Center(
                                child: Container(
                                  width: 140, height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [phase.color.withValues(alpha: 0.25), Colors.transparent],
                                      stops: const [0.0, 0.7],
                                    ),
                                  ),
                                  child: Center(
                                    child: Text('$_countdown',
                                        style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900,
                                            color: _running ? phase.color : AppTheme.primaryIndigo)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_running)
                        ...List.generate(4, (i) => AnimatedBuilder(
                          animation: _orbitCtrl,
                          builder: (_, __) {
                            final angle = (_orbitCtrl.value * 2 * pi) + (i * pi / 2);
                            final radius = 100.0 * (1.0 + (_ringCtrl.value * 0.45));
                            return Transform.translate(
                              offset: Offset(cos(angle) * radius, sin(angle) * radius),
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: phase.color),
                              ),
                            );
                          },
                        )),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Phase text
                Text(phase.label,
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: phase.color)),
                const SizedBox(height: 8),
                Text(phase.sub, style: TextStyle(color: textSec, fontSize: 14)),

                const SizedBox(height: 32),

                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_phases.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _phaseIdx ? 32 : 12, height: 4,
                    decoration: BoxDecoration(
                      color: i == _phaseIdx ? phase.color : textSec.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),

                const Spacer(),

                // Toggle Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(_running ? '⏸  Pause' : _cycles == 0 ? '🫁  Start Breathing' : '▶  Resume',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final textSec = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Scaffold(
    backgroundColor: bg,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text('Session Complete!', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.accentTeal)),
            const SizedBox(height: 10),
            Text('You completed $_targetCycles breathing cycles.\nYour body is ready for deep sleep.',
                textAlign: TextAlign.center, style: TextStyle(color: textSec, fontSize: 16, height: 1.5)),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final history = context.read<SleepAnalysisProvider>().history;
                final streak = _calcStreak(history);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text('$streak Day Streak Maintained!', style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(color: AppTheme.primaryIndigo, borderRadius: BorderRadius.circular(16)),
                child: const Text('Return Home 🏠', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  int _calcStreak(List<SleepReport> sessions) {
    if (sessions.isEmpty) return 0;

    final dates = sessions
        .map((s) => DateTime(s.recordedAt.year, s.recordedAt.month, s.recordedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (dates.first != today && dates.first != yesterday) return 0;

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final expected = dates[i - 1].subtract(const Duration(days: 1));
      if (dates[i] == expected) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

class _Phase {
  final String label, sub;
  final int duration;
  final double scale;
  final Color color;
  const _Phase(this.label, this.duration, this.scale, this.color, this.sub);
}

class _Particle {
  final double x, delay, dur, size, op;
  const _Particle({required this.x, required this.delay, required this.dur, required this.size, required this.op});
}

class _ParticleWidget extends StatefulWidget {
  final _Particle p;
  final Color color;
  const _ParticleWidget(this.p, this.color);
  @override
  State<_ParticleWidget> createState() => _ParticleWidgetState();
}

class _ParticleWidgetState extends State<_ParticleWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.p.dur * 1000).toInt()));
    _anim = Tween(begin: 1.0, end: -0.2).animate(_ctrl);
    Future.delayed(Duration(milliseconds: (widget.p.delay * 1000).toInt()), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        left: widget.p.x * size.width,
        top: _anim.value * size.height,
        child: Container(
          width: widget.p.size, height: widget.p.size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: widget.p.op)),
        ),
      ),
    );
  }
}
