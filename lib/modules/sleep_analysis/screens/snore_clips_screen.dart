import 'package:flutter/material.dart';
import '../models/sleep_report.dart';
import '../widgets/snore_audio_player.dart';

class SnoreClipsScreen extends StatelessWidget {
  final List<SnoreAudioClip> clips;
  final DateTime recordedAt;

  const SnoreClipsScreen({super.key, required this.clips, required this.recordedAt});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = isLight ? Colors.black87 : Colors.white;
    final textSec = isLight ? Colors.black54 : Colors.white60;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('All Snore Recordings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: clips.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final clip = clips[index];
          // Format duration (e.g., 12s, 1m 5s)
          final d = clip.duration;
          final durationStr = d.inMinutes > 0 
              ? '${d.inMinutes}m ${d.inSeconds % 60}s'
              : '${d.inSeconds}s';
              
          // Format time (e.g., +2h 15m into sleep)
          final ts = clip.timestamp;
          final tsStr = ts.inHours > 0 
              ? '+${ts.inHours}h ${ts.inMinutes % 60}m'
              : '+${ts.inMinutes}m';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recording ${index + 1}',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$tsStr  •  $durationStr',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SnoreAudioPlayer(
                localPath: clip.localPath,
                audioUrl: clip.remoteUrl,
                recordedTime: recordedAt.add(clip.timestamp),
              ),
            ],
          );
        },
      ),
    );
  }
}
