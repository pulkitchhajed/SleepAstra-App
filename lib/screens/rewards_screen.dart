import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../core/router/app_router.dart';
import '../modules/rewards/providers/rewards_provider.dart';
import '../modules/rewards/models/reward_models.dart';
import '../modules/rewards/widgets/tier_progress_card.dart';
import '../modules/rewards/widgets/ledger_transaction_tile.dart';
import 'package:intl/intl.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSecondary = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final rewards = context.watch<RewardsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: rewards.refreshWallet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rewards',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Stay consistent, earn rewards',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.06, end: 0, curve: Curves.easeOut),
                        const Spacer(),
                        Container(
                          width: 48,
                          height: 48,
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
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    if (rewards.isLoading && rewards.wallet == null)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // ── Balance Card ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  NumberFormat('#,###').format(rewards.balance),
                                  style: GoogleFonts.outfit(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 36),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Tier Progress ────────────────────────────────────
                      TierProgressCard(
                        currentTier: rewards.currentTier,
                        lifetimePoints: rewards.wallet?.lifetimeEarned ?? 0,
                        isLight: isLight,
                      ),

                      const SizedBox(height: 32),

                      // ── Quick Actions ────────────────────────────────────
                      Text(
                        'Earn More',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _QuickAction(
                            icon: Icons.mic_rounded,
                            label: 'Record Sleep',
                            color: const Color(0xFF818CF8),
                            onTap: () => Navigator.pushNamed(context, AppRouter.sleepAnalysis),
                          ),
                          _QuickAction(
                            icon: Icons.book_rounded,
                            label: 'Journal',
                            color: const Color(0xFF34D399),
                            onTap: () => Navigator.pushNamed(context, AppRouter.eveningJournal),
                          ),
                          _QuickAction(
                            icon: Icons.self_improvement_rounded,
                            label: 'Meditate',
                            color: const Color(0xFFFBBF24),
                            onTap: () => Navigator.pushNamed(context, AppRouter.relaxation),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ── Earning Rules ────────────────────────────────────
                      Text(
                        'Ways to Earn',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (rewards.rules.isEmpty)
                        Text('No active rules', style: TextStyle(color: textSecondary))
                      else
                        ...rewards.rules.where((r) => r.isActive).map((r) => _EarnRuleRow(rule: r, isLight: isLight)),

                      const SizedBox(height: 32),

                      // ── Transaction History ──────────────────────────────
                      Text(
                        'History',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (rewards.ledger.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No transactions yet',
                              style: GoogleFonts.outfit(color: textSecondary),
                            ),
                          ),
                        )
                      else
                        ...rewards.ledger.map((e) => LedgerTransactionTile(entry: e, isLight: isLight)),
                    ],
                  ],
                ),
              ),
            ),
            
            // Earn Points Toast Animation
            if (rewards.lastEarnedPoints != null)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value < 0.8 ? value : (1.0 - (value - 0.8) * 5).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF34D399).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '+${rewards.lastEarnedPoints} points',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnRuleRow extends StatelessWidget {
  final EarningRule rule;
  final bool isLight;

  const _EarnRuleRow({required this.rule, required this.isLight});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final cardColor = isLight ? AppTheme.surfaceLight : AppTheme.surface;
    final borderColor = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(rule.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              rule.description,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${rule.basePoints}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryIndigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
