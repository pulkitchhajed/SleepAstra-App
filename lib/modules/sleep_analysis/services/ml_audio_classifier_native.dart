import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:snore_clinics/modules/sleep_analysis/models/sleep_report.dart' show NoiseType;

/// A wrapper around the YAMNet TFLite model to classify audio chunks.
/// YAMNet accepts 16kHz mono audio as a 1D float array.
/// It outputs scores for 521 audio classes.
class MLAudioClassifierService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  // Pre-allocated output buffer — avoids creating a new nested list on every call.
  List<List<double>>? _outputBuffer;

  // Key YAMNet class indices
  static const int indexSpeech = 0;
  static const int indexWhistling = 13;
  static const int indexSnort = 47;
  static const int indexSnoring = 48;
  static const int indexBreathing = 288;
  static const int indexCough = 22;
  static const int indexBabyCrying = 42;
  static const int indexDog = 71;
  static const int indexCat = 73;
  static const int indexMusic = 137;
  static const int indexVehicle = 322;
  static const int indexWind = 382;

  Future<void> initializeFromBuffer(Uint8List modelBuffer) async {
    if (_isInitialized) return;
    try {
      _interpreter = Interpreter.fromBuffer(modelBuffer);
      _isInitialized = true;
      debugPrint('MLAudioClassifierService: YAMNet initialized successfully from buffer.');
    } catch (e) {
      debugPrint('MLAudioClassifierService: Error initializing YAMNet: $e');
    }
  }

  /// Classifies a 16kHz audio buffer and returns the predicted NoiseType.
  NoiseType classifyAudio(Float32List audio16kHz) {
    if (!_isInitialized || _interpreter == null) {
      return NoiseType.ambient; // Fallback
    }

    try {
      final input = audio16kHz.buffer.asFloat32List(audio16kHz.offsetInBytes, audio16kHz.length);
      
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[1];
      _outputBuffer ??= List.generate(1, (_) => List.filled(numClasses, 0.0));

      const int windowSize = 15600; // 0.975 seconds at 16kHz

      if (input.length < windowSize) {
        return NoiseType.ambient;
      }

      // Run inference on just the first sub-window.
      // For a 2-second chunk this was previously running 2× and averaging.
      // Since we only call ML when snoreVote >= 2 (spectral heuristics are
      // already suspicious), a single 0.975 s window gives sufficient accuracy
      // at half the inference cost. The first window is representative since
      // snoring is a sustained, periodic signal.
      final windowInput = input.sublist(0, windowSize);
      final out = _outputBuffer!;
      for (int c = 0; c < out[0].length; c++) out[0][c] = 0.0; // reset
      _interpreter!.run(windowInput, out);
      final scores = out[0];

      // Extract specific scores
      double baseSnoreScore = scores[indexSnoring];
      double snortScore     = scores[indexSnort];
      double breathingScore = scores[indexBreathing];

      // Combine related classes into a single effective snore confidence
      double snoreScore = baseSnoreScore + (snortScore * 0.5) + (breathingScore * 0.3);

      double speechScore = scores[indexSpeech];
      double whistleScore = scores[indexWhistling];
      double coughScore   = scores[indexCough];
      double babyScore    = scores[indexBabyCrying];
      double dogScore     = scores[indexDog];
      double catScore     = scores[indexCat];
      double musicScore   = scores[indexMusic];
      double envScore     = scores[indexVehicle] + scores[indexWind];

      // Classification Logic
      // KEY RULE: If there is meaningful speech signal, ALWAYS classify as talking.
      // Talking and snoring can have overlapping acoustic features,
      // so we must never let a marginal snore score override clear speech evidence.
      if (speechScore > 0.08) { // Raised from 0.01 to prevent faint vocal overtones in snoring from being labeled as speech
        return NoiseType.talking;
      } else if (whistleScore > 0.05) { // Highly sensitive whistling threshold
        return NoiseType.ambient; // Whistling maps to ambient noise
      } else if (babyScore > 0.15) {
        return NoiseType.babyCrying;
      } else if (coughScore > 0.15) {
        return NoiseType.coughing;
      } else if (snoreScore > 0.15 && snoreScore > (speechScore * 3.0) && snoreScore > catScore && snoreScore > dogScore) {
        // Only classify as snoring if snore confidence is strong AND
        // at least 3x stronger than any residual speech signal.
        // Threshold lowered from 0.20 -> 0.15 to allow combined breathing/snort scores to push borderline snores through.
        return NoiseType.snoring;
      } else if (catScore > 0.15 || dogScore > 0.15) {
        return NoiseType.pets;
      } else if (musicScore > 0.15) {
        return NoiseType.music;
      } else if (envScore > 0.15) {
        return NoiseType.environmental;
      } else {
        return NoiseType.ambient;
      }

    } catch (e) {
      debugPrint('MLAudioClassifierService: Error during inference: $e');
      return NoiseType.ambient;
    }
  }
}
