import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:sleep_analysis/modules/sleep_analysis/services/audio_analyzer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Creating mock audio file...');
  final path = 'test_audio.wav';
  final file = File(path);
  
  // Create a 60 second mock recording
  // 16000 sample rate, 1 channel, 16 bits per sample (2 bytes)
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
  builder.add((ByteData(2)..setUint16(0, 1, Endian.little)).buffer.asUint8List()); // AudioFormat
  builder.add((ByteData(2)..setUint16(0, numChannels, Endian.little)).buffer.asUint8List());
  builder.add((ByteData(4)..setUint32(0, sampleRate, Endian.little)).buffer.asUint8List());
  builder.add((ByteData(4)..setUint32(0, sampleRate * numChannels * 2, Endian.little)).buffer.asUint8List()); // ByteRate
  builder.add((ByteData(2)..setUint16(0, numChannels * 2, Endian.little)).buffer.asUint8List()); // BlockAlign
  builder.add((ByteData(2)..setUint16(0, 16, Endian.little)).buffer.asUint8List()); // BitsPerSample
  
  builder.add('data'.codeUnits);
  builder.add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List());
  
  // Generate audio data
  // Let's create some periods of silence and some periods of "snoring"
  final random = Random();
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    int sample = 0;
    
    // Snoring simulation between 20s and 30s
    if (t > 20 && t < 30) {
      // Low frequency (around 80Hz) + noise, high amplitude
      final fundamental = sin(2 * pi * 80 * t);
      final noise = (random.nextDouble() * 2 - 1) * 0.3;
      sample = ((fundamental + noise) * 15000).toInt();
    } 
    // Silence/room noise otherwise
    else {
      sample = ((random.nextDouble() * 2 - 1) * 300).toInt(); // Low amplitude noise
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
    print('Duration: ${report.durationMs / 1000} seconds');
    print('Score: ${report.score}/100');
    print('Quality: ${report.quality.name}');
    print('Snore Events: ${report.snoringEvents.length}');
    if (report.snoringEvents.isNotEmpty) {
      print('First snore event: ${report.snoringEvents.first.timestampMs / 1000}s, duration: ${report.snoringEvents.first.durationMs / 1000}s, intensity: ${report.snoringEvents.first.intensity.name}');
    }
    print('Sleep Stages: Deep ${(report.sleepStages['deep']! * 100).toStringAsFixed(1)}%, Light ${(report.sleepStages['light']! * 100).toStringAsFixed(1)}%, REM ${(report.sleepStages['rem']! * 100).toStringAsFixed(1)}%');
  } catch (e) {
    print('Error during analysis: $e');
  } finally {
    if (await file.exists()) {
      await file.delete();
      print('\nCleaned up $path');
    }
  }
}
