import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'app_theme.dart';

/// A helper class to resolve theme colors dynamically based on the current mode.
/// This eliminates the need to manually check `isLight` and select colors
/// in every screen.
class ThemeColors {
  final bool isLight;
  
  const ThemeColors(this.isLight);

  /// Creates a [ThemeColors] instance from the current [BuildContext].
  /// This automatically reads the [ThemeProvider].
  factory ThemeColors.of(BuildContext context) {
    // Read the provider (use watch so widgets rebuild on change)
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return ThemeColors(!isDark);
  }

  // ── Backgrounds & Surfaces ─────────────────────────────────────────

  Color get background => isLight ? AppTheme.backgroundLight : AppTheme.background;
  
  Color get surface => isLight ? AppTheme.surfaceLight : AppTheme.surface;
  
  Color get surfaceElevated => isLight ? AppTheme.surfaceElevatedLight : AppTheme.surfaceElevated;
  
  Color get cardBorder => isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

  // ── Text & Typography ──────────────────────────────────────────────

  Color get textPrimary => isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
  
  Color get textSecondary => isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
  
  // ── Helpers ────────────────────────────────────────────────────────

  /// Returns a decoration tailored to the current mode (light or dark).
  BoxDecoration glassDecoration({
    double opacity = 0.45,
    BorderRadius? borderRadius,
    bool showBorder = true,
  }) {
    return AppTheme.glassDecoration(
      opacity: opacity,
      borderRadius: borderRadius,
      showBorder: showBorder,
      isLightMode: isLight,
    );
  }
}
