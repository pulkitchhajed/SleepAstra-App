import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  try {
    final model = GenerativeModel(
      model: 'gemini-flash-latest', 
      apiKey: 'AQ.Ab8RN6Lm5gpxg8uscT0wSiJRRzrMe11iPkDKQB8wLGRix3jenA'
    );
    
    // Testing history starting with model
    final history = [
      Content('model', [TextPart('Hello I am AI')])
    ];
    
    final chat = model.startChat(history: history);
    final response = chat.sendMessageStream(Content.text('Hi'));
    
    await for (final chunk in response) {
      print(chunk.text);
    }
  } catch(e) {
    print('Error: $e');
  }
}
