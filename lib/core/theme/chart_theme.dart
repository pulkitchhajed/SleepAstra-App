import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'app_theme.dart';

class ChartTheme {
  /// Unified grid lines with dashed styling
  static FlGridData gridData(bool isLight, {double? horizontalInterval}) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: horizontalInterval,
      getDrawingHorizontalLine: (value) => FlLine(
        color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  /// Unified hidden border
  static FlBorderData get borderData => FlBorderData(show: false);
  
  /// Unified typography for axis labels
  static TextStyle getAxisTextStyle(bool isLight, {bool isHighlight = false}) {
    return TextStyle(
      color: isHighlight 
          ? AppTheme.primaryIndigo 
          : (isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.5)),
      fontSize: 10,
      fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
    );
  }

  /// Unified background track for bar charts
  static BackgroundBarChartRodData backgroundBar(bool isLight, double maxY) {
    return BackgroundBarChartRodData(
      show: true,
      toY: maxY,
      color: isLight ? Colors.grey.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
    );
  }

  /// Shared tooltip styling
  static LineTouchData lineTouchData(bool isLight) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => isLight ? AppTheme.surfaceLight.withValues(alpha: 0.9) : const Color(0xFF1A1D33).withValues(alpha: 0.9),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              spot.y.toStringAsFixed(1),
              TextStyle(color: isLight ? AppTheme.textPrimaryLight : Colors.white, fontWeight: FontWeight.bold),
            );
          }).toList();
        },
      ),
    );
  }
}
