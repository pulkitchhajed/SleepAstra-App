import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reward_models.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class LedgerTransactionTile extends StatelessWidget {
  final LedgerEntry entry;
  final bool isLight;

  const LedgerTransactionTile({
    super.key,
    required this.entry,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final isEarn = entry.isEarning;
    final color = isEarn ? const Color(0xFF34D399) : const Color(0xFFFB7185);
    final icon = isEarn ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded;
    
    final textColor = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final secondaryTextColor = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.8) : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, h:mm a').format(entry.createdAt),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isEarn ? '+' : ''}${entry.points}',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
