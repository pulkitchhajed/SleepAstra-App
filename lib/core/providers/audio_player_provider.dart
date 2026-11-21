import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../modules/audio/models/audio_track_model.dart';

/// Global audio playback provider.
/// Lives above MaterialApp so it persists across all tabs.
class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  AudioTrackModel? activeTrack;
  List<AudioTrackModel> playlist = [];
  bool isPlaying = false;
  bool isLooping = false;
  Duration position = Duration.zero;
  Duration total = Duration.zero;
  bool isLoading = false;

  AudioPlayerProvider() {
    _player.positionStream.listen((p) {
      position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      total = d ?? Duration.zero;
      notifyListeners();
    });
    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
    });
  }

  /// Start playing [track]. Pass the full [playlist] for prev/next support.
  Future<void> play(AudioTrackModel track, List<AudioTrackModel> tracks) async {
    playlist = tracks;
    activeTrack = track;
    isLoading = true;
    notifyListeners();

    try {
      final src = AudioSource.uri(Uri.parse(track.audioUrl));
      await _player.setAudioSource(src);
      _player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
      await _player.play();
      isPlaying = true;
    } catch (_) {
      activeTrack = null;
      isPlaying = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    isPlaying = true;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    activeTrack = null;
    isPlaying = false;
    isLooping = false;
    position = Duration.zero;
    total = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
    position = pos;
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    isLooping = !isLooping;
    await _player.setLoopMode(isLooping ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  /// Play the next track in the playlist.
  Future<void> next() async {
    if (activeTrack == null || playlist.isEmpty) return;
    final idx = playlist.indexWhere((t) => t.id == activeTrack!.id);
    if (idx < playlist.length - 1) {
      await play(playlist[idx + 1], playlist);
    }
  }

  /// Play the previous track in the playlist.
  Future<void> prev() async {
    if (activeTrack == null || playlist.isEmpty) return;
    final idx = playlist.indexWhere((t) => t.id == activeTrack!.id);
    if (idx > 0) {
      await play(playlist[idx - 1], playlist);
    }
  }

  bool get hasNext {
    if (activeTrack == null || playlist.isEmpty) return false;
    final idx = playlist.indexWhere((t) => t.id == activeTrack!.id);
    return idx < playlist.length - 1;
  }

  bool get hasPrev {
    if (activeTrack == null || playlist.isEmpty) return false;
    final idx = playlist.indexWhere((t) => t.id == activeTrack!.id);
    return idx > 0;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
