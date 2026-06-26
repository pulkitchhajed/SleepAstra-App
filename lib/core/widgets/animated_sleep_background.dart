import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-screen animated background with two layers:
/// 1. Starfield  — 60 tiny stars that twinkle independently (dark mode only)
/// 2. Aurora     — 3 slow-drifting bezier light bands
/// Light mode: clean off-white gradient background instead
class AnimatedSleepBackground extends StatefulWidget {
  final Widget? child;
  final bool isLightMode;
  const AnimatedSleepBackground({super.key, this.child, this.isLightMode = false});

  @override
  State<AnimatedSleepBackground> createState() => _AnimatedSleepBackgroundState();
}

class _AnimatedSleepBackgroundState extends State<AnimatedSleepBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLightMode) {
      // Light mode: clean gradient background
      return Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8F9FF), // very slight blue tint at top
                  Color(0xFFF8F9FA), // off-white at bottom
                ],
              ),
            ),
          ),
          if (widget.child != null) Positioned.fill(child: widget.child!),
        ],
      );
    }

    return Stack(
      children: [
        // Base space-black plain color
        Container(color: AppTheme.background),
        // Child content on top
        if (widget.child != null) Positioned.fill(child: widget.child!),
      ],
    );
  }
}

