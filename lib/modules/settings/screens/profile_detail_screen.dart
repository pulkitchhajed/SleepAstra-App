import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../onboarding/screens/setup_flow_screen.dart';

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<OnboardingProvider>().profile;
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg = isLight ? AppTheme.backgroundLight : const Color(0xFF0D0F1E);
    final textPrimary = isLight ? AppTheme.textPrimaryLight : Colors.white;
    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white70;
    final iconColor = isLight ? AppTheme.textSecondaryLight.withValues(alpha: 0.5) : Colors.white54;
    final dividerColor = isLight ? Colors.black12 : Colors.white10;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Profile', style: TextStyle(color: textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _buildProfileRow(Icons.height_rounded, 'Height', '${profile.heightCm} cm', iconColor, textSec, textPrimary),
            Divider(color: dividerColor, height: 1),
            _buildProfileRow(Icons.monitor_weight_rounded, 'Weight', '${profile.weightKg} kg', iconColor, textSec, textPrimary),
            Divider(color: dividerColor, height: 1),
            _buildProfileRow(Icons.calculate_rounded, 'BMI', profile.bmi.toStringAsFixed(1), iconColor, textSec, textPrimary),
            Divider(color: dividerColor, height: 1),
            _buildProfileRow(Icons.cake_rounded, 'Age', '${profile.age} years', iconColor, textSec, textPrimary),
            Divider(color: dividerColor, height: 1),
            _buildProfileRow(Icons.person_rounded, 'Gender', profile.gender.isNotEmpty ? profile.gender : 'Not Specified', iconColor, textSec, textPrimary),
            Divider(color: dividerColor, height: 1),
            _buildProfileRow(Icons.bedtime_rounded, 'Target Sleep', '${profile.targetDurationHours.toStringAsFixed(1)} hours', iconColor, textSec, textPrimary),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SetupFlowScreen())),
                icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryIndigo),
                label: const Text('Edit Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryIndigo)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryIndigo, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value, Color iconColor, Color textSec, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: textSec, fontSize: 16)),
          const Spacer(),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
