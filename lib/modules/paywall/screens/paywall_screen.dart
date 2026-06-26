import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/subscription_plan.dart';
import '../providers/subscription_provider.dart';
import '../widgets/plan_card_widget.dart';
import '../widgets/feature_comparison_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  SubscriptionPlan _selectedPlan = Plans.annual;

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        // Handle payment processing state
        if (provider.paymentState == PaymentState.processing) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryIndigo),
                  SizedBox(height: 24),
                  Text('Processing Payment...'),
                ],
              ),
            ),
          );
        }

        // Handle success state
        if (provider.paymentState == PaymentState.success) {
          // Reset state and navigate to success screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.resetPaymentState();
            Navigator.pushReplacementNamed(
              context,
              AppRouter.subscriptionSuccess,
            );
          });
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, provider),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroImage(context),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Unlock Deep Sleep',
                        style: Theme.of(context).textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Start your 7-day free trial today. Get full access to AI insights, sleep stages, and apnea risk detection.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      if (provider.errorMessage != null) ...[
                        _buildErrorMessage(provider.errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      _buildPlanSelectionRow(provider),
                      const SizedBox(height: 24),
                      _buildSubscribeButton(provider),
                      const SizedBox(height: 16),
                      Text(
                        'Recurring billing. Cancel anytime.',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 40),
                      const FeatureComparisonWidget(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, SubscriptionProvider provider) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight.withValues(alpha: 0.6) : AppTheme.surfaceElevated.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await provider.restorePurchase();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Purchases restored')),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Restore'),
        ),
      ],
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight
              ? [
                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                  AppTheme.backgroundLight,
                ]
              : [
                  const Color(0xFF2E245E),
                  AppTheme.background,
                ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glow
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: isLight ? 0.2 : 0.4),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
          // Icon
          Icon(
            Icons.bedroom_parent_rounded,
            size: 96,
            color: isLight ? AppTheme.primaryIndigo : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelectionRow(SubscriptionProvider provider) {
    return Column(
      children: [
        PlanCardWidget(
          plan: Plans.annual,
          isSelected: _selectedPlan == Plans.annual,
          isCurrentPlan: provider.currentTier == PlanTier.annual,
          onTap: () => setState(() => _selectedPlan = Plans.annual),
        ),
        const SizedBox(height: 16),
        PlanCardWidget(
          plan: Plans.monthly,
          isSelected: _selectedPlan == Plans.monthly,
          isCurrentPlan: provider.currentTier == PlanTier.monthly,
          onTap: () => setState(() => _selectedPlan = Plans.monthly),
        ),
      ],
    );
  }

  Widget _buildSubscribeButton(SubscriptionProvider provider) {
    final isCurrentPlan = provider.currentTier == _selectedPlan.tier;

    return ElevatedButton(
      onPressed: isCurrentPlan
          ? null
          : () {
              provider.startPurchase(
                plan: _selectedPlan,
                userEmail: 'test@example.com', // Demo user
                userPhone: '9876543210',
              );
            },
      child: Text(isCurrentPlan ? 'Current Plan' : 'Start 7-Day Free Trial'),
    );
  }
}
