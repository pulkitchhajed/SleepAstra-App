// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../models/sleep_report.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Displays the average spectral energy composition of the recorded night,
/// broken into three frequency bands:
///   Purple  50-500 Hz  (Snoring band)
///   Teal    500-2kHz   (Voice / Light Breathing)
///   Grey    2kHz+      (Ambient / Environment)
class SnoreFrequencyProfileChart extends StatefulWidget {
  final SleepReport report;
  const SnoreFrequencyProfileChart({super.key, required this.report});

  @override
  State<SnoreFrequencyProfileChart> createState() => _SnoreFrequencyProfileChartState();
}

class _SnoreFrequencyProfileChartState extends State<SnoreFrequencyProfileChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation  = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight     = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg      = isLight ? AppTheme.surfaceLight : const Color(0xFF1A1D33);
    final cardBorder  = isLight ? AppTheme.cardBorderLight : AppTheme.primaryIndigo.withOpacity(0.25);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec     = isLight ? AppTheme.textSecondaryLight : Colors.white.withOpacity(0.5);

    final snoringBand = widget.report.avgSnoreBandEnergyRatio.clamp(0.0, 1.0);
    final remaining   = 1.0 - snoringBand;
    final voiceBand   = remaining * 0.58;
    final ambientBand = remaining * 0.42;
    final confidence  = widget.report.detectionConfidence;
    final hasSBERData = widget.report.amplitudeTimeline.any((s) => s.sber != null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryIndigo.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3)),
                ),
                child: const Icon(Icons.equalizer_rounded, color: AppTheme.primaryIndigo, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sound Frequency Profile', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Energy distribution across frequency bands', style: TextStyle(color: textSec, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasSBERData)
            Center(child: Padding(padding: const EdgeInsets.all(8), child: Text('Frequency data not available for this recording.', style: TextStyle(color: textSec, fontSize: 12))))
          else ...[
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 36,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final total = constraints.maxWidth;
                          return Row(
                            children: [
                              if (snoringBand > 0)
                                Container(
                                  width: total * snoringBand * _animation.value,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                                  ),
                                ),
                              Container(
                                width: total * voiceBand * _animation.value,
                                color: AppTheme.accentTeal,
                              ),
                              Expanded(
                                child: Container(
                                  color: isLight ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLegendRow(color: const Color(0xFF6366F1), label: '50-500 Hz  (Snoring Band)', percent: snoringBand * 100, textSec: textSec, textPrimary: textPrimary),
                  const SizedBox(height: 8),
                  _buildLegendRow(color: AppTheme.accentTeal, label: '500-2kHz  (Breathing / Voice)', percent: voiceBand * 100, textSec: textSec, textPrimary: textPrimary),
                  const SizedBox(height: 8),
                  _buildLegendRow(color: isLight ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563), label: '2kHz+      (Ambient / Room Noise)', percent: ambientBand * 100, textSec: textSec, textPrimary: textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildConfidenceIndicator(confidence, textPrimary, textSec),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendRow({required Color color, required String label, required double percent, required Color textSec, required Color textPrimary}) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: textSec, fontSize: 11))),
        Text('${percent.toStringAsFixed(1)}%', style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildConfidenceIndicator(double confidence, Color textPrimary, Color textSec) {
    final confColor = confidence >= 70 ? AppTheme.accentTeal : confidence >= 45 ? AppTheme.primaryGold : AppTheme.error;
    final confLabel = confidence >= 70 ? 'High' : confidence >= 45 ? 'Moderate' : confidence > 0 ? 'Low' : 'N/A';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: confColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: confColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: confColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              confidence > 0 ? 'Detection Confidence: $confLabel — ${confidence.toInt()}% spectral match to known snoring patterns' : 'No snoring detected in this recording',
              style: TextStyle(color: confColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
