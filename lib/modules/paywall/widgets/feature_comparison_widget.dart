import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/subscription_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';

/// Full feature comparison table: Trial vs Premium columns.
class FeatureComparisonWidget extends StatelessWidget {
  const FeatureComparisonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final cardBg = isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated;
    final cardBorder = isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          _buildTableHeader(context, isLight, cardBorder),
          Divider(height: 1, color: cardBorder),
          ...Plans.features.asMap().entries.map((entry) {
            final isLast = entry.key == Plans.features.length - 1;
            return Column(
              children: [
                _buildFeatureRow(context, entry.value, isLight, cardBorder),
                if (!isLast) Divider(height: 1, color: cardBorder),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, bool isLight, Color cardBorder) {
    final textS = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Feature',
              style: TextStyle(
                color: textS,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Trial',
                style: TextStyle(
                  color: textS,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppTheme.primaryIndigo, Color(0xFF8B83FF)],
                ).createShader(rect),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, PlanFeature feature, bool isLight, Color cardBorder) {
    final textP = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature.name,
              style: TextStyle(
                color: textP,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _CheckIcon(included: feature.includedInFree, isLight: isLight),
            ),
          ),
          Expanded(
            child: Center(
              child: _CheckIcon(
                included: feature.includedInPremium,
                premiumStyle: true,
                isLight: isLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  final bool included;
  final bool premiumStyle;
  final bool isLight;

  const _CheckIcon({
    required this.included,
    this.premiumStyle = false,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    if (included) {
      return Icon(
        Icons.check_circle_rounded,
        color: premiumStyle ? AppTheme.primaryIndigo : AppTheme.success,
        size: 18,
      );
    }
    return Icon(
      Icons.remove_circle_outline_rounded,
      color: isLight ? AppTheme.cardBorderLight : AppTheme.cardBorder,
      size: 18,
    );
  }
}
