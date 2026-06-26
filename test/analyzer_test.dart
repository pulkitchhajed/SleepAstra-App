// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snore_clinics/modules/sleep_analysis/services/audio_analyzer_service.dart';

void main() {
  test('AudioAnalyzerService whole flow', () async {
    print('Creating mock audio file...');
    final path = 'test_audio.wav';
    final file = File(path);
    
    // Create a 60 second mock recording
    final sampleRate = 16000;
    final numChannels = 1;
    final durationSec = 60;
    final numSamples = sampleRate * durationSec;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    
    final builder = BytesBuilder();
    
    // WAV Header
    builder.add('RIFF'.codeUnits);
    builder.add((ByteData(4)..setUint32(0, fileSize - 8, Endian.little)).buffer.asUint8List());
    builder.add('WAVE'.codeUnits);
    builder.add('fmt '.codeUnits);
    builder.add((ByteData(4)..setUint32(0, 16, Endian.little)).buffer.asUint8List());
    builder.add((ByteData(2)..setUint16(0, 1, Endian.little)).buffer.asUint8List());
    builder.add((ByteData(2)..setUint16(0, numChannels, Endian.little)).buffer.asUint8List());
    builder.add((ByteData(4)..setUint32(0, sampleRate, Endian.little)).buffer.asUint8List());
    builder.add((ByteData(4)..setUint32(0, sampleRate * numChannels * 2, Endian.little)).buffer.asUint8List());
    builder.add((ByteData(2)..setUint16(0, numChannels * 2, Endian.little)).buffer.asUint8List());
    builder.add((ByteData(2)..setUint16(0, 16, Endian.little)).buffer.asUint8List());
    
    builder.add('data'.codeUnits);
    builder.add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List());
    
    final random = Random();
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      int sample = 0;
      
      if (t > 20 && t < 30) {
        final fundamental = sin(2 * pi * 80 * t);
        final noise = (random.nextDouble() * 2 - 1) * 0.3;
        sample = ((fundamental + noise) * 15000).toInt();
      } else {
        sample = ((random.nextDouble() * 2 - 1) * 300).toInt();
      }
      builder.add((ByteData(2)..setInt16(0, sample, Endian.little)).buffer.asUint8List());
    }
    
    await file.writeAsBytes(builder.toBytes());
    print('Mock audio saved to $path');
    
    try {
      print('Running AudioAnalyzerService...');
      final service = AudioAnalyzerService();
      final report = await service.analyzeFile(path, 'test_audio.wav', goalMinutes: 480, actualDuration: Duration(seconds: 60));
      
      print('\n--- Analysis Report ---');
      print('Duration: ${report.totalDuration.inSeconds} seconds');
      print('Score: ${report.qualityScore}/100');
      print('Quality: ${report.quality.name}');
      print('Snore Events: ${report.snoringEvents.length}');
      if (report.snoringEvents.isNotEmpty) {
        print('First snore event: ${report.snoringEvents.first.timestamp.inSeconds}s, duration: ${report.snoringEvents.first.duration.inSeconds}s, amplitude: ${report.snoringEvents.first.amplitude}');
      }
      print('Sleep Stages: Deep ${(report.deepSleepPercent * 100).toStringAsFixed(1)}%, Light ${(report.lightSleepPercent * 100).toStringAsFixed(1)}%, REM ${(report.remSleepPercent * 100).toStringAsFixed(1)}%');
      
      expect(report.totalDuration.inSeconds, greaterThan(0));
      expect(report.snoringEvents.isNotEmpty, true);
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  });
}
