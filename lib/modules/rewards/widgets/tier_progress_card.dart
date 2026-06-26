import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reward_models.dart';
import '../../../core/theme/app_theme.dart';

class TierProgressCard extends StatelessWidget {
  final RewardsTier currentTier;
  final int lifetimePoints;
  final bool isLight;

  const TierProgressCard({
    super.key,
    required this.currentTier,
    required this.lifetimePoints,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final nextTier = currentTier.nextTier;
    
    // Gradient based on tier
    List<Color> gradientColors;
    switch (currentTier) {
      case RewardsTier.bronze:
        gradientColors = [const Color(0xFFCD7F32), const Color(0xFFA0522D)];
        break;
      case RewardsTier.silver:
        gradientColors = [const Color(0xFFC0C0C0), const Color(0xFF808080)];
        break;
      case RewardsTier.gold:
        gradientColors = [const Color(0xFFFFD700), const Color(0xFFDAA520)];
        break;
      case RewardsTier.platinum:
        gradientColors = [const Color(0xFFE5E4E2), const Color(0xFFB0C4DE)];
        break;
    }

    final textColor = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final secondaryTextColor = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.8) : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentTier.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${currentTier.label} Tier',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${currentTier.multiplier}x Earn Rate',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          if (nextTier != null) ...[
            const SizedBox(height: 16),
            _ProgressBar(
              currentPoints: lifetimePoints,
              threshold: currentTier.threshold,
              nextThreshold: nextTier.threshold,
              gradientColors: gradientColors,
            ),
            const SizedBox(height: 8),
            Text(
              '${nextTier.threshold - lifetimePoints} points to ${nextTier.label} Tier',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: secondaryTextColor,
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'You have reached the highest tier! 🎉',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int currentPoints;
  final int threshold;
  final int nextThreshold;
  final List<Color> gradientColors;

  const _ProgressBar({
    required this.currentPoints,
    required this.threshold,
    required this.nextThreshold,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final range = nextThreshold - threshold;
    final progress = (currentPoints - threshold).clamp(0, range);
    final percent = range > 0 ? progress / range : 1.0;

    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
