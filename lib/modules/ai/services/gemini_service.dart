import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../sleep_analysis/models/sleep_report.dart';
import '../../journal/models/journal_entry.dart';
import '../../onboarding/models/user_profile.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Gemini AI service — structured JSON analysis and chat.
class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_GEMINI_API_KEY';
  static bool get _hasKey => _apiKey != 'YOUR_GEMINI_API_KEY';

  /// Generates an AI analysis from a user profile.
  Future<Map<String, dynamic>> analyzeProfile(UserProfile p) async {
    if (!_hasKey) return _offlineProfileAnalysis(p);
    try {
      final schema = Schema.object(
        properties: {
          'summary': Schema.string(description: 'A 2-3 sentence summary of their profile'),
          'riskLevel': Schema.string(description: 'Low, Medium, or High risk of sleep issues based on StopBang and BMI'),
          'recommendation': Schema.string(description: 'One key actionable recommendation based on their lifestyle (e.g. coffee, alcohol)'),
        },
        requiredProperties: ['summary', 'riskLevel', 'recommendation'],
      );
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: schema),
      );
      final prompt = 'Analyze this sleep profile: Age ${p.age}, BMI ${p.bmi.toStringAsFixed(1)}, Coffee ${p.caffeineCups} cups/day, Alcohol ${p.alcoholDays} days/week, Exercise ${p.exerciseDays} days/week, STOP-BANG score ${p.stopBangScore}/8. Provide a summary, risk level (Low/Medium/High), and one specific actionable recommendation.';
      final response = await model.generateContent([Content.text(prompt)]);
      return jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini Profile Error: $e');
      return _offlineProfileAnalysis(p);
    }
  }

  /// Generates a structured JSON analysis from a SleepReport.
  Future<Map<String, dynamic>> analyzeSession(
      SleepReport report, JournalEntry? journalEntry) async {
    if (!_hasKey) return _offlineJsonAnalysis(report, journalEntry);

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
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
          temperature: 0.2, // Low temp for analytical consistency
        ),
      );

      final prompt = _buildAnalysisPrompt(report, journalEntry);
      final response = await model.generateContent([Content.text(prompt)]);
      
      return jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini Error: $e');
      return _offlineJsonAnalysis(report, journalEntry);
    }
  }

  /// Analyzes correlations over multiple sessions.
  Future<Map<String, dynamic>> analyzeCorrelations(
      List<SleepReport> reports, List<JournalEntry> journals) async {
    if (!_hasKey) return _offlineCorrelationAnalysis(reports, journals);

    try {
      final schema = Schema.object(
        properties: {
          'summary': Schema.string(description: 'Executive summary of trends'),
          'correlations': Schema.array(
            description: 'Specific correlations found',
            items: Schema.object(
              properties: {
                'factor': Schema.string(),
                'impact': Schema.string(),
                'percentage': Schema.integer(),
              },
              requiredProperties: ['factor', 'impact', 'percentage'],
            ),
          ),
          'apneaTrend': Schema.string(description: 'Assessment of long-term apnea risk'),
        },
        requiredProperties: ['summary', 'correlations', 'apneaTrend'],
      );

      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
        ),
      );

      final prompt = _buildCorrelationPrompt(reports, journals);
      final response = await model.generateContent([Content.text(prompt)]);
      
      return jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Gemini Correlation Error: $e');
      return _offlineCorrelationAnalysis(reports, journals);
    }
  }

  /// Streams a conversational response from Nidra Chat with full context.
  ///
  /// Nidra receives ALL available user data:
  ///   • [userProfile]    — name, age, BMI, gender, STOP-BANG score, lifestyle baseline
  ///   • [latestReport]   — most recent sleep session metrics
  ///   • [latestJournal]  — most recent daily journal (caffeine, alcohol, stress, mood, etc.)
  ///   • [sleepHistory]   — last N session summaries for trend awareness
  ///   • [history]        — conversation turn history for multi-turn chat
  Stream<String> chat(
    String userMessage, {
    UserProfile? userProfile,
    SleepReport? latestReport,
    JournalEntry? latestJournal,
    List<SleepReport> sleepHistory = const [],
    List<Map<String, String>> history = const [],
  }) async* {
    if (!_hasKey) {
      yield* _offlineChat(userMessage, latestReport);
      return;
    }

    try {
      // ── 1. User Profile Context ───────────────────────────────────
      String profileContext = '';
      if (userProfile != null && userProfile.name.isNotEmpty) {
        final bmi = userProfile.bmi.toStringAsFixed(1);
        final bmiLabel = userProfile.bmi < 18.5
            ? 'underweight'
            : userProfile.bmi < 25
                ? 'healthy'
                : userProfile.bmi < 30
                    ? 'overweight'
                    : 'obese';
        final stopBangRisk = userProfile.stopBangScore >= 5
            ? 'High'
            : userProfile.stopBangScore >= 3
                ? 'Intermediate'
                : 'Low';

        profileContext = '''
USER PROFILE:
- Name: ${userProfile.name}
- Age: ${userProfile.age}, Gender: ${userProfile.gender}
- BMI: $bmi ($bmiLabel), Weight: ${userProfile.weightKg.toStringAsFixed(1)} kg, Height: ${userProfile.heightCm.toStringAsFixed(0)} cm
- STOP-BANG Apnea Risk Score: ${userProfile.stopBangScore}/8 ($stopBangRisk risk)
- Bedtime: ${userProfile.bedtime}, Wake Time: ${userProfile.wakeTime}
- Sleep Goal: ${userProfile.goalDurationMinutes ~/ 60}h ${userProfile.goalDurationMinutes % 60}m per night
- Habitual Caffeine: ${userProfile.caffeineCups} cups/day
- Habitual Alcohol: ${userProfile.alcoholDays} days/week
- Exercise Frequency: ${userProfile.exerciseDays} days/week''';
      }

      // ── 2. Latest Sleep Session Context ──────────────────────────
      String sessionContext = '';
      if (latestReport != null) {
        final scoreLabel = latestReport.qualityScore >= 85
            ? 'Excellent'
            : latestReport.qualityScore >= 65
                ? 'Good'
                : latestReport.qualityScore >= 45
                    ? 'Fair'
                    : 'Poor';
        sessionContext = '''
LATEST SLEEP SESSION (${_formatDate(latestReport.recordedAt)}):
- Quality Score: ${latestReport.qualityScore.toInt()}/100 ($scoreLabel)
- Total Sleep: ${latestReport.totalDuration.inHours}h ${latestReport.totalDuration.inMinutes % 60}m
- Snoring Duration: ${latestReport.snoringDuration.inMinutes} minutes (${latestReport.snoringPercentage.toStringAsFixed(1)}% of night)
- Snoring Events: ${latestReport.snoringEventCount}
- Apnea Risk: ${latestReport.apneaRiskLevel}
- Sleep Stages: Deep ${(latestReport.deepSleepPercent * 100).toStringAsFixed(0)}%, REM ${(latestReport.remSleepPercent * 100).toStringAsFixed(0)}%, Light ${(latestReport.lightSleepPercent * 100).toStringAsFixed(0)}%
- Sleep Debt: ${latestReport.sleepDebtHours.toStringAsFixed(1)} hours''';
      } else {
        sessionContext = 'The user has not recorded any sleep sessions yet.';
      }

      // ── 3. Latest Journal Context ─────────────────────────────────
      String journalContext = '';
      if (latestJournal != null) {
        final stressLabel = latestJournal.stressLevel >= 8
            ? 'Very High'
            : latestJournal.stressLevel >= 6
                ? 'High'
                : latestJournal.stressLevel >= 4
                    ? 'Moderate'
                    : 'Low';
        journalContext = '''
LATEST DAILY JOURNAL (${_formatDate(latestJournal.date)}):
- Caffeine: ${latestJournal.caffeineUnits} units
- Alcohol: ${latestJournal.alcoholUnits} drinks
- Stress Level: ${latestJournal.stressLevel}/10 ($stressLabel)
- Sleep Position: ${latestJournal.sleepPosition}
- Morning Mood Score: ${latestJournal.moodScore}/10
- Energy Level: ${latestJournal.energyLevel}
- Nasal Congestion: ${latestJournal.hadCongestion ? 'Yes' : 'No'}
${latestJournal.hoursBeforeBedMeal != null ? '- Last Meal Before Bed: ${latestJournal.hoursBeforeBedMeal}h prior' : ''}
${latestJournal.notes.isNotEmpty ? '- User Notes: "${latestJournal.notes}"' : ''}''';
      }

      // ── 4. Sleep History Trend Context ────────────────────────────
      String historyContext = '';
      if (sleepHistory.length > 1) {
        final recent = sleepHistory.take(7).toList(); // last 7 sessions
        final avgScore = recent.map((r) => r.qualityScore).reduce((a, b) => a + b) / recent.length;
        final avgSnoreMin = recent.map((r) => r.snoringDuration.inMinutes).reduce((a, b) => a + b) / recent.length;
        final highRiskCount = recent.where((r) => r.apneaRiskLevel == 'High').length;
        historyContext = '''
SLEEP HISTORY TREND (last ${recent.length} sessions):
- Average Quality Score: ${avgScore.toStringAsFixed(1)}/100
- Average Snoring: ${avgSnoreMin.toStringAsFixed(0)} minutes per night
- High Apnea Risk sessions: $highRiskCount out of ${recent.length}''';
      }

      // ── 5. Build full system instruction ─────────────────────────
      final systemInstruction = '''You are Nidra, a professional and warm AI sleep assistant for the SnoreClinics app.
Your role is to help users understand their sleep patterns, snoring data, and overall sleep health.
You specialize in Obstructive Sleep Apnea (OSA), CPAP machines, and specific breathing exercises.
Provide accurate, scientifically-grounded answers about sleep disorders, sleep hygiene, and snoring mechanics.
Give thorough, actionable, and easy-to-understand responses.
When relevant, mention https://snoreclinics.org/ for professional help.
You may use markdown formatting like **bold**, bullet lists, and headers to structure your responses clearly.
Always personalize your answers using the user's data below when available.
Always address the user by their name when you know it.

$profileContext

$sessionContext

$journalContext

$historyContext

CRITICAL RULE: You must append the following exact sentence to the very end of your response for any medical or diagnostic questions:
"*I am an AI, please consult a doctor for a professional diagnosis.*"''';

      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
        systemInstruction: Content.system(systemInstruction),
      );

      // ── 6. Build conversation history ─────────────────────────────
      final mergedHistory = <Map<String, String>>[];
      for (final msg in history) {
        final role = msg['role'];
        final text = msg['text'] ?? '';
        if (text.isEmpty || role == null) continue;
        
        if (mergedHistory.isNotEmpty && mergedHistory.last['role'] == role) {
          mergedHistory.last['text'] = '${mergedHistory.last['text']}\n\n$text';
        } else {
          mergedHistory.add(Map.from(msg));
        }
      }
      
      // History must end with a 'model' message before we send the next 'user' message
      if (mergedHistory.isNotEmpty && mergedHistory.last['role'] == 'user') {
        mergedHistory.removeLast();
      }

      final chatHistory = <Content>[];
      for (final msg in mergedHistory) {
        final role = msg['role'];
        final text = msg['text'] ?? '';
        if (role == 'user') {
          chatHistory.add(Content.text(text));
        } else if (role == 'model') {
          chatHistory.add(Content('model', [TextPart(text)]));
        }
      }

      final chat = model.startChat(history: chatHistory);
      final response = chat.sendMessageStream(Content.text(userMessage));

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('Gemini Chat Error: $e');
      yield* _offlineChat(userMessage, latestReport);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ── Offline / demo responses ────────────────────────────────────

  Map<String, dynamic> _offlineProfileAnalysis(UserProfile p) {
    final risk = p.stopBangScore >= 5 ? 'High' : p.stopBangScore >= 3 ? 'Medium' : 'Low';
    return {
      'summary': 'Based on your age, BMI (${p.bmi.toStringAsFixed(1)}), and lifestyle, your profile indicates typical sleep architecture with some room for optimization.',
      'riskLevel': risk,
      'recommendation': p.caffeineCups > 2 
          ? 'Reduce caffeine intake in the afternoon to improve deep sleep cycles.'
          : (p.exerciseDays < 2 ? 'Incorporate more daily exercise to build sleep pressure.' : 'Maintain your healthy habits for consistent recovery.'),
    };
  }

  Map<String, dynamic> _offlineJsonAnalysis(SleepReport r, JournalEntry? j) {
    final quality = r.quality.name;
    final snoreMin = r.snoringDuration.inMinutes;
    final score = r.qualityScore.toInt();
    
    String rec = 'Sleep Quality: ${quality[0].toUpperCase()}${quality.substring(1)} ($score/100)\n\n';

    if (snoreMin == 0) {
      rec += 'Excellent news — no significant snoring was detected. Your airway remained clear throughout the night.\n\n';
    } else if (snoreMin < 20) {
      rec += 'Mild snoring detected (${snoreMin}m). This is common and not immediately concerning.\n\n';
    } else {
      rec += 'Moderate-to-heavy snoring detected (${snoreMin}m). Consider sleeping on your side and reviewing your evening habits.\n\n';
    }

    final List<String> factors = [];

    if (j != null) {
      if (j.alcoholUnits > 2) {
        factors.add('Alcohol (${j.alcoholUnits} units)');
      }
      if (j.stressLevel >= 7) {
        factors.add('High Stress (${j.stressLevel}/10)');
      }
      if (j.caffeineUnits > 2) {
        factors.add('Caffeine (${j.caffeineUnits} units)');
      }
    }

    rec += '**Recommendation**: ${score >= 80 ? "Keep up this routine!" : score >= 60 ? "A few small changes could improve your sleep significantly." : "Let's work together to find the root cause of your poor sleep."}';

    return {
      'aiScore': score,
      'recommendation': rec,
      'lifestyleFactors': factors.isEmpty ? ['None detected'] : factors,
    };
  }

  Stream<String> _offlineChat(String msg, SleepReport? r) async* {
    const errorMsg = 'I am currently running in offline mode because the Gemini API key is either missing or invalid. Please update the `.env` file with a valid Gemini API key from Google AI Studio and rebuild the app to activate my full AI capabilities!';
    for (final chunk in errorMsg.split(' ')) {
      yield '$chunk ';
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  String _buildAnalysisPrompt(SleepReport r, JournalEntry? j) {
    final sb = StringBuffer();
    sb.writeln('Analyse this sleep session and provide personalised feedback:');
    sb.writeln('- Total sleep duration: ${r.totalDuration.inMinutes} minutes');
    sb.writeln('- Snoring duration: ${r.snoringDuration.inMinutes} minutes');
    sb.writeln('- Snoring events: ${r.snoringEventCount}');
    sb.writeln('- Quality score: ${r.qualityScore}');
    if (j != null) {
      sb.writeln('Evening journal:');
      sb.writeln('  Caffeine: ${j.caffeineUnits} units');
      sb.writeln('  Alcohol: ${j.alcoholUnits} units');
      sb.writeln('  Stress: ${j.stressLevel}/10');
    }
    sb.writeln('Provide a concise 3-paragraph analysis with lifestyle factors and actionable tips. Provide clean plain text output. DO NOT use any markdown formatting like ** or ##.');
    return sb.toString();
  }

  String _buildCorrelationPrompt(List<SleepReport> reports, List<JournalEntry> journals) {
    final sb = StringBuffer();
    sb.writeln('Analyse the following sleep history (last ${reports.length} sessions) to find correlations between lifestyle and snoring:');
    
    for (var i = 0; i < reports.length; i++) {
      final r = reports[i];
      final j = journals.length > i ? journals[i] : null;
      sb.writeln('Session ${i + 1}: Date=${r.recordedAt}, Score=${r.qualityScore}, SnoreMin=${r.snoringDuration.inMinutes}, ApneaRisk=${r.apneaRiskLevel}');
      if (j != null) {
        sb.writeln('  Journal: Alcohol=${j.alcoholUnits}, Caffeine=${j.caffeineUnits}, Stress=${j.stressLevel}/10');
      }
    }
    
    sb.writeln('\nReturn a JSON summary identifying specific correlations (e.g. "On nights with >2 units of alcohol, snoring increases by X%").');
    return sb.toString();
  }

  Map<String, dynamic> _offlineCorrelationAnalysis(List<SleepReport> reports, List<JournalEntry> journals) {
    return {
      'summary': 'Your sleep quality is generally stable, but we found some patterns related to your evening routine.',
      'correlations': [
        {
          'factor': 'Alcohol Intake',
          'impact': 'Snoring increases on nights with alcohol.',
          'percentage': 35
        },
        {
          'factor': 'High Stress',
          'impact': 'Sleep depth decreases during high-stress periods.',
          'percentage': 20
        }
      ],
      'apneaTrend': 'Your apnea risk has remained "Low" over the last 14 days. Consistent side-sleeping is helping.'
    };
  }
}
