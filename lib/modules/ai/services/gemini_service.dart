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
        final snoringLabel = latestReport.snoringDuration.inMinutes == 0
            ? 'None'
            : latestReport.snoringDuration.inMinutes < 15
                ? 'Mild'
                : latestReport.snoringDuration.inMinutes < 30
                    ? 'Moderate'
                    : 'Heavy';
        sessionContext = '''
LATEST SLEEP SESSION (${_formatDate(latestReport.recordedAt)}):
- Quality Score: ${latestReport.qualityScore.toInt()}/100 ($scoreLabel)
- Total Sleep: ${latestReport.totalDuration.inHours}h ${latestReport.totalDuration.inMinutes % 60}m
- Snoring Duration: ${latestReport.snoringDuration.inMinutes} minutes ($snoringLabel — ${latestReport.snoringPercentage.toStringAsFixed(1)}% of night)
- Snoring Events: ${latestReport.snoringEventCount} individual episodes
- Apnea Risk Level: ${latestReport.apneaRiskLevel}
- Sleep Stages: Deep ${(latestReport.deepSleepPercent * 100).toStringAsFixed(0)}%, REM ${(latestReport.remSleepPercent * 100).toStringAsFixed(0)}%, Light ${(latestReport.lightSleepPercent * 100).toStringAsFixed(0)}%, Awake ${(100 - (latestReport.deepSleepPercent + latestReport.remSleepPercent + latestReport.lightSleepPercent) * 100).clamp(0, 100).toStringAsFixed(0)}%
- Sleep Debt: ${latestReport.sleepDebtHours.toStringAsFixed(1)} hours behind goal''';
      } else {
        sessionContext = 'The user has not recorded any sleep sessions yet. Encourage them to start their first recording tonight so Nidra can provide personalised data-driven insights.';
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
        final trend = recent.length >= 3
            ? (recent.first.qualityScore > recent.last.qualityScore ? 'Improving 📈' : recent.first.qualityScore < recent.last.qualityScore ? 'Declining 📉' : 'Stable ➡️')
            : 'Not enough data';
        final sessionLines = recent.asMap().entries.map((e) {
          final i = e.key + 1;
          final r = e.value;
          return 'Session $i (${_formatDate(r.recordedAt)}): Score=${r.qualityScore.toInt()}, Snore=${r.snoringDuration.inMinutes}min, Risk=${r.apneaRiskLevel}';
        }).join('\n  ');
        historyContext = '''
SLEEP HISTORY TREND (last ${recent.length} sessions):
- Overall Trend: $trend
- Average Quality Score: ${avgScore.toStringAsFixed(1)}/100
- Average Snoring: ${avgSnoreMin.toStringAsFixed(0)} minutes per night
- High Apnea Risk sessions: $highRiskCount out of ${recent.length}
- Session Breakdown:
  $sessionLines''';
      }

      // ── 5. Build few-shot examples ─────────────────────────────
      const fewShotExamples = '''
FEW-SHOT EXAMPLES (follow this format and tone exactly):

User: "Why do I snore?"
Nidra: "Great question! 😴 Snoring happens when airflow through your throat is partially blocked during sleep, causing the surrounding tissue to vibrate.

The most common culprits are:
- **Throat muscle relaxation**: Your muscles relax deeply during sleep, narrowing the airway.
- **Sleep position**: Sleeping on your back allows gravity to push the tongue and soft palate backward.
- **Weight**: Extra tissue around the neck puts pressure on your airway (BMI above 25 significantly increases risk).
- **Alcohol or sedatives**: These relax throat muscles even further, making snoring worse.
- **Nasal congestion**: Blocked nasal passages force you to breathe through your mouth, increasing vibration.

Do you tend to snore more on nights when you've had a drink or two? That's often a revealing clue! 🍷

*I am an AI, please consult a doctor for a professional diagnosis.*"

User: "What is sleep apnea?"
Nidra: "Sleep Apnea is a serious but very treatable sleep disorder. During an apnea episode, your airway becomes **completely blocked**, causing you to stop breathing for 10 seconds or more. Your brain then triggers a micro-arousal to restart breathing — and this can happen **hundreds of times per night** without you even knowing.

**The 3 types:**
- 🔴 **Obstructive Sleep Apnea (OSA)**: Throat tissue collapses. Most common type.
- 🟡 **Central Sleep Apnea**: Your brain forgets to send the signal to breathe.
- 🟠 **Complex Sleep Apnea**: A combination of both.

**Warning signs to watch for:**
- Loud snoring with pauses
- Waking up gasping or choking
- Extreme daytime fatigue despite a full night's sleep
- Morning headaches
- Poor concentration

Have you or a bed partner noticed any pauses in your breathing at night? That is the key diagnostic question!

*I am an AI, please consult a doctor for a professional diagnosis.*"

User: "How can I stop snoring tonight?"
Nidra: "Here are some proven changes you can make **right now** tonight! 💪

**Immediate steps:**
1. **Sleep on your side** — Use the tennis ball trick: tape a tennis ball to the back of your pyjama top to prevent rolling onto your back.
2. **Elevate your head** — Add an extra pillow or raise the head of your bed by 4 inches to reduce airway collapse.
3. **Skip the nightcap** — Avoid alcohol for at least 4 hours before bed.
4. **Clear your nasal passages** — Try a saline nasal rinse or a nasal strip (like Breathe Right) before sleep.
5. **Stay hydrated** — Dehydration thickens nasal secretions, making congestion and snoring worse.

**Longer-term strategies:**
- Practice **myofunctional exercises** (tongue and throat exercises) — studies show these reduce snoring by up to 39%.
- Maintain a healthy weight — even a 5–10% weight loss can significantly open the airway.

Would you like me to walk you through a specific throat exercise routine you can start tonight? 🏋️"
''';

      // ── 6. Build full system instruction ─────────────────────────
      final systemInstruction = '''You are Nidra, a professional, empathetic, and highly knowledgeable AI sleep coach for the SnoreClinics app.
Your primary role is to help users deeply understand their sleep patterns, snoring data, and overall sleep health, and to guide them toward better sleep hygiene.

CORE COMPETENCIES & KNOWLEDGE:
- Snoring Mechanics: You know exactly why people snore (soft palate relaxation, nasal congestion, weight, alcohol relaxing throat muscles, back-sleeping gravity effects).
- Obstructive Sleep Apnea (OSA): You understand the AHI index, apnea risk factors, and the severe health impacts of untreated OSA (hypertension, fatigue, poor focus).
- CPAP & Treatments: You are knowledgeable about CPAP machines, oral appliances, positional therapy, and myofunctional (throat/tongue) exercises.
- Lifestyle Impact: You know how caffeine, alcohol, stress, late meals, and screen time negatively affect REM and Deep sleep cycles.

BEHAVIOR & TONE:
1. Warm & Empathetic: Validate the user's struggles with sleep. Be encouraging and supportive.
2. Clinical yet Accessible: Explain complex medical concepts (like REM sleep or apnea) in simple, easy-to-understand terms.
3. Proactive & Investigative: Do not just answer the question and stop. ALWAYS ask a relevant follow-up question to dig deeper into the root cause of their snoring or sleep issues. (e.g., "Did you happen to sleep on your back last night?", "Have you noticed if your snoring is worse after a glass of wine?", or "Do you wake up feeling rested?")
4. Hyper-Personalized: ALWAYS use the user's provided data (BMI, journal entries, sleep scores, snoring duration) to give specific, tailored advice rather than generic tips. Mention their data explicitly.
5. Structured Responses: Use Markdown (**bolding**, bullet points, headers) to make your responses easy to skim. Use emojis sparingly but effectively.
6. Professional Referral: When relevant, or if the user shows signs of high apnea risk, recommend visiting https://snoreclinics.org/ for professional evaluation.
7. Address the user by their name when available.

$profileContext

$sessionContext

$journalContext

$historyContext

$fewShotExamples

CRITICAL RULE: You must append the following exact sentence to the very end of your response for any medical, diagnostic, or treatment-related questions:
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
    // Smart offline fallback — provides context-aware responses without the API.
    final lc = msg.toLowerCase();
    String response;

    if (r != null) {
      // Personalised responses based on available sleep data.
      final snoreMin = r.snoringDuration.inMinutes;
      final score = r.qualityScore.toInt();
      final risk = r.apneaRiskLevel;

      if (lc.contains('snor') || lc.contains('snore')) {
        response = snoreMin == 0
            ? "Great news — your last session showed **no significant snoring**! 🎉 Your airway stayed clear. Keep up whatever you did before bed — it\'s clearly working.\n\nWould you like tips on maintaining this? Or are you curious about what factors usually trigger snoring?"
            : snoreMin < 20
                ? "Your last session recorded **mild snoring** ($snoreMin minutes). This is common and not immediately alarming, but it\'s worth monitoring.\n\n**Quick wins for tonight:**\n- Try sleeping on your side\n- Skip alcohol for 4 hours before bed\n- Try a nasal strip if you feel congested\n\nDid you sleep on your back last night? That\'s the most common trigger for mild snoring. 🛌\n\n*I am an AI, please consult a doctor for a professional diagnosis.*"
                : "Your last session flagged **heavy snoring** ($snoreMin minutes — ${r.snoringPercentage.toStringAsFixed(0)}% of your night). Your Apnea Risk is currently **$risk**.\n\n**I\'d recommend:**\n1. Sleeping strictly on your side\n2. Elevating your head by 4+ inches\n3. Avoiding alcohol entirely on weeknights\n4. Practising throat exercises daily\n\nIf this persists, a professional sleep study is strongly advised. Visit **snoreclinics.org** for expert evaluation.\n\n*I am an AI, please consult a doctor for a professional diagnosis.*";
      } else if (lc.contains('apnea') || lc.contains('apnoea') || lc.contains('stop breathing')) {
        response = "Based on your last session, your Apnea Risk is **$risk**.\n\nObstructive Sleep Apnea happens when your airway **completely collapses** during sleep, causing you to stop breathing for 10+ seconds. Warning signs include:\n- Loud snoring with pauses\n- Waking up gasping\n- Extreme daytime fatigue\n- Morning headaches\n\nYour snoring data (${r.snoringEventCount} events in your last session) is a meaningful signal.${risk == 'High' ? ' **Your High risk level warrants a professional evaluation.** Please visit snoreclinics.org.' : ''}\n\nHave you ever woken up gasping for air? 🤔\n\n*I am an AI, please consult a doctor for a professional diagnosis.*";
      } else if (lc.contains('score') || lc.contains('quality') || lc.contains('how was') || lc.contains('last night')) {
        final label = score >= 80 ? 'Excellent 🌟' : score >= 60 ? 'Fair 🌙' : 'Poor 😴';
        response = "Your last sleep session scored **$score/100** — $label\n\n**Breakdown:**\n- Snoring: $snoreMin minutes\n- Apnea Risk: $risk\n- Sleep: ${r.totalDuration.inHours}h ${r.totalDuration.inMinutes % 60}m\n\n${score >= 80 ? 'That\'s a strong recovery night! Would you like to know what drove that great score?' : score >= 60 ? 'A decent night, but there\'s room to improve. The biggest factor was your ${snoreMin > 10 ? "snoring duration" : "sleep staging"}.' : 'This was a rough night. Let\'s work backwards — do you remember anything unusual about yesterday evening?'}";
      } else if (lc.contains('cpap') || lc.contains('machine') || lc.contains('device')) {
        response = "**CPAP (Continuous Positive Airway Pressure)** therapy is the gold standard treatment for Obstructive Sleep Apnea. 🏆\n\nHere\'s how it works:\n- A mask worn over your nose/mouth delivers a constant gentle stream of pressurised air.\n- This air acts as a **pneumatic splint**, keeping your airway open all night.\n- Most people see dramatic improvement in snoring, energy, and focus within the first week.\n\n**Common concerns:**\n- 😟 *\'It looks uncomfortable\'* — Modern CPAP masks are lightweight and come in many styles (nasal pillows, full face, nasal cradle).\n- 😟 *\'I can\'t sleep with it on\'* — There\'s a 2–4 week adjustment period. Most people can\'t imagine sleeping without it afterwards.\n\nWould you like to know if CPAP might be right for you based on your snoring data? 🤔\n\n*I am an AI, please consult a doctor for a professional diagnosis.*";
      } else {
        response = "Hi! I\'m Nidra, your AI sleep coach. 😊 Your last sleep session gave you a score of **$score/100** with **$snoreMin minutes of snoring**.\n\nI\'m here to help you understand your snoring, improve your sleep, and answer any questions about sleep apnea or sleep hygiene.\n\nWhat would you like to explore? You could ask me:\n- *Why do I snore?*\n- *What does my sleep score mean?*\n- *How can I stop snoring tonight?*\n- *What is sleep apnea?*";
      }
    } else {
      // No sleep data at all.
      if (lc.contains('snor')) {
        response = "Snoring occurs when the soft tissue in your throat **vibrates** as relaxed muscles partially block your airway during sleep.\n\n**Top causes:**\n- Sleeping on your back\n- Alcohol before bed\n- Nasal congestion\n- Excess weight around the neck\n- Airway anatomy\n\nOnce you record your first sleep session, I can give you **personalised** insights based on your actual snoring data! 🎤\n\nWould you like to know how to start your first recording?";
      } else {
        response = "Hi! I\'m Nidra, your personal AI sleep coach from SnoreClinics. 😊\n\nI can help you understand:\n- 🌙 Your sleep stages and quality\n- 📊 Your snoring patterns and causes\n- 😴 How to treat snoring and sleep apnea\n- 💡 Lifestyle changes that dramatically improve sleep\n\nRecord your first sleep session tonight, and I\'ll give you a full personalised analysis! In the meantime, feel free to ask me anything about snoring or sleep health.";
      }
    }

    for (final chunk in response.split(' ')) {
      yield '$chunk ';
      await Future.delayed(const Duration(milliseconds: 25));
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
