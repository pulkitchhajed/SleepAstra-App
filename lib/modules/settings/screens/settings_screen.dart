import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../onboarding/screens/profile_setup_screen.dart';
import '../../../core/services/firestore_service.dart';
import 'debug_logs_screen.dart';
import 'profile_detail_screen.dart';

import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showVersionInfo(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Sleep Astra',
      applicationVersion: '1.12.0',
      applicationIcon: const Text('🌙', style: TextStyle(fontSize: 40)),
      children: [
        const Text('Designed and developed by the Sleep Astra Team.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final profile = provider.profile;

    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Profile card
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileDetailScreen())),
            child: _profileCard(context, profile.name, profile.age),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 28),

          _sectionHeader('Account'),
          _tile(context,
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileSetupScreen())),
          ),
          _tile(context,
            icon: Icons.logout_rounded,
            label: 'Log Out',
            iconColor: AppTheme.error,
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 24),

          _sectionHeader('Notifications'),
          _switchTile(context,
            icon: Icons.notifications_outlined,
            label: 'Bedtime Reminder',
            subtitle: 'Alert at ${profile.bedtime}',
            value: profile.bedtimeReminderEnabled,
            onChanged: (v) => provider.updateBedtimeReminder(v),
          ),
          _switchTile(context,
            icon: Icons.wb_sunny_outlined,
            label: 'Morning Prompt',
            subtitle: 'Prompt to log morning journal',
            value: profile.morningPromptEnabled,
            onChanged: (v) => provider.updateMorningPrompt(v),
          ),

          const SizedBox(height: 24),

          _sectionHeader('Privacy & Data'),
          _tile(context,
            icon: Icons.delete_outline_rounded,
            label: 'Clear All Sleep Data',
            iconColor: AppTheme.error,
            onTap: () => _confirmClear(context),
          ),
          _tile(context,
            icon: Icons.info_outline_rounded,
            label: 'Privacy Policy',
            onTap: () => _launchUrl('https://snoreclinics.com/privacy'),
          ),
          const SizedBox(height: 24),

          _sectionHeader('About'),
          _tile(context,
            icon: Icons.star_outline_rounded,
            label: 'Rate Sleep Astra',
            onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.snoreclinics.app'),
          ),
          _tile(context,
            icon: Icons.code_rounded,
            label: 'Version 1.12.0',
            onTap: () => _showVersionInfo(context),
          ),
          _tile(context,
            icon: Icons.bug_report_outlined,
            label: 'View Debug Logs',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugLogsScreen())),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _profileCard(BuildContext context, String name, int age) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryIndigo.withValues(alpha: 0.3),
            AppTheme.primaryIndigo.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.3),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '😴',
            style: TextStyle(fontSize: 28, color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Text(name.isEmpty ? 'SnoreClinics User' : name,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('v1.12', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Age $age',
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 13)),
        ]),
      ]),
    );
  }

  Widget _sectionHeader(String title) => Builder(builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2)),
      ));

  Widget _tile(BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryIndigo).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.primaryIndigo, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded, color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)
          : null,
      onTap: onTap,
    );
  }

  Widget _switchTile(BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryIndigo, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primaryIndigo,
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        return AlertDialog(
        backgroundColor: isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Data',
            style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
        content: Text(
            'This will permanently delete all sleep sessions, journals, and your profile. Are you sure?',
            style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final uid = auth.uid ?? await FirestoreService.deviceUid;
              if (!context.mounted) return;
              await context.read<OnboardingProvider>().clearProfile(uid);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      );
      },
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        return AlertDialog(
        backgroundColor: isLight ? AppTheme.surfaceLight : AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out',
            style: TextStyle(color: isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary)),
        content: Text(
            'Are you sure you want to sign out? Your data will remain safely in the cloud.',
            style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              context.read<OnboardingProvider>().reset();
              await context.read<AuthProvider>().signOut();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Log Out',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      );
      },
    );
  }
}
