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
    age: 25,
    gender: 'other',
    weightKg: 70,
    heightCm: 170,
    bedtime: '22:30',
    wakeTime: '06:30',
    goalDurationMinutes: 480,
    onboardingComplete: false,
  );

  String? _currentUid;
  bool _initialized = false;
  UserProfile get profile => _profile;
  bool get isComplete => _profile.onboardingComplete;
  bool get isInitialized => _initialized;

  /// Returns the display label for the current auth provider.
  /// Use this in your UI to show "Pulled from your Google account" etc.
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

    // Resolve email from all possible sources in priority order:
    // 1. Explicitly passed userEmail argument
    // 2. Firebase Auth current user's email (covers Google + email/password)
    // 3. Firebase Auth providerData (fallback for federated providers)
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

      // EMAIL RECOVERY: Inject email from auth if profile is missing it.
      if ((_profile.email == null || _profile.email!.isEmpty) &&
          resolvedEmail != null) {
        debugPrint('[Onboarding] Injecting missing email: $resolvedEmail');
        _profile = _profile.copyWith(email: resolvedEmail);
        saveProfile(uid);
      }

      // EMAIL SYNC: If the auth email changed, keep the profile in sync.
      if (resolvedEmail != null &&
          _profile.email != null &&
          _profile.email!.isNotEmpty &&
          _profile.email != resolvedEmail) {
        debugPrint('[Onboarding] Email changed in Auth, syncing: '
            '${_profile.email} → $resolvedEmail');
        _profile = _profile.copyWith(email: resolvedEmail);
        saveProfile(uid);
      }

      // AUTO-HEAL: If the profile has essential data but the completion flag is false
      if (!_profile.onboardingComplete &&
          _profile.name.isNotEmpty &&
          _profile.age > 0) {
        debugPrint('[Onboarding] Auto-healing: marking onboarding complete.');
        _profile = _profile.copyWith(onboardingComplete: true);
        saveProfile(uid);
      }
    }

    _updateReminders();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _updateReminders() async {
    final service = NotificationService();
    
    // Only request permissions if at least one reminder is enabled
    if (_profile.bedtimeReminderEnabled || _profile.morningPromptEnabled) {
      await service.requestPermissions();
    }
    
    service.cancelAll();

    if (_profile.bedtimeReminderEnabled) {
      try {
        final now = DateTime.now();
        final timeParts = _profile.bedtime.split(':');
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
        final timeParts = _profile.wakeTime.split(':');
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

  void updateName(String v) {
    _profile = _profile.copyWith(name: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateEmail(String v) {
    _profile = _profile.copyWith(email: v);
    if (_currentUid != null) {
      saveProfile(_currentUid!);
      // BULLETPROOF: Save the email explicitly to Firestore immediately as a master key
      FirestoreService.saveEmail(_currentUid!, v);
    }
    notifyListeners();
  }

  void updateAge(int v) {
    _profile = _profile.copyWith(age: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateGender(String v) {
    _profile = _profile.copyWith(gender: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateWeight(double v) {
    _profile = _profile.copyWith(weightKg: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateHeight(double v) {
    _profile = _profile.copyWith(heightCm: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateBedtime(String v) {
    _profile = _profile.copyWith(bedtime: v);
    _updateReminders();
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateWakeTime(String v) {
    _profile = _profile.copyWith(wakeTime: v);
    _updateReminders();
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateGoalDuration(int minutes) {
    _profile = _profile.copyWith(goalDurationMinutes: minutes);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateCaffeineCups(int v) {
    _profile = _profile.copyWith(caffeineCups: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateAlcoholDays(int v) {
    _profile = _profile.copyWith(alcoholDays: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateExerciseDays(int v) {
    _profile = _profile.copyWith(exerciseDays: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

  void updateStopBangScore(int v) {
    _profile = _profile.copyWith(stopBangScore: v);
    if (_currentUid != null) saveProfile(_currentUid!);
    notifyListeners();
  }

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
    _profile = _profile.copyWith(onboardingComplete: true);
    _updateReminders();
    if (_currentUid != null) {
      await saveProfile(_currentUid!);
    }
    notifyListeners();
  }

  Future<void> saveProfile(String uid) async {
    // PARANOID PROTECTION: Never save a profile without an email if the current Firebase user has one.
    if (_profile.email == null || _profile.email!.isEmpty) {
      final authEmail = FirebaseAuth.instance.currentUser?.email;
      if (authEmail != null && authEmail.isNotEmpty) {
        debugPrint('[Onboarding] saveProfile: Injecting missing email from Auth: $authEmail');
        _profile = _profile.copyWith(email: authEmail);
      }
    }
    await FirestoreService.saveProfile(uid, _profile);
    notifyListeners();
  }

  Future<void> clearProfile(String uid) async {
    _profile = const UserProfile(
      name: '', email: '', age: 25, gender: 'other',
      weightKg: 70, heightCm: 170,
      bedtime: '22:30', wakeTime: '06:30',
      goalDurationMinutes: 480, onboardingComplete: false,
      bedtimeReminderEnabled: true, morningPromptEnabled: true,
    );
    await FirestoreService.saveProfile(uid, _profile);
    notifyListeners();
  }

  void reset() {
    _currentUid = null;
    _profile = const UserProfile(
      name: '', email: '', age: 25, gender: 'other',
      weightKg: 70, heightCm: 170,
      bedtime: '22:30', wakeTime: '06:30',
      goalDurationMinutes: 480, onboardingComplete: false,
      bedtimeReminderEnabled: true, morningPromptEnabled: true,
    );
    _initialized = false;
    notifyListeners();
  }
}
