import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SubscriptionSuccessScreen extends StatefulWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  State<SubscriptionSuccessScreen> createState() =>
      _SubscriptionSuccessScreenState();
}

class _SubscriptionSuccessScreenState extends State<SubscriptionSuccessScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildGlowIcon(),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to Premium!',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You now have full access to deep sleep analysis, unlimited history, and personalised AI insights.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  _buildFeatureList(context),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRouter.home,
                      (r) => false,
                    ),
                    child: const Text('Start Exploring'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // blast downwards
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            colors: const [
              AppTheme.primaryIndigo,
              AppTheme.primaryGold,
              AppTheme.accentTeal,
              Colors.white,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlowIcon() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.verified_rounded,
          size: 72,
          color: AppTheme.primaryGold,
        ),
      ),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlocked Features',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          const _FeatureItem(icon: Icons.auto_graph_rounded, text: 'Detailed Snoring Amplitude Charts'),
          const SizedBox(height: 12),
          const _FeatureItem(icon: Icons.psychology_rounded, text: 'Personalised AI Sleep Insights'),
          const SizedBox(height: 12),
          const _FeatureItem(icon: Icons.history_rounded, text: 'Unlimited Tracking History'),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.success, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
