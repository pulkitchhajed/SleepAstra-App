import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import 'setup_completed_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _micGranted = false;
  bool _checking = false;

  Future<void> _requestMic() async {
    setState(() => _checking = true);
    final granted = await AudioRecorder().hasPermission();
    setState(() {
      _micGranted = granted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final surface     = isLight ? AppTheme.surfaceLight       : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border      = isLight ? AppTheme.cardBorderLight    : AppTheme.cardBorder;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            _stepIndicator(13, 13, border),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('🎙️', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 24),
                    Text('Microphone Access',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                      'SnoreClinics needs your microphone to record and analyse sleep sounds. No raw audio is stored — only anonymised events.',
                      style: TextStyle(color: textSec, fontSize: 15, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    _permissionTile('🔒 Privacy', 'Raw audio is never stored on servers.',
                        surface: surface, textPrimary: textPrimary, textSec: textSec, border: border),
                    const SizedBox(height: 12),
                    _permissionTile('📱 Local Only', 'All processing happens on your device.',
                        surface: surface, textPrimary: textPrimary, textSec: textSec, border: border),
                    const SizedBox(height: 12),
                    _permissionTile('🔇 Opt Out', 'You can revoke permission anytime in Settings.',
                        surface: surface, textPrimary: textPrimary, textSec: textSec, border: border),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_micGranted)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _checking ? null : _requestMic,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _checking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Allow Microphone',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              )
            else
              Column(children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
                const SizedBox(height: 8),
                const Text('Permission granted!',
                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Let's Start!",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _finish,
              child: Text('Skip for now', style: TextStyle(color: textSec)),
            ),
          ]),
        ),
      ),
    );
  }

  void _finish() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupCompletedScreen()));
  }

  Widget _permissionTile(String title, String body,
      {required Color surface, required Color textPrimary,
       required Color textSec, required Color border}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Text(title.split(' ')[0], style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.split(' ').skip(1).join(' '),
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
            Text(body, style: TextStyle(color: textSec, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _stepIndicator(int current, int total, Color border) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 4, margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < current ? AppTheme.primaryIndigo : border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
