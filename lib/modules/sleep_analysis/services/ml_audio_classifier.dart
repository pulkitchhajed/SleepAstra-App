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
  static const int indexSnoring = 48;
  static const int indexDog = 71;
  static const int indexCat = 73;
  static const int indexMusic = 137;

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
      double dogScore = avgScores[indexDog];
      double catScore = avgScores[indexCat];
      double musicScore = avgScores[indexMusic];

      debugPrint('ML YAMNet Scores - Snore: ${snoreScore.toStringAsFixed(3)}, '
                 'Speech: ${speechScore.toStringAsFixed(3)}, '
                 'Cat: ${catScore.toStringAsFixed(3)}');

      // Classification Logic
      if (snoreScore > 0.1 && snoreScore > speechScore && snoreScore > catScore && snoreScore > dogScore) {
        return NoiseType.snoring;
      } else if (speechScore > 0.1 || catScore > 0.1 || dogScore > 0.1 || musicScore > 0.1) {
        return NoiseType.talking; // Maps to any vetoed talking/animal sound
      } else {
        return NoiseType.ambient; // Or movement if amplitude was high
      }

    } catch (e) {
      debugPrint('MLAudioClassifierService: Error during inference: $e');
      return NoiseType.ambient;
    }
  }
}
