import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/notification_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

class OnboardingProvider extends ChangeNotifier {
  UserProfile _profile = const UserProfile(
    name: '',
    email: '',
    dateOfBirth: '1995-01-01',
    gender: 'other',
    weightKg: 70,
    heightCm: 170,
    currentBedtime: '00:00',
    currentWakeTime: '06:30',
    targetBedtime: '22:30',
    targetWakeTime: '07:00',
    onboardingComplete: false,
  );

  String? _currentUid;
  bool _initialized = false;
  UserProfile get profile => _profile;
  bool get isComplete => _profile.onboardingComplete;
  bool get isInitialized => _initialized;

  /// Returns the display label for the current auth provider.
  String get authProviderLabel {
    final providers = FirebaseAuth.instance.currentUser?.providerData
            .map((p) => p.providerId)
            .toList() ??
        [];
    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('password')) return 'Email';
    if (providers.contains('phone')) return 'Phone';
    return 'your';
  }

  Future<void> loadProfile(String uid, {String? userEmail}) async {
    _currentUid = uid;
    UserProfile? loaded;

    final authUser = FirebaseAuth.instance.currentUser;
    final resolvedEmail = userEmail ??
        authUser?.email ??
        authUser?.providerData
            .map((p) => p.email)
            .where((e) => e != null && e.isNotEmpty)
            .firstOrNull;

    debugPrint('[Onboarding] Resolved email: $resolvedEmail '
        '(provider: ${authUser?.providerData.map((p) => p.providerId).join(", ")})');

    try {
      loaded = await FirestoreService.getOrCreateProfile(uid, email: resolvedEmail);
    } catch (e) {
      debugPrint('Skipping profile overwrite due to parse error.');
      _initialized = true;
      notifyListeners();
      return;
    }

    if (loaded != null) {
      _profile = loaded;

      if ((_profile.email == null || _profile.email!.isEmpty) &&
          resolvedEmail != null) {
        debugPrint('[Onboarding] Injecting missing email: $resolvedEmail');
        _profile = _profile.copyWith(email: resolvedEmail);
        saveProfile(uid);
      }

      if (resolvedEmail != null &&
          _profile.email != null &&
          _profile.email!.isNotEmpty &&
          _profile.email != resolvedEmail) {
        debugPrint('[Onboarding] Email changed in Auth, syncing: '
            '${_profile.email} → $resolvedEmail');
        _profile = _profile.copyWith(email: resolvedEmail);
        saveProfile(uid);
      }
    }

    _updateReminders();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _updateReminders() async {
    final service = NotificationService();
    
    if (_profile.bedtimeReminderEnabled || _profile.morningPromptEnabled) {
      await service.requestPermissions();
    }
    
    service.cancelAll();

    if (_profile.bedtimeReminderEnabled) {
      try {
        final now = DateTime.now();
        final timeParts = _profile.targetBedtime.split(':');
        final bedtime = DateTime(
          now.year, now.month, now.day,
          int.parse(timeParts[0]), int.parse(timeParts[1]),
        );
        service.scheduleBedtimeReminder(bedtime);
      } catch (e) {
        debugPrint('Error scheduling bedtime reminder: $e');
      }
    }

    if (_profile.morningPromptEnabled) {
      try {
        final now = DateTime.now();
        final timeParts = _profile.targetWakeTime.split(':');
        final wakeTime = DateTime(
          now.year, now.month, now.day,
          int.parse(timeParts[0]), int.parse(timeParts[1]),
        );
        service.scheduleMorningPrompt(wakeTime);
      } catch (e) {
        debugPrint('Error scheduling morning prompt: $e');
      }
    }
  }

  // --- Profile Field Updaters ---

  void updateName(String v) {
    _profile = _profile.copyWith(name: v);
    notifyListeners();
  }

  void updateDateOfBirth(String v) {
    _profile = _profile.copyWith(dateOfBirth: v);
    notifyListeners();
  }

  void updateGender(String v) {
    _profile = _profile.copyWith(gender: v);
    notifyListeners();
  }

  void updateWeight(double v) {
    _profile = _profile.copyWith(weightKg: v);
    notifyListeners();
  }

  void updateHeight(double v) {
    _profile = _profile.copyWith(heightCm: v);
    notifyListeners();
  }
  
  void updateBmiCategory(String category) {
    _profile = _profile.copyWith(bmiCategory: category);
    notifyListeners();
  }

  void updateCurrentSchedule(String bedtime, String wakeTime, double duration) {
    _profile = _profile.copyWith(
      currentBedtime: bedtime,
      currentWakeTime: wakeTime,
      currentDurationHours: duration,
    );
    notifyListeners();
  }

  void updateTargetSchedule(String bedtime, String wakeTime, double duration) {
    _profile = _profile.copyWith(
      targetBedtime: bedtime,
      targetWakeTime: wakeTime,
      targetDurationHours: duration,
    );
    _updateReminders();
    notifyListeners();
  }

  void updateCircadianRecommendations({
    required double sleepDebtHours,
    required double weeklySleepDebtHours,
    required String recommendedBedtime,
    required String recommendedWakeTime,
    required double recommendedDurationHours,
    required String transitionStrategy,
  }) {
    _profile = _profile.copyWith(
      sleepDebtHours: sleepDebtHours,
      weeklySleepDebtHours: weeklySleepDebtHours,
      recommendedBedtime: recommendedBedtime,
      recommendedWakeTime: recommendedWakeTime,
      recommendedDurationHours: recommendedDurationHours,
      transitionStrategy: transitionStrategy,
    );
    notifyListeners();
  }

  void updatePrimarySleepGoals(List<String> goals) {
    _profile = _profile.copyWith(primarySleepGoals: goals);
    notifyListeners();
  }

  void updateStopAnswers(Map<String, bool> answers, int score) {
    _profile = _profile.copyWith(stopAnswers: answers, stopBangScore: score);
    notifyListeners();
  }

  // --- End Profile Field Updaters ---

  void addCoins(int amount) {
    _profile = _profile.copyWith(coins: _profile.coins + amount);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateBedtimeReminder(bool v) {
    _profile = _profile.copyWith(bedtimeReminderEnabled: v);
    _updateReminders();
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateMorningPrompt(bool v) {
    _profile = _profile.copyWith(morningPromptEnabled: v);
    _updateReminders();
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  Future<void> toggleHealthIntegration(bool enabled) async {
    if (enabled) {
      final success = await HealthService().requestPermissions();
      if (!success) return;
    }
    _profile = _profile.copyWith(healthIntegrationEnabled: enabled);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _profile = _profile.copyWith(onboardingComplete: true, complianceAccepted: true);
    _updateReminders();
    if (_currentUid != null) {
      await saveProfile(_currentUid!);
    }
    notifyListeners();
  }

  Future<void> saveProfile(String uid) async {
    if (_profile.email == null || _profile.email!.isEmpty) {
      final authEmail = FirebaseAuth.instance.currentUser?.email;
      if (authEmail != null && authEmail.isNotEmpty) {
        _profile = _profile.copyWith(email: authEmail);
      }
    }
    await FirestoreService.saveProfile(uid, _profile);
    notifyListeners();
  }

  Future<void> clearProfile(String uid) async {
    _profile = const UserProfile(
      name: '', email: '', dateOfBirth: '1995-01-01', gender: 'other',
      weightKg: 70, heightCm: 170,
      currentBedtime: '00:00', currentWakeTime: '06:30',
      targetBedtime: '22:30', targetWakeTime: '07:00',
      complianceAccepted: false, onboardingComplete: false,
      bedtimeReminderEnabled: true, morningPromptEnabled: true,
    );
    await FirestoreService.saveProfile(uid, _profile);
    notifyListeners();
  }

  void reset() {
    _currentUid = null;
    _profile = const UserProfile(
      name: '', email: '', dateOfBirth: '1995-01-01', gender: 'other',
      weightKg: 70, heightCm: 170,
      currentBedtime: '00:00', currentWakeTime: '06:30',
      targetBedtime: '22:30', targetWakeTime: '07:00',
      complianceAccepted: false, onboardingComplete: false,
      bedtimeReminderEnabled: true, morningPromptEnabled: true,
    );
    _initialized = false;
    notifyListeners();
  }
}
