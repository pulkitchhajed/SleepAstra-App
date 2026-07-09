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

  // Key YAMNet class indices
  static const int indexSpeech = 0;
  static const int indexWhistling = 13;
  static const int indexSnoring = 48;
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
      
      const int windowSize = 15600; // 0.975 seconds at 16kHz
      
      if (input.length < windowSize) {
        return NoiseType.ambient; 
      }

      int numWindows = input.length ~/ windowSize;
      List<double> avgScores = List.filled(numClasses, 0.0);

      // Run inference on each 0.975s window
      for (int w = 0; w < numWindows; w++) {
        final windowInput = input.sublist(w * windowSize, (w + 1) * windowSize);
        
        var output = List.generate(1, (_) => List.filled(numClasses, 0.0));
        _interpreter!.run(windowInput, output);
        
        for (int c = 0; c < numClasses; c++) {
          avgScores[c] += output[0][c];
        }
      }

      // Average scores across windows
      for (int c = 0; c < numClasses; c++) {
        avgScores[c] /= numWindows;
      }

      // Extract specific scores
      double snoreScore = avgScores[indexSnoring];
      double speechScore = avgScores[indexSpeech];
      double whistleScore = avgScores[indexWhistling];
      double coughScore = avgScores[indexCough];
      double babyScore = avgScores[indexBabyCrying];
      double dogScore = avgScores[indexDog];
      double catScore = avgScores[indexCat];
      double musicScore = avgScores[indexMusic];
      double envScore = avgScores[indexVehicle] + avgScores[indexWind];

      debugPrint('ML YAMNet Scores - Snore: ${snoreScore.toStringAsFixed(3)}, '
                 'Speech: ${speechScore.toStringAsFixed(3)}, '
                 'Cat: ${catScore.toStringAsFixed(3)}');

      // Classification Logic
      // KEY RULE: If there is meaningful speech signal, ALWAYS classify as talking.
      // Talking and snoring can have overlapping acoustic features,
      // so we must never let a marginal snore score override clear speech evidence.
      if (speechScore > 0.01) { // Highly sensitive speech/mumbling threshold
        return NoiseType.talking;
      } else if (whistleScore > 0.05) { // Highly sensitive whistling threshold
        return NoiseType.ambient; // Whistling maps to ambient noise
      } else if (babyScore > 0.15) {
        return NoiseType.babyCrying;
      } else if (coughScore > 0.15) {
        return NoiseType.coughing;
      } else if (snoreScore > 0.20 && snoreScore > (speechScore * 3.0) && snoreScore > catScore && snoreScore > dogScore) {
        // Only classify as snoring if snore confidence is strong AND
        // at least 3x stronger than any residual speech signal.
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
