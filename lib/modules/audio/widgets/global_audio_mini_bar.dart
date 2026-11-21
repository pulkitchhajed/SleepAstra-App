import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/audio_player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/audio_player_sheet.dart';

/// Persistent mini-player bar shown above the bottom nav on every tab.
/// Visible whenever [AudioPlayerProvider.activeTrack] is non-null.
class GlobalAudioMiniBar extends StatelessWidget {
  const GlobalAudioMiniBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AudioPlayerProvider>();
    if (ap.activeTrack == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => AudioPlayerSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryIndigo,
              ap.isPlaying ? const Color(0xFF4F46E5) : AppTheme.primaryIndigo,
            ],
          ),
          boxShadow: ap.isPlaying
              ? [
                  BoxShadow(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ap.activeTrack!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ap.isPlaying ? 'Now Playing' : 'Paused',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Play/Pause
            if (ap.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  ap.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 34,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => context.read<AudioPlayerProvider>().togglePlayPause(),
              ),
            const SizedBox(width: 4),

            // Close
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => context.read<AudioPlayerProvider>().stop(),
            ),
          ],
        ),
      ),
    );
  }
}
