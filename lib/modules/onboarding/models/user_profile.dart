import 'dart:convert';

class UserProfile {
  final String name;
  final String? email;
  final String dateOfBirth; // YYYY-MM-DD
  final String gender;
  final double weightKg;
  final double heightCm;
  final String bmiCategory;

  // Current Schedule
  final String currentBedtime;
  final String currentWakeTime;
  final double currentDurationHours;

  // Target Schedule
  final String targetBedtime;
  final String targetWakeTime;
  final double targetDurationHours;

  // Circadian
  final double sleepDebtHours;
  final double weeklySleepDebtHours;
  final String recommendedBedtime;
  final String recommendedWakeTime;
  final double recommendedDurationHours;
  final String transitionStrategy;

  // Goals & Assessment
  final List<String> primarySleepGoals;
  final int stopBangScore;
  final Map<String, bool> stopAnswers;

  // App State
  final bool complianceAccepted;
  final bool onboardingComplete;
  final bool bedtimeReminderEnabled;
  final bool morningPromptEnabled;
  final bool healthIntegrationEnabled;
  final int coins;
  final bool isPremium;
  final String subscriptionTier;
  final DateTime? subscriptionExpiry;

  const UserProfile({
    required this.name,
    this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    this.bmiCategory = 'Optimal',
    this.currentBedtime = '00:00',
    this.currentWakeTime = '06:30',
    this.currentDurationHours = 6.5,
    this.targetBedtime = '22:30',
    this.targetWakeTime = '07:00',
    this.targetDurationHours = 8.5,
    this.sleepDebtHours = 0.0,
    this.weeklySleepDebtHours = 0.0,
    this.recommendedBedtime = '22:30',
    this.recommendedWakeTime = '07:00',
    this.recommendedDurationHours = 8.5,
    this.transitionStrategy = '',
    this.primarySleepGoals = const [],
    this.stopBangScore = 0,
    this.stopAnswers = const {
      'snoring': false,
      'tiredness': false,
      'observed': false,
      'pressure': false,
    },
    this.complianceAccepted = false,
    this.onboardingComplete = false,
    this.bedtimeReminderEnabled = true,
    this.morningPromptEnabled = true,
    this.healthIntegrationEnabled = false,
    this.coins = 0,
    this.isPremium = false,
    this.subscriptionTier = 'free',
    this.subscriptionExpiry,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  /// Computed age from dateOfBirth (YYYY-MM-DD).
  int get age {
    try {
      final parts = dateOfBirth.split('-');
      final dob = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      int years = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
      return years < 0 ? 0 : years;
    } catch (_) {
      return 0;
    }
  }

  /// Alias — points to currentBedtime for legacy code.
  String get bedtime => currentBedtime;

  /// Alias — points to currentWakeTime for legacy code.
  String get wakeTime => currentWakeTime;

  /// Target sleep duration in minutes (from targetDurationHours).
  int get goalDurationMinutes => (targetDurationHours * 60).round();

  /// Alias — no longer collected, returns 0.
  int get caffeineCups => 0;

  /// Alias — no longer collected, returns 0.
  int get alcoholDays => 0;

  /// Alias — no longer collected, returns 0.
  int get exerciseDays => 0;

  /// Alias for sleepDebtHours.
  double get dailySleepDebtHours => sleepDebtHours;

  UserProfile copyWith({
    String? name,
    String? email,
    String? dateOfBirth,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? bmiCategory,
    String? currentBedtime,
    String? currentWakeTime,
    double? currentDurationHours,
    String? targetBedtime,
    String? targetWakeTime,
    double? targetDurationHours,
    double? sleepDebtHours,
    double? weeklySleepDebtHours,
    String? recommendedBedtime,
    String? recommendedWakeTime,
    double? recommendedDurationHours,
    String? transitionStrategy,
    List<String>? primarySleepGoals,
    int? stopBangScore,
    Map<String, bool>? stopAnswers,
    bool? complianceAccepted,
    bool? onboardingComplete,
    bool? bedtimeReminderEnabled,
    bool? morningPromptEnabled,
    bool? healthIntegrationEnabled,
    int? coins,
    bool? isPremium,
    String? subscriptionTier,
    DateTime? subscriptionExpiry,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bmiCategory: bmiCategory ?? this.bmiCategory,
      currentBedtime: currentBedtime ?? this.currentBedtime,
      currentWakeTime: currentWakeTime ?? this.currentWakeTime,
      currentDurationHours: currentDurationHours ?? this.currentDurationHours,
      targetBedtime: targetBedtime ?? this.targetBedtime,
      targetWakeTime: targetWakeTime ?? this.targetWakeTime,
      targetDurationHours: targetDurationHours ?? this.targetDurationHours,
      sleepDebtHours: sleepDebtHours ?? this.sleepDebtHours,
      weeklySleepDebtHours: weeklySleepDebtHours ?? this.weeklySleepDebtHours,
      recommendedBedtime: recommendedBedtime ?? this.recommendedBedtime,
      recommendedWakeTime: recommendedWakeTime ?? this.recommendedWakeTime,
      recommendedDurationHours: recommendedDurationHours ?? this.recommendedDurationHours,
      transitionStrategy: transitionStrategy ?? this.transitionStrategy,
      primarySleepGoals: primarySleepGoals ?? this.primarySleepGoals,
      stopBangScore: stopBangScore ?? this.stopBangScore,
      stopAnswers: stopAnswers ?? this.stopAnswers,
      complianceAccepted: complianceAccepted ?? this.complianceAccepted,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      bedtimeReminderEnabled: bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      morningPromptEnabled: morningPromptEnabled ?? this.morningPromptEnabled,
      healthIntegrationEnabled: healthIntegrationEnabled ?? this.healthIntegrationEnabled,
      coins: coins ?? this.coins,
      isPremium: isPremium ?? this.isPremium,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'bmiCategory': bmiCategory,
      'currentBedtime': currentBedtime,
      'currentWakeTime': currentWakeTime,
      'currentDurationHours': currentDurationHours,
      'targetBedtime': targetBedtime,
      'targetWakeTime': targetWakeTime,
      'targetDurationHours': targetDurationHours,
      'sleepDebtHours': sleepDebtHours,
      'weeklySleepDebtHours': weeklySleepDebtHours,
      'recommendedBedtime': recommendedBedtime,
      'recommendedWakeTime': recommendedWakeTime,
      'recommendedDurationHours': recommendedDurationHours,
      'transitionStrategy': transitionStrategy,
      'primarySleepGoals': primarySleepGoals,
      'stopBangScore': stopBangScore,
      'stopAnswers': stopAnswers,
      'complianceAccepted': complianceAccepted,
      'onboardingComplete': onboardingComplete,
      'bedtimeReminderEnabled': bedtimeReminderEnabled,
      'morningPromptEnabled': morningPromptEnabled,
      'healthIntegrationEnabled': healthIntegrationEnabled,
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
    dateOfBirth: json['dateOfBirth'] as String? ?? '1995-01-01',
    gender: json['gender'] as String? ?? 'other',
    weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
    bmiCategory: json['bmiCategory'] as String? ?? 'Optimal',
    currentBedtime: json['currentBedtime'] as String? ?? '00:00',
    currentWakeTime: json['currentWakeTime'] as String? ?? '06:30',
    currentDurationHours: (json['currentDurationHours'] as num?)?.toDouble() ?? 6.5,
    targetBedtime: json['targetBedtime'] as String? ?? '22:30',
    targetWakeTime: json['targetWakeTime'] as String? ?? '07:00',
    targetDurationHours: (json['targetDurationHours'] as num?)?.toDouble() ?? 8.5,
    sleepDebtHours: (json['sleepDebtHours'] as num?)?.toDouble() ?? 0.0,
    weeklySleepDebtHours: (json['weeklySleepDebtHours'] as num?)?.toDouble() ?? 0.0,
    recommendedBedtime: json['recommendedBedtime'] as String? ?? '22:30',
    recommendedWakeTime: json['recommendedWakeTime'] as String? ?? '07:00',
    recommendedDurationHours: (json['recommendedDurationHours'] as num?)?.toDouble() ?? 8.5,
    transitionStrategy: json['transitionStrategy'] as String? ?? '',
    primarySleepGoals: (json['primarySleepGoals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    stopBangScore: (json['stopBangScore'] as num?)?.toInt() ?? 0,
    stopAnswers: (json['stopAnswers'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as bool? ?? false),
        ) ?? {
      'snoring': false,
      'tiredness': false,
      'observed': false,
      'pressure': false,
    },
    complianceAccepted: json['complianceAccepted'] as bool? ?? false,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    bedtimeReminderEnabled: json['bedtimeReminderEnabled'] as bool? ?? true,
    morningPromptEnabled: json['morningPromptEnabled'] as bool? ?? true,
    healthIntegrationEnabled: json['healthIntegrationEnabled'] as bool? ?? false,
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
