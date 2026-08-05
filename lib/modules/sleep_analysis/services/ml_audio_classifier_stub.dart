import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:snore_clinics/modules/sleep_analysis/models/sleep_report.dart' show NoiseType;

/// A stub wrapper for Web builds where tflite_flutter is unsupported.
class MLAudioClassifierService {
  bool _isInitialized = false;

  Future<void> initializeFromBuffer(Uint8List modelBuffer) async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('MLAudioClassifierService (Stub): ML is disabled on Web.');
  }

  /// Always returns ambient noise on Web.
  NoiseType classifyAudio(Float32List audio16kHz) {
    return NoiseType.ambient;
  }
}
