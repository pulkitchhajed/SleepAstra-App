import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/audio_player_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Full-screen bottom sheet player opened when a track is tapped.
class AudioPlayerSheet extends StatelessWidget {
  const AudioPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AudioPlayerSheet(),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AudioPlayerProvider>();
    final track = ap.activeTrack;
    if (track == null) {
      Navigator.of(context).pop();
      return const SizedBox.shrink();
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? AppTheme.backgroundLight : AppTheme.background;
    final textPrimary = isLight ? AppTheme.textPrimaryLight : AppTheme.textPrimary;
    final textSecondary = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;

    final totalSecs = ap.total.inSeconds.toDouble().clamp(1.0, double.infinity);
    final posSecs = ap.position.inSeconds.toDouble().clamp(0.0, totalSecs);

    final idx = ap.playlist.indexWhere((t) => t.id == track.id);
    final playlistLength = ap.playlist.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Artwork
            Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 72),
            ),
            const SizedBox(height: 28),

            // Title & description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    track.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  if (track.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      track.description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  ],
                  if (playlistLength > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${idx + 1} / $playlistLength',
                      style: TextStyle(fontSize: 12, color: textSecondary.withValues(alpha: 0.7)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Progress slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: AppTheme.primaryIndigo,
                      inactiveTrackColor: AppTheme.primaryIndigo.withValues(alpha: 0.2),
                      thumbColor: AppTheme.primaryIndigo,
                      overlayColor: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: posSecs,
                      min: 0,
                      max: totalSecs,
                      onChanged: (v) => context.read<AudioPlayerProvider>().seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(ap.position), style: TextStyle(fontSize: 12, color: textSecondary)),
                        Text(_formatDuration(ap.total), style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Controls: Prev · Play/Pause · Next  +  Loop
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Loop
                  IconButton(
                    icon: Icon(
                      Icons.loop_rounded,
                      color: ap.isLooping ? AppTheme.primaryIndigo : textSecondary.withValues(alpha: 0.5),
                      size: 26,
                    ),
                    onPressed: () => context.read<AudioPlayerProvider>().toggleLoop(),
                  ),
                  const SizedBox(width: 8),
                  // Prev
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded, size: 36,
                        color: ap.hasPrev ? textPrimary : textSecondary.withValues(alpha: 0.3)),
                    onPressed: ap.hasPrev ? () => context.read<AudioPlayerProvider>().prev() : null,
                  ),
                  const SizedBox(width: 8),
                  // Play/Pause
                  ap.isLoading
                      ? Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)],
                            ),
                          ),
                          child: const Center(
                            child: SizedBox(width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => context.read<AudioPlayerProvider>().togglePlayPause(),
                          child: Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryIndigo, Color(0xFF818CF8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryIndigo.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              ap.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                  const SizedBox(width: 8),
                  // Next
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, size: 36,
                        color: ap.hasNext ? textPrimary : textSecondary.withValues(alpha: 0.3)),
                    onPressed: ap.hasNext ? () => context.read<AudioPlayerProvider>().next() : null,
                  ),
                  const SizedBox(width: 8),
                  // Stop
                  IconButton(
                    icon: Icon(Icons.stop_circle_outlined, size: 26, color: textSecondary.withValues(alpha: 0.5)),
                    onPressed: () {
                      context.read<AudioPlayerProvider>().stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
