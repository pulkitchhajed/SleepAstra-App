import 'dart:convert';
import 'package:uuid/uuid.dart';

enum JournalType { evening, morning }

/// Captures lifestyle and physiological factors for one sleep session.
class JournalEntry {
  final String id;
  final DateTime date;
  final JournalType type;

  // ── Evening factors ──────────────────────────────────────────
  final int caffeineUnits;      // 0–5
  final int alcoholUnits;       // 0–5
  final int stressLevel;        // 1–10
  final int? hoursBeforeBedMeal; // hours since last meal

  // ── Morning factors ──────────────────────────────────────────
  final int moodScore;          // 1–10 (1=terrible, 10=great)
  final String energyLevel;     // 'Low', 'Medium', 'High'
  final String sleepPosition;   // 'back', 'side', 'stomach'
  final bool hadCongestion;
  final String notes;

  const JournalEntry({
    required this.id,
    required this.date,
    required this.type,
    this.caffeineUnits = 0,
    this.alcoholUnits = 0,
    this.stressLevel = 5,
    this.hoursBeforeBedMeal,
    this.moodScore = 7,
    this.energyLevel = 'Medium',
    this.sleepPosition = 'side',
    this.hadCongestion = false,
    this.notes = '',
  });

  factory JournalEntry.newEvening() => JournalEntry(
    id: const Uuid().v4(),
    date: DateTime.now(),
    type: JournalType.evening,
  );

  factory JournalEntry.newMorning() => JournalEntry(
    id: const Uuid().v4(),
    date: DateTime.now(),
    type: JournalType.morning,
  );

  JournalEntry copyWith({
    int? caffeineUnits,
    int? alcoholUnits,
    int? stressLevel,
    int? hoursBeforeBedMeal,
    int? moodScore,
    String? energyLevel,
    String? sleepPosition,
    bool? hadCongestion,
    String? notes,
  }) {
    return JournalEntry(
      id: id,
      date: date,
      type: type,
      caffeineUnits: caffeineUnits ?? this.caffeineUnits,
      alcoholUnits: alcoholUnits ?? this.alcoholUnits,
      stressLevel: stressLevel ?? this.stressLevel,
      hoursBeforeBedMeal: hoursBeforeBedMeal ?? this.hoursBeforeBedMeal,
      moodScore: moodScore ?? this.moodScore,
      energyLevel: energyLevel ?? this.energyLevel,
      sleepPosition: sleepPosition ?? this.sleepPosition,
      hadCongestion: hadCongestion ?? this.hadCongestion,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'type': type.name,
    'caffeineUnits': caffeineUnits,
    'alcoholUnits': alcoholUnits,
    'stressLevel': stressLevel,
    'hoursBeforeBedMeal': hoursBeforeBedMeal,
    'moodScore': moodScore,
    'energyLevel': energyLevel,
    'sleepPosition': sleepPosition,
    'hadCongestion': hadCongestion,
    'notes': notes,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String? ?? const Uuid().v4(),
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    type: JournalType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => JournalType.evening,
    ),
    caffeineUnits: json['caffeineUnits'] as int? ?? 0,
    alcoholUnits: json['alcoholUnits'] as int? ?? 0,
    stressLevel: json['stressLevel'] as int? ?? 5,
    hoursBeforeBedMeal: json['hoursBeforeBedMeal'] as int?,
    moodScore: json['moodScore'] as int? ?? 7,
    energyLevel: json['energyLevel'] as String? ?? 'Medium',
    sleepPosition: json['sleepPosition'] as String? ?? 'side',
    hadCongestion: json['hadCongestion'] as bool? ?? false,
    notes: json['notes'] as String? ?? '',
  );

  static List<JournalEntry> listFromJson(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<JournalEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());
}
