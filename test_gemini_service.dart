import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:snore_clinics/modules/ai/services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final service = GeminiService();
  
  final stream = service.chat('Hello');
  print('Starting chat stream...');
  await for (final chunk in stream) {
    stdout.write(chunk);
  }
  print('\nFinished chat stream.');
}
