// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snore_clinics/modules/sleep_analysis/services/audio_analyzer_service.dart';

void main() {
  test('SnoreClinics AI Audio Stress Test (8-hour dummy file)', () async {
    print('--- SnoreClinics AI Audio Stress Test ---');
    final file = File('test/load_tests/8_hour_dummy.wav');
    
    final durationHours = 8;
    final sampleRate = 16000;
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final dataSize = durationHours * 60 * 60 * byteRate;
    
    if (!await file.exists() || await file.length() < dataSize) {
      print('Generating 8-hour WAV file (~${dataSize ~/ 1024 ~/ 1024} MB)... This will take a moment.');
      final raf = await file.open(mode: FileMode.write);
      
      // Write WAV header
      final header = ByteData(44);
      
      // RIFF chunk descriptor
      header.setUint8(0, 0x52); // 'R'
      header.setUint8(1, 0x49); // 'I'
      header.setUint8(2, 0x46); // 'F'
      header.setUint8(3, 0x46); // 'F'
      header.setUint32(4, 36 + dataSize, Endian.little);
      header.setUint8(8, 0x57); // 'W'
      header.setUint8(9, 0x41); // 'A'
      header.setUint8(10, 0x56); // 'V'
      header.setUint8(11, 0x45); // 'E'
      
      // fmt sub-chunk
      header.setUint8(12, 0x66); // 'f'
      header.setUint8(13, 0x6D); // 'm'
      header.setUint8(14, 0x74); // 't'
      header.setUint8(15, 0x20); // ' '
      header.setUint32(16, 16, Endian.little); // Subchunk1Size
      header.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
      header.setUint16(22, numChannels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little); // BlockAlign
      header.setUint16(34, bitsPerSample, Endian.little);
      
      // data sub-chunk
      header.setUint8(36, 0x64); // 'd'
      header.setUint8(37, 0x61); // 'a'
      header.setUint8(38, 0x74); // 't'
      header.setUint8(39, 0x61); // 'a'
      header.setUint32(40, dataSize, Endian.little);
      
      await raf.writeFrom(header.buffer.asUint8List());
      
      // Write data chunks (write 1MB chunks to avoid memory issues)
      final chunk = Uint8List(1024 * 1024);
      // fill with fake noise
      for (int i = 0; i < chunk.length; i++) {
         chunk[i] = (i % 256) - 128; // just randomish noise
      }
      
      int written = 0;
      while (written < dataSize) {
        int toWrite = (dataSize - written) < chunk.length ? (dataSize - written) : chunk.length;
        await raf.writeFrom(chunk, 0, toWrite);
        written += toWrite;
      }
      await raf.close();
      print('Generation complete.');
    } else {
      print('Using existing 8-hour WAV file.');
    }
    
    print('Starting 8-hour analysis. Please wait...');
    final analyzer = AudioAnalyzerService();
    final stopwatch = Stopwatch()..start();
    
    final report = await analyzer.analyzeFile(
      file.path, 
      '8_hour_dummy.wav',
      goalMinutes: 480,
      actualDuration: const Duration(hours: 8),
    );
    stopwatch.stop();
    print('======================================');
    print('✅ ANALYSIS SUCCESSFUL!');
    print('Time taken: ${stopwatch.elapsed.inSeconds} seconds');
    print('Snoring duration: ${report.snoringDuration.inSeconds} seconds');
    print('Quality Score: ${report.qualityScore}');
    print('======================================');
    
    // Test fails if we timeout or OOM, so reaching here is a pass.
    expect(report.qualityScore, isNotNull);
  });
}
