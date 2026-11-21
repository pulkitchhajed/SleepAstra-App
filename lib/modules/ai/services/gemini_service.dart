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
        model: 'gemini-1.5-flash',
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
        model: 'gemini-1.5-flash',
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
        model: 'gemini-3.6-flash',
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

      // ── 6. Build full system instruction ─────────────────────────
      final systemInstruction = '''You are Nidra, a professional, empathetic, and highly knowledgeable AI sleep coach for the SnoreClinics app.
Your primary role is to help users deeply understand their sleep patterns, snoring data, and overall sleep health, and to guide them toward better sleep hygiene.

CORE COMPETENCIES & KNOWLEDGE:
- Snoring Mechanics: You know exactly why people snore (soft palate relaxation, nasal congestion, weight, alcohol relaxing throat muscles, back-sleeping gravity effects).
- Obstructive Sleep Apnea (OSA): You understand the AHI index, apnea risk factors, and the severe health impacts of untreated OSA (hypertension, fatigue, poor focus).
- CPAP & Treatments: You are knowledgeable about CPAP machines, oral appliances, positional therapy, and myofunctional (throat/tongue) exercises.
- Lifestyle Impact: You know how caffeine, alcohol, stress, late meals, and screen time negatively affect REM and Deep sleep cycles.

BEHAVIOR & TONE:
1. Concise and Brief: ALWAYS keep your answers extremely concise. No more than 1-2 short sentences unless the user explicitly asks for a detailed explanation. This is critical for a fast, conversational flow.
2. Warm & Empathetic: Validate the user's struggles with sleep. Be encouraging and supportive.
3. Proactive & Investigative: If appropriate, ask a short, relevant follow-up question to dig deeper into the root cause of their snoring or sleep issues.
4. Hyper-Personalized: ALWAYS use the user's provided data (BMI, journal entries, sleep scores) to give specific, tailored advice.
5. Professional Referral: When relevant, or if the user shows signs of high apnea risk, recommend visiting https://snoreclinics.org/ for professional evaluation.

$profileContext

$sessionContext

$journalContext

$historyContext

CRITICAL RULE: You must append the following exact sentence to the very end of your response for any medical, diagnostic, or treatment-related questions:
"*I am an AI, please consult a doctor for a professional diagnosis.*"''';

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
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

      // History MUST start with a 'user' message according to Gemini API docs
      while (mergedHistory.isNotEmpty && mergedHistory.first['role'] != 'user') {
        mergedHistory.removeAt(0);
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
    final lc = msg.toLowerCase().trim();
    String response;

    if (r != null) {
      final snoreMin = r.snoringDuration.inMinutes;
      final score = r.qualityScore.toInt();
      final risk = r.apneaRiskLevel;
      final deepPct = (r.deepSleepPercent * 100).toInt();
      final remPct = (r.remSleepPercent * 100).toInt();
      final lightPct = (r.lightSleepPercent * 100).toInt();
      final awakePct = (100 - (deepPct + remPct + lightPct)).clamp(0, 100);
      final totalHours = r.totalDuration.inHours;
      final totalMins = r.totalDuration.inMinutes % 60;
      final events = r.snoringEventCount;
      final debt = r.sleepDebtHours;

      // 1. Deep Sleep Questions
      if (lc.contains('deep sleep') || lc.contains('deep') || lc.contains('slow wave')) {
        final status = deepPct >= 20 ? 'Optimal 🌟' : deepPct >= 13 ? 'Moderate 🌙' : 'Low ⚠️';
        response = "Your latest recording registered **$deepPct% Deep Sleep** ($status).\n\n"
            "Deep sleep (Stage 3 Slow-Wave Sleep) is your body's physical restorative phase: it triggers muscle repair, immune system regeneration, and cellular recovery. A healthy adult typically spends **15% to 25%** of the night in deep sleep.\n\n"
            "${deepPct < 15 ? '**How to boost your deep sleep tonight:**\n- ❄️ **Cooler bedroom:** Lower temperature to around 18–19°C (65–68°F).\n- ☕ **Early caffeine cutoff:** Zero caffeine within 8 hours of bedtime.\n- 🍷 **Skip alcohol:** Alcohol severely blunts slow-wave sleep cycles.' : 'Your deep sleep architecture looks strong! Maintaining consistent bedtimes will preserve this recovery.'}\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 2. REM Sleep Questions
      else if (lc.contains('rem') || lc.contains('dream') || lc.contains('cognitive') || lc.contains('memory')) {
        final status = remPct >= 20 ? 'Healthy 🧠' : 'Below Average 🌙';
        response = "In your last session, you logged **$remPct% REM Sleep** ($status).\n\n"
            "Rapid Eye Movement (REM) sleep is essential for emotional processing, creative problem solving, and memory consolidation. Most healthy adults average **20% to 25%** REM per night.\n\n"
            "REM occurs mostly in the second half of the night. If your total sleep duration was shortened (${totalHours}h ${totalMins}m), REM is the first stage compromised.\n\n"
            "**Key tip:** Giving yourself a full 7.5–8.5 hour sleep opportunity protects your final REM cycles.\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 3. Light Sleep / Awake / Sleep Architecture
      else if (lc.contains('light sleep') || lc.contains('awake') || lc.contains('woke up') || lc.contains('efficiency') || lc.contains('stage')) {
        response = "Here is your full **Sleep Stages Architecture** from your last session:\n\n"
            "- 🌊 **Deep Sleep:** $deepPct% (${(r.totalDuration.inMinutes * r.deepSleepPercent).toInt()} mins)\n"
            "- 🧠 **REM Sleep:** $remPct% (${(r.totalDuration.inMinutes * r.remSleepPercent).toInt()} mins)\n"
            "- 🍃 **Light Sleep:** $lightPct% (${(r.totalDuration.inMinutes * r.lightSleepPercent).toInt()} mins)\n"
            "- 👀 **Awake/Restless:** $awakePct% (${(r.totalDuration.inMinutes * (awakePct / 100)).toInt()} mins)\n\n"
            "${awakePct > 15 ? 'Your awake time was elevated. Frequent micro-awakenings are often caused by airway resistance, room temperature shifts, or late meals.' : 'Your sleep efficiency was high with minimal awakenings!'}\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 4. Snoring & Snore Clips
      else if (lc.contains('snor') || lc.contains('snore') || lc.contains('clip') || lc.contains('noise') || lc.contains('loud')) {
        final label = snoreMin == 0
            ? 'Quiet / No Snoring 🎉'
            : snoreMin < 15
                ? 'Mild Snoring 🟡'
                : snoreMin < 35
                    ? 'Moderate Snoring 🟠'
                    : 'Heavy Snoring 🔴';
        response = "Your last sleep session recorded **$snoreMin minutes of snoring** across **$events episodes** (${r.snoringPercentage.toStringAsFixed(1)}% of your night). Classification: **$label**.\n\n"
            "Snoring occurs when relaxed throat muscles and soft palate tissue vibrate against the airway during inhalation.\n\n"
            "**Immediate adjustments for tonight:**\n"
            "1. 🛌 **Positional therapy:** Sleep strictly on your side — back sleeping causes gravity to drop your tongue into the airway.\n"
            "2. 🛏️ **Elevation:** Elevate your head and torso by 30° or 4–6 inches.\n"
            "3. 👃 **Nasal patency:** Use a saline rinse or nasal dilator strip if you have any congestion.\n"
            "4. 🚫 **Evening cutoff:** Zero alcohol or sedative medications within 4 hours of bedtime.\n\n"
            "${snoreMin >= 20 ? 'Because your snoring duration is significant, having a clinical screening via **snoreclinics.org** is strongly recommended.\n\n' : ''}"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 5. Apnea Risk & Breathing Interruptions
      else if (lc.contains('apnea') || lc.contains('apnoea') || lc.contains('ahi') || lc.contains('breath') || lc.contains('chok') || lc.contains('gasp') || lc.contains('oxygen')) {
        response = "Your analyzed **Sleep Apnea Risk Level is: $risk**.\n\n"
            "Obstructive Sleep Apnea (OSA) occurs when airway muscles collapse completely, halting airflow for 10 seconds or longer. Key signs include loud cyclic snoring, gasping for air, morning dry mouth, and unrefreshing sleep.\n\n"
            "In your session, we analyzed ${r.snoringEventCount} acoustic airway resistance events during your ${totalHours}h ${totalMins}m recording.\n\n"
            "${risk == 'High' ? '🚨 **Priority Recommendation:** A High risk rating means your airway is showing recurrent obstruction patterns. We strongly recommend visiting **snoreclinics.org** to discuss a home sleep apnea test (HST) with a sleep specialist.' : 'Your apnea risk is currently manageable. Continue tracking your sessions to monitor changes over time.'}\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 6. Sleep Score / Quality Questions
      else if (lc.contains('score') || lc.contains('quality') || lc.contains('how did i sleep') || lc.contains('how was my sleep') || lc.contains('last night') || lc.contains('analysis') || lc.contains('report') || lc.contains('summary') || lc.contains('results')) {
        final label = score >= 85 ? 'Excellent 🌟' : score >= 70 ? 'Good 👍' : score >= 50 ? 'Fair 🌙' : 'Needs Attention 😴';
        response = "### 🌙 Sleep Analysis Breakdown\n\n"
            "**Overall Sleep Score: $score/100** ($label)\n\n"
            "**Session Metrics:**\n"
            "- ⏱️ **Total Sleep Duration:** ${totalHours}h ${totalMins}m\n"
            "- 🌊 **Deep Sleep:** $deepPct% (${(r.totalDuration.inMinutes * r.deepSleepPercent).toInt()} min)\n"
            "- 🧠 **REM Sleep:** $remPct% (${(r.totalDuration.inMinutes * r.remSleepPercent).toInt()} min)\n"
            "- 🔊 **Snoring Duration:** $snoreMin mins ($events episodes)\n"
            "- 🫁 **Apnea Risk:** $risk\n"
            "- 📉 **Sleep Debt:** ${debt.toStringAsFixed(1)} hours behind goal\n\n"
            "**Primary Takeaway:** "
            "${score >= 80 ? 'Your sleep architecture is well balanced. Keep maintaining your pre-bed winddown routine!' : snoreMin > 20 ? 'Snoring and airway resistance were the primary factors lowering your score. Focus on side-sleeping tonight.' : 'Increasing total sleep duration will help clear your sleep debt and boost deep restorative sleep.'}\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 7. Sleep Debt / Duration / Target Goal
      else if (lc.contains('debt') || lc.contains('hours') || lc.contains('duration') || lc.contains('goal') || lc.contains('time')) {
        response = "Your latest recording clocked **$totalHours hours and $totalMins minutes**.\n\n"
            "Your calculated sleep debt is **${debt.toStringAsFixed(1)} hours** relative to your target sleep goal.\n\n"
            "**Sleep Debt Recovery Protocol:**\n"
            "- Avoid massive weekend sleep-ins (which disrupt your circadian clock).\n"
            "- Instead, go to bed **30–45 minutes earlier** for the next 3 consecutive nights.\n"
            "- An afternoon 20-minute power nap before 2:00 PM can help restore alertness without harming nighttime sleep pressure.\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 8. How to Improve Tonight / Recommendations
      else if (lc.contains('improve') || lc.contains('tonight') || lc.contains('tip') || lc.contains('better') || lc.contains('help') || lc.contains('advice') || lc.contains('what should i do')) {
        response = "### 💡 Your Personalized Action Plan for Tonight:\n\n"
            "Based on your latest session (Score: **$score/100**, Snoring: **${snoreMin}m**, Apnea Risk: **$risk**):\n\n"
            "1. 🛌 **Lateral Sleeping:** Place a pillow behind your back to prevent rolling onto your spine.\n"
            "2. 🌬️ **Airway Clearing:** Take a hot shower or use saline spray 15 minutes before bed.\n"
            "3. 🧊 **Cool Darkness:** Set bedroom to 18–19°C and dim all lights 45 minutes before sleep.\n"
            "4. 📱 **Digital Wind-Down:** Swap screens for reading or listen to a soothing track in our Wellness Hub.\n\n"
            "${risk == 'High' ? '⚠️ For ongoing airway concerns, visit **snoreclinics.org** for professional diagnostic guidance.\n\n' : ''}"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 9. CPAP & Medical Devices
      else if (lc.contains('cpap') || lc.contains('machine') || lc.contains('device') || lc.contains('mask') || lc.contains('mouthpiece') || lc.contains('oral appliance')) {
        response = "**Continuous Positive Airway Pressure (CPAP)** is the clinical gold standard for managing snoring and sleep apnea. 🏆\n\n"
            "- It delivers a gentle, continuous stream of filtered air through a mask to prevent throat tissues from collapsing.\n"
            "- Mandibular Advancement Devices (oral appliances) are another proven option that hold the lower jaw forward.\n\n"
            "Given your current Apnea Risk rating of **$risk** with **$snoreMin min of snoring**, consulting a specialist at **snoreclinics.org** can help identify if CPAP or an oral appliance is ideal for you.\n\n"
            "*I am an AI, please consult a doctor for a professional diagnosis.*";
      }
      // 10. Default contextual greeting with analysis metrics
      else {
        response = "Hi! I'm Nidra, your AI sleep coach. 🌙\n\n"
            "I've analyzed your latest session:\n"
            "- **Score:** $score/100\n"
            "- **Total Sleep:** ${totalHours}h ${totalMins}m\n"
            "- **Deep Sleep:** $deepPct% | **REM:** $remPct%\n"
            "- **Snoring:** $snoreMin mins ($risk Apnea Risk)\n\n"
            "You can ask me anything about your results:\n"
            "- *'Why was my deep sleep low?'*\n"
            "- *'How can I reduce my snoring tonight?'*\n"
            "- *'What does my apnea risk mean?'*\n"
            "- *'Explain my sleep score calculation.'*";
      }
    } else {
      // No report recorded yet
      if (lc.contains('snor')) {
        response = "Snoring occurs when air flow causes relaxed tissues in the back of your throat to vibrate. Key factors include sleeping position, congestion, alcohol, and airway anatomy.\n\nOnce you record a sleep session in Sleep Astra, I'll analyze your exact snoring minutes and decibel levels! 🎤";
      } else if (lc.contains('apnea')) {
        response = "Sleep Apnea is a condition where breathing repeatedly stops during sleep. Warning signs include loud chronic snoring, waking up gasping, and daytime fatigue.\n\nRecord a sleep session tonight and I will calculate your Apnea Risk Score automatically.";
      } else {
        response = "Hi! I'm Nidra, your AI sleep coach from SnoreClinics. 🌙\n\nI can answer questions on your sleep stages, snoring frequency, apnea risk, and sleep debt as soon as you record a session.\n\nStart your first sleep recording tonight from the **Record** tab, and I'll generate a personalized deep-dive analysis for you!";
      }
    }

    for (final chunk in response.split(' ')) {
      yield '$chunk ';
      await Future.delayed(const Duration(milliseconds: 20));
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

  Future<String> projectSleepQuality(JournalEntry entry) async {
    if (!_hasKey) return "Looking at your evening, expect a decent night's sleep!";
    
    final prompt = '''
You are Nidra, an AI sleep coach. Based on this evening journal entry, provide a 1-2 sentence friendly projection of how the user might sleep tonight and one tip.
Caffeine: ${entry.caffeineUnits} units
Alcohol: ${entry.alcoholUnits} units
Stress: ${entry.stressLevel}/10
Screen Time: ${entry.screenTimeHours}h
Worked Out: ${entry.workedOut ? 'Yes' : 'No'}
Meals before bed: ${entry.hoursBeforeBedMeal ?? 0}h
Notes: ${entry.notes}
''';

    try {
      final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Looks like a standard night ahead! Sleep well.";
    } catch (e) {
      return "Looks like a standard night ahead! Sleep well.";
    }
  }
}
