import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/rewards_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';

class RewardsRedemptionWidget extends StatefulWidget {
  final double cartTotal;
  final Function(int points, double value) onApply;

  const RewardsRedemptionWidget({
    super.key,
    required this.cartTotal,
    required this.onApply,
  });

  @override
  State<RewardsRedemptionWidget> createState() => _RewardsRedemptionWidgetState();
}

class _RewardsRedemptionWidgetState extends State<RewardsRedemptionWidget> {
  int _sliderValue = 0;

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final rewards = context.watch<RewardsProvider>();

    if (rewards.balance < rewards.config.minRedemptionPoints) {
      return const SizedBox.shrink(); // Hide if not enough points
    }

    final maxPointsAllowedByPercent = rewards.config.rupeesToPoints(widget.cartTotal * rewards.config.maxRedemptionPercent);
    final maxRedeemable = rewards.balance.clamp(0, maxPointsAllowedByPercent);
    
    if (maxRedeemable == 0) return const SizedBox.shrink();

    final valueInRupees = rewards.config.pointsToRupees(_sliderValue);
    
    final textColor = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppTheme.cardBackground,
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
              const Icon(Icons.stars_rounded, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Text(
                'Redeem Points',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '-₹${valueInRupees.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryIndigo,
              inactiveTrackColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
              thumbColor: AppTheme.primaryIndigo,
            ),
            child: Slider(
              value: _sliderValue.toDouble(),
              min: 0,
              max: maxRedeemable.toDouble(),
              divisions: maxRedeemable > 0 ? maxRedeemable : 1,
              onChanged: (val) {
                setState(() => _sliderValue = val.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: GoogleFonts.outfit(color: textColor)),
              Text('$maxRedeemable pts', style: GoogleFonts.outfit(color: textColor)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _sliderValue > 0 ? () => widget.onApply(_sliderValue, valueInRupees) : null,
              child: const Text('Apply Discount'),
            ),
          ),
        ],
      ),
    );
  }
}
