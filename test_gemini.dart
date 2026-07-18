import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  try {
    final model = GenerativeModel(
      model: 'gemini-flash-latest', 
      apiKey: 'AQ.Ab8RN6Lm5gpxg8uscT0wSiJRRzrMe11iPkDKQB8wLGRix3jenA'
    );
    final response = await model.generateContent([Content.text('Hello')]);
    print('Response 1: ${response.text}');
  } catch(e) {
    print('Error with gemini-flash-latest: $e');
  }

  try {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash', 
      apiKey: 'AQ.Ab8RN6Lm5gpxg8uscT0wSiJRRzrMe11iPkDKQB8wLGRix3jenA'
    );
    final response = await model.generateContent([Content.text('Hello')]);
    print('Response 2: ${response.text}');
  } catch(e) {
    print('Error with gemini-1.5-flash: $e');
  }
}
