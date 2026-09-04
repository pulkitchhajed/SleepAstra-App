import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Colours (unchanged) ──────────────────────────────────────
  static const Color primaryIndigo    = Color(0xFF6366F1); // Electric Indigo
  static const Color primaryGold      = Color(0xFFFFB347); // Warm Gold
  static const Color accentTeal       = Color(0xFF34D399); // Emerald
  static const Color textPrimary      = Color(0xFFF0F0FF); // Ghost White
  static const Color textSecondary    = Color(0xFFA5B4FC); // Lavender
  static const Color success          = Color(0xFF34D399);
  static const Color error            = Color(0xFFF87171);

  // ── Aurora Cosmica Backgrounds (Dark Mode) ─────────────────────────
  static const Color background       = Color(0xFF040810); // True Space Black
  static const Color surface          = Color(0xFF07111F); // Deep Space
  static const Color surfaceElevated  = Color(0xCC07111F); // Deep Space 80%
  static const Color cardBorder       = Color(0x396366F1); // Indigo Glow Border ~22%
  static const Color cardBackground   = surfaceElevated;

  // ── Aurora Cosmica Backgrounds (Light Mode) ────────────────────────
  static const Color backgroundLight      = Color(0xFFF8F9FA); // Off-white
  static const Color surfaceLight         = Color(0xFFFFFFFF); // White
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color cardBorderLight      = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimaryLight     = Color(0xFF1E293B); // Slate 800
  static const Color textSecondaryLight   = Color(0xFF64748B); // Slate 500

  // ── Aurora Glassmorphism ───────────────────────────────────────────
  // Glowing borders + double shadow (close dark + far indigo glow)
  static BoxDecoration glassDecoration({
    double opacity = 0.45,
    BorderRadius? borderRadius,
    bool showBorder = true,
    bool isLightMode = false,
  }) {
    return BoxDecoration(
      color: isLightMode 
          ? surfaceLight.withValues(alpha: opacity * 1.5 > 1.0 ? 1.0 : opacity * 1.5) 
          : surface.withValues(alpha: opacity * 0.8),
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      border: showBorder
          ? Border.all(
              color: isLightMode ? cardBorderLight : primaryIndigo.withValues(alpha: 0.22), 
              width: 0.8)
          : null,
      boxShadow: [
        // Close sharp shadow
        BoxShadow(
          color: isLightMode ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.50),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        // Far diffuse glow
        BoxShadow(
          color: primaryIndigo.withValues(alpha: isLightMode ? 0.05 : 0.10),
          blurRadius: 40,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primaryIndigo,
        secondary: primaryGold,
        tertiary: accentTeal,
        surface: surface,
        error: error,
      ),
      // ── Typography: Unified Premium ─────────────────────────────────
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        TextTheme(
          displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
          displaySmall: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
          headlineLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimary,
            height: 1.6,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.6,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: primaryIndigo.withValues(alpha: 0.18), width: 0.8),
        ),
      ),
      // ── Buttons: Glow Shadow ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 8,
          shadowColor: primaryIndigo.withValues(alpha: 0.55),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      // ── AppBar: True Transparent ────────────────────────────────────
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryIndigo,
        secondary: primaryGold,
        tertiary: accentTeal,
        surface: surfaceLight,
        error: error,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        TextTheme(
          displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textPrimaryLight,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textPrimaryLight,
            letterSpacing: -0.3,
          ),
          displaySmall: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimaryLight,
            letterSpacing: -0.2,
          ),
          headlineLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          headlineMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimaryLight,
            height: 1.6,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textSecondaryLight,
            height: 1.6,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryLight,
            letterSpacing: 0.3,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorderLight, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
          shadowColor: primaryIndigo.withValues(alpha: 0.3),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimaryLight,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimaryLight),
      ),
    );
  }
}
