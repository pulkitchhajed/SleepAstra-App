import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/rewards_provider.dart';
import '../../../core/router/app_router.dart';
import 'package:intl/intl.dart';

class RewardsBalanceChip extends StatelessWidget {
  const RewardsBalanceChip({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final rewards = context.watch<RewardsProvider>();

    return GestureDetector(
      onTap: () {
        // Navigate to rewards tab (index 3)
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.mainNav,
          (route) => false,
          arguments: 3,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 6),
            // We can use a TweenAnimationBuilder for a nice count up effect later,
            // but simple text works fine for now.
            Text(
              NumberFormat('#,###').format(rewards.balance),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
