/// Shared sleep/relaxation audio track definitions.
///
/// A single source of truth used by both [SleepAnalysisScreen] and
/// [WellnessScreen] so the two screens always show identical track lists
/// without duplicating the URLs.
library;

import 'package:flutter/material.dart';

/// Metadata for a single audio track.
class SleepTrack {
  const SleepTrack({
    required this.name,
    required this.category,
    required this.duration,
    required this.icon,
    required this.color,
    required this.url,
    required this.type,
  });

  final String name;
  final String category;
  final String duration;
  final IconData icon;
  final Color color;
  final String url;

  /// Wellness screen filter category (e.g. 'Sleep Sounds', 'Meditation').
  final String type;
}

/// The canonical list of all app audio tracks.
const List<SleepTrack> kSleepTracks = [
  SleepTrack(
    name: 'Brown Noise',
    category: 'Ambient',
    duration: '10 Min',
    icon: Icons.waves,
    color: Color(0xFF5D4037),
    url: 'https://archive.org/download/WhiteBrownNoise/BrownNoise.ogg',
    type: 'Sleep Sounds',
  ),
  SleepTrack(
    name: 'Soft Rain',
    category: 'Nature',
    duration: '15 Min',
    icon: Icons.water_drop,
    color: Color(0xFF4FC3F7),
    url: 'https://archive.org/download/RelaxingRainAndLoudThunderFreeFieldRecordingOfNatureSoundsForSleepOrMeditation/soft.ogg',
    type: 'Sleep Sounds',
  ),
  SleepTrack(
    name: 'Waterfalls',
    category: 'Nature',
    duration: '20 Min',
    icon: Icons.pool,
    color: Color(0xFF00796B),
    url: 'https://archive.org/download/WhiteBrownNoise/VirtualWaterfalls.ogg',
    type: 'Sleep Sounds',
  ),
  SleepTrack(
    name: 'Guided Meditation',
    category: 'Voices',
    duration: '10 Min',
    icon: Icons.self_improvement,
    color: Color(0xFF8E24AA),
    url: 'https://archive.org/download/swmp167/SWMP167.mp3',
    type: 'Meditation',
  ),
  SleepTrack(
    name: 'Calm Piano',
    category: 'Music',
    duration: '30 Min',
    icon: Icons.music_note,
    color: Color(0xFF3949AB),
    url: 'https://archive.org/download/DreamlandByMikeHuber/16%20The%20End%20Of%20The%20Day%20Revox.mp3',
    type: 'Music',
  ),
  SleepTrack(
    name: 'Instrumental Sleep',
    category: 'Music',
    duration: '45 Min',
    icon: Icons.spa,
    color: Color(0xFF43A047),
    url: 'https://archive.org/download/sunflowertracks/sunflowertracks.mp3',
    type: 'Music',
  ),
  SleepTrack(
    name: 'Forest Night',
    category: 'Nature',
    duration: '60 Min',
    icon: Icons.forest,
    color: Color(0xFF1B5E20),
    url: 'https://archive.org/download/QuietForestNightSoundEffects/Quiet%20Forest%20Night.mp3',
    type: 'Sleep Sounds',
  ),
  SleepTrack(
    name: 'Ocean Waves',
    category: 'Nature',
    duration: '15 Min',
    icon: Icons.waves,
    color: Color(0xFF0277BD),
    url: 'https://archive.org/download/OceanWaves_447/OceanWaves.mp3',
    type: 'Sleep Sounds',
  ),
  SleepTrack(
    name: 'White Noise',
    category: 'Ambient',
    duration: '30 Min',
    icon: Icons.blur_on,
    color: Color(0xFF9E9E9E),
    url: 'https://archive.org/download/WhiteNoise10Min/WhiteNoise.mp3',
    type: 'Sleep Sounds',
  ),
  SleepTrack(
    name: 'Binaural Beats',
    category: 'Healing',
    duration: '20 Min',
    icon: Icons.headphones,
    color: Color(0xFF512DA8),
    url: 'https://archive.org/download/binaural-beats-sleep/binaural.mp3',
    type: 'Meditation',
  ),
];
