import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  try {
    final schema = Schema.object(
      properties: {
        'aiScore': Schema.integer(description: 'AI sleep score 0-100'),
        'recommendation': Schema.string(description: 'Detailed sleep analysis and tips'),
        'lifestyleFactors': Schema.array(
          description: 'Identified lifestyle factors affecting sleep from journal',
          items: Schema.string(),
        ),
      },
      requiredProperties: ['aiScore', 'recommendation', 'lifestyleFactors'],
    );

    final model = GenerativeModel(
      model: 'gemini-flash-latest', 
      apiKey: 'AQ.Ab8RN6Lm5gpxg8uscT0wSiJRRzrMe11iPkDKQB8wLGRix3jenA',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
      ),
    );
    
    final prompt = 'Analyze this sleep session...';
    final response = await model.generateContent([Content.text(prompt)]);
    print(response.text);
  } catch(e) {
    print('Error: $e');
  }
}
