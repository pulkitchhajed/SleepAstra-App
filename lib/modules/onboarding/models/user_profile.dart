import 'dart:convert';

/// Represents a user's baseline health profile and sleep goals.
class UserProfile {
  final String name;
  final String? email;
  final int age;
  final String gender; // 'male', 'female', 'other'
  final double weightKg;
  final double heightCm;
  final String bedtime;   // "HH:mm" 24h format e.g. "22:30"
  final String wakeTime;  // "HH:mm" 24h format e.g. "06:30"
  final int goalDurationMinutes;
  final bool complianceAccepted;
  final bool onboardingComplete;
  final bool bedtimeReminderEnabled;
  final bool morningPromptEnabled;
  final bool healthIntegrationEnabled;
  // Lifestyle & Clinical
  final int caffeineCups;
  final int alcoholDays;
  final int exerciseDays;
  final int stopBangScore;
  final int coins;
  // Subscription
  final bool isPremium;
  final String subscriptionTier; // 'free', 'monthly', 'annual'
  final DateTime? subscriptionExpiry;

  const UserProfile({
    required this.name,
    this.email,
    required this.age,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.bedtime,
    required this.wakeTime,
    required this.goalDurationMinutes,
    this.complianceAccepted = false,
    this.onboardingComplete = false,
    this.bedtimeReminderEnabled = true,
    this.morningPromptEnabled = true,
    this.healthIntegrationEnabled = false,
    this.caffeineCups = 0,
    this.alcoholDays = 0,
    this.exerciseDays = 0,
    this.stopBangScore = 0,
    this.coins = 0,
    this.isPremium = false,
    this.subscriptionTier = 'free',
    this.subscriptionExpiry,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  UserProfile copyWith({
    String? name,
    String? email,
    int? age,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? bedtime,
    String? wakeTime,
    int? goalDurationMinutes,
    bool? complianceAccepted,
    bool? onboardingComplete,
    bool? bedtimeReminderEnabled,
    bool? morningPromptEnabled,
    bool? healthIntegrationEnabled,
    int? caffeineCups,
    int? alcoholDays,
    int? exerciseDays,
    int? stopBangScore,
    int? coins,
    bool? isPremium,
    String? subscriptionTier,
    DateTime? subscriptionExpiry,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      goalDurationMinutes: goalDurationMinutes ?? this.goalDurationMinutes,
      complianceAccepted: complianceAccepted ?? this.complianceAccepted,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      bedtimeReminderEnabled: bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      morningPromptEnabled: morningPromptEnabled ?? this.morningPromptEnabled,
      healthIntegrationEnabled: healthIntegrationEnabled ?? this.healthIntegrationEnabled,
      caffeineCups: caffeineCups ?? this.caffeineCups,
      alcoholDays: alcoholDays ?? this.alcoholDays,
      exerciseDays: exerciseDays ?? this.exerciseDays,
      stopBangScore: stopBangScore ?? this.stopBangScore,
      coins: coins ?? this.coins,
      isPremium: isPremium ?? this.isPremium,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'age': age,
      'gender': gender,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'bedtime': bedtime,
      'wakeTime': wakeTime,
      'goalDurationMinutes': goalDurationMinutes,
      'complianceAccepted': complianceAccepted,
      'onboardingComplete': onboardingComplete,
      'bedtimeReminderEnabled': bedtimeReminderEnabled,
      'morningPromptEnabled': morningPromptEnabled,
      'healthIntegrationEnabled': healthIntegrationEnabled,
      'caffeineCups': caffeineCups,
      'alcoholDays': alcoholDays,
      'exerciseDays': exerciseDays,
      'stopBangScore': stopBangScore,
      'coins': coins,
      'isPremium': isPremium,
      'subscriptionTier': subscriptionTier,
    };
    if (email != null && email!.isNotEmpty) data['email'] = email;
    if (subscriptionExpiry != null) {
      data['subscriptionExpiry'] = subscriptionExpiry!.toIso8601String();
    }
    return data;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    age: (json['age'] as num?)?.toInt() ?? 25,
    gender: json['gender'] as String? ?? 'other',
    weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
    bedtime: json['bedtime'] as String? ?? '22:30',
    wakeTime: json['wakeTime'] as String? ?? '06:30',
    goalDurationMinutes: (json['goalDurationMinutes'] as num?)?.toInt() ?? 480,
    complianceAccepted: json['complianceAccepted'] as bool? ?? false,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    bedtimeReminderEnabled: json['bedtimeReminderEnabled'] as bool? ?? true,
    morningPromptEnabled: json['morningPromptEnabled'] as bool? ?? true,
    healthIntegrationEnabled: json['healthIntegrationEnabled'] as bool? ?? false,
    caffeineCups: (json['caffeineCups'] as num?)?.toInt() ?? 0,
    alcoholDays: (json['alcoholDays'] as num?)?.toInt() ?? 0,
    exerciseDays: (json['exerciseDays'] as num?)?.toInt() ?? 0,
    stopBangScore: (json['stopBangScore'] as num?)?.toInt() ?? 0,
    coins: (json['coins'] as num?)?.toInt() ?? 0,
    isPremium: json['isPremium'] as bool? ?? false,
    subscriptionTier: json['subscriptionTier'] as String? ?? 'free',
    subscriptionExpiry: json['subscriptionExpiry'] != null 
        ? DateTime.tryParse(json['subscriptionExpiry'] as String) 
        : null,
  );

  static UserProfile? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
