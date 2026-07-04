import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../modules/onboarding/models/user_profile.dart';
import '../../modules/journal/models/journal_entry.dart';
import '../../modules/sleep_analysis/models/sleep_report.dart';

/// Central Firestore service for all SnoreClinics AI cloud data operations.
/// Uses a device-level UID (no login required) scoped under /users/{uid}/.
class FirestoreService {
  static const _uidKey = 'device_uid';
  static final _db = FirebaseFirestore.instance;

  static String? _cachedUid;

  /// Returns only the local device-level UID for guest sessions.
  static Future<String> get deviceUid async {
    if (_cachedUid != null) return _cachedUid!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_uidKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_uidKey, id);
    }
    _cachedUid = id;
    return id;
  }

  /// Clears the in-memory UID cache and persistent guest ID. Must be called on sign-out.
  static Future<void> clearCache() async {
    _cachedUid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
  }

  // ─── Collection References ────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> _sleepReportsCol(String uid) {
    return _userDoc(uid).collection('sleep_reports');
  }

  static CollectionReference<Map<String, dynamic>> _journalCol(String uid) {
    return _userDoc(uid).collection('journal_entries');
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  /// Saves or updates the user profile document.
  static Future<void> saveProfile(String uid, UserProfile profile) async {
    try {
      final doc = _userDoc(uid);
      await doc.set({
        ...profile.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror to email-based collection for recovery/failover
      if (profile.email != null && profile.email!.isNotEmpty) {
        await _db.collection('profiles_by_email').doc(profile.email!.toLowerCase()).set({
          ...profile.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLinkedUid': uid,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[Firestore] saveProfile error: $e');
    }
  }

  /// Explicitly saves the email address to Firestore and the recovery collection.
  static Future<void> saveEmail(String uid, String email) async {
    if (email.isEmpty) return;
    try {
      final emailLower = email.toLowerCase();
      // 1. Save to primary user doc
      await _userDoc(uid).set({
        'email': emailLower,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Save to recovery collection (master key)
      await _db.collection('profiles_by_email').doc(emailLower).set({
        'email': emailLower,
        'lastLinkedUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('[Firestore] Hard-saved email master key: $emailLower');
    } catch (e) {
      debugPrint('[Firestore] saveEmail error: $e');
    }
  }

  /// Gets the user profile, or creates a new one if it doesn't exist.
  /// Also guarantees the email is updated if provided.
  /// NEW: Uses email-based failover if UID lookup fails.
  static Future<UserProfile?> getOrCreateProfile(String uid, {String? email}) async {
    try {
      final doc = _userDoc(uid);
      final snap = await doc.get();
      
      UserProfile? profile;
      final String? normalizedEmail = (email != null && email.isNotEmpty) ? email.toLowerCase() : null;

      if (!snap.exists) {
        // FAILOVER: Check if a profile exists under this email address
        if (normalizedEmail != null) {
          final emailDoc = _db.collection('profiles_by_email').doc(normalizedEmail);
          final emailSnap = await emailDoc.get();
          if (emailSnap.exists && emailSnap.data() != null) {
            final emailData = emailSnap.data()!;
            debugPrint('[Firestore] Found email-based failover for $normalizedEmail. Migrating to UID $uid.');
            profile = UserProfile.fromJson(emailData);
            // Ensure the profile has the correct email and link it to this UID
            profile = profile.copyWith(email: normalizedEmail);
            doc.set({
              ...profile.toJson(),
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((e) => debugPrint('[Firestore] failover profile set error: $e'));

            // DATA RECOVERY: Migrate sub-collections from the last known UID
            final oldUid = emailData['lastLinkedUid'] as String?;
            if (oldUid != null && oldUid != uid) {
              debugPrint('[Firestore] Recovering historical data from old UID: $oldUid');
              // Reuse existing migration logic for reports and journals
              _migrateSubCollections(oldUid, uid).catchError((e) => debugPrint('[Firestore] sub-collection migration error: $e'));
            }
          }
        }

        if (profile == null) {
          // Create new profile with the provided email
          profile = UserProfile(
            name: '',
            email: email,
            age: 25,
            gender: 'other',
            weightKg: 70,
            heightCm: 170,
            bedtime: '22:30',
            wakeTime: '06:30',
            goalDurationMinutes: 480,
            onboardingComplete: false,
          );
          doc.set({
            ...profile.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }).catchError((e) => debugPrint('[Firestore] profile set error: $e'));
        }
      } else {
        // Document exists, update email if provided and missing
        final data = snap.data()!;
        if (normalizedEmail != null) {
          final existingEmail = (data['email'] as String?);
          if (existingEmail == null || existingEmail.isEmpty || existingEmail != normalizedEmail) {
            data['email'] = normalizedEmail;
            doc.set({'email': normalizedEmail}, SetOptions(merge: true));
            debugPrint('[Firestore] Updated missing/different email for UID $uid: $normalizedEmail');
          }
        }
        profile = UserProfile.fromJson(data);
      }

      // SECONDARY PERSISTENCE: Always save a copy to the email-based collection for recovery
      // We don't await this so it doesn't block startup while waiting for server ack.
      if (profile.email != null && profile.email!.isNotEmpty) {
        final emailKey = profile.email!.toLowerCase();
        _db.collection('profiles_by_email').doc(emailKey).set({
          ...profile.toJson(),
          'email': emailKey, // Force normalized email in the doc
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLinkedUid': uid,
        }, SetOptions(merge: true)).catchError((e) => debugPrint('[Firestore] failover profile update error: $e'));
      }
      
      return profile;
    } catch (e, stackTrace) {
      debugPrint('CRITICAL [Firestore] getOrCreateProfile error: $e');
      debugPrint('CRITICAL [Firestore] stackTrace: $stackTrace');
      rethrow;
    }
  }

  static Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = _userDoc(uid);
      final snap = await doc.get();
      if (!snap.exists || snap.data() == null) return null;
      return UserProfile.fromJson(snap.data()!);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the user's subscription status.
  static Future<void> updateSubscriptionStatus(String uid, bool isPremium, String tier, DateTime? expiry) async {
    try {
      final doc = _userDoc(uid);
      final updateData = <String, dynamic>{
        'isPremium': isPremium,
        'subscriptionTier': tier,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (expiry != null) {
        updateData['subscriptionExpiry'] = expiry.toIso8601String();
      }
      
      await doc.set(updateData, SetOptions(merge: true));

      // Also mirror to email collection if we can fetch the profile email
      final snap = await doc.get();
      if (snap.exists && snap.data() != null) {
        final email = snap.data()!['email'] as String?;
        if (email != null && email.isNotEmpty) {
           await _db.collection('profiles_by_email').doc(email.toLowerCase()).set(
             updateData, SetOptions(merge: true)
           );
        }
      }
    } catch (e) {
      debugPrint('[Firestore] updateSubscriptionStatus error: $e');
    }
  }

  // ─── Sleep Reports ────────────────────────────────────────────────────────

  /// Saves a sleep report to Firestore. Uses recordedAt timestamp as document ID.
  static Future<void> saveReport(String uid, SleepReport report) async {
    final col = _sleepReportsCol(uid);
    final docId = report.recordedAt.millisecondsSinceEpoch.toString();

    // Compress amplitudeTimeline to stay under Firestore 1 MB doc limit without downsampling
    final timelinePoints = report.amplitudeTimeline.map((s) => s.toJson()).toList();
    final timelineBytes = utf8.encode(jsonEncode(timelinePoints));
    final timelineCompressed = gzip.encode(timelineBytes);
    final timelineBase64 = base64Encode(timelineCompressed);

    // Compress snoringEvents as well, since 24 hours of snoring events can be massive
    final snoringEventsList = report.snoringEvents.map((e) => {
      'timestampMs': e.timestamp.inMilliseconds,
      'amplitude': e.amplitude,
      'durationMs': e.duration.inMilliseconds,
    }).toList();
    final eventsBytes = utf8.encode(jsonEncode(snoringEventsList));
    final eventsCompressed = gzip.encode(eventsBytes);
    final eventsBase64 = base64Encode(eventsCompressed);

    await col.doc(docId).set({
      'fileName': report.fileName,
      'recordedAt': Timestamp.fromDate(report.recordedAt),
      'totalDurationMs': report.totalDuration.inMilliseconds,
      'snoringDurationMs': report.snoringDuration.inMilliseconds,
      'snoringEventCount': report.snoringEventCount,
      'qualityScore': report.qualityScore,
      'quality': report.quality.name,
      'snoringEvents': eventsBase64,
      'amplitudeTimeline': timelineBase64,
      'insights': report.insights
          .map((i) => {
                'title': i.title,
                'description': i.description,
                'emoji': i.emoji,
              })
          .toList(),
      'sleepDebtHours': report.sleepDebtHours,
      'lightSleepPercent': report.lightSleepPercent,
      'deepSleepPercent': report.deepSleepPercent,
      'remSleepPercent': report.remSleepPercent,
      'apneaRiskLevel': report.apneaRiskLevel,
      'cpapUsageDurationMs': report.cpapUsageDuration.inMilliseconds,
      'apneaHypopneaIndex': report.apneaHypopneaIndex,
      'detectedApneaEvents': report.detectedApneaEvents.map((e) => {
        'timestampMs': e.timestamp.inMilliseconds,
        'gapDurationMs': e.gapDuration.inMilliseconds,
        'type': e.type.name,
        'peakRecoveryAmplitude': e.peakRecoveryAmplitude,
        'confidence': e.confidence,
      }).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'snoreAudioClips': report.snoreAudioClips.map((c) => c.toJson()).toList(),
    });
  }

  /// Saves AI analysis results onto an existing sleep report document.
  static Future<void> saveAiAnalysis({
    required String uid,
    required DateTime reportedAt,
    required int aiScore,
    required String aiRecommendation,
    required List<String> aiLifestyleFactors,
  }) async {
    try {
      final col = _sleepReportsCol(uid);
      final docId = reportedAt.millisecondsSinceEpoch.toString();
      await col.doc(docId).update({
        'aiScore': aiScore,
        'aiRecommendation': aiRecommendation,
        'aiLifestyleFactors': aiLifestyleFactors,
      });
    } catch (e) {
      debugPrint('[Firestore] saveAiAnalysis error: $e');
    }
  }

  /// Returns all sleep reports, sorted by date (newest first).
  static Future<List<SleepReport>> getAllReports(String uid) async {
    try {
      final col = _sleepReportsCol(uid);
      final snap = await col
          .orderBy('recordedAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => _mapToReport(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] getAllReports error: $e');
      return [];
    }
  }

  /// Deletes all sleep reports matching a specific timestamp.
  /// Uses both ID-based deletion and Query-based cleanup for ghost duplicates.
  static Future<void> deleteReport(String uid, DateTime recordedAt) async {
    try {
      final col = _sleepReportsCol(uid);
      
      // 1. Try fast deletion by ID (the modern way)
      final docId = recordedAt.millisecondsSinceEpoch.toString();
      await col.doc(docId).delete();

      // 2. Query for ANY duplicates matching that exact time (ghost cleanup)
      final snapshots = await col
          .where('recordedAt', isEqualTo: Timestamp.fromDate(recordedAt))
          .get();

      for (final doc in snapshots.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('[Firestore] deleteReport error: $e');
    }
  }

  // ─── Journal Entries ──────────────────────────────────────────────────────

  /// Saves a new journal entry.
  static Future<void> saveJournalEntry(String uid, JournalEntry entry) async {
    try {
      final col = _journalCol(uid);
      await col.doc(entry.id).set({
        ...entry.toJson(),
        'date': Timestamp.fromDate(entry.date),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Firestore] saveJournalEntry error: $e');
    }
  }

  /// Returns all journal entries, sorted newest first.
  static Future<List<JournalEntry>> getJournalEntries(String uid) async {
    try {
      final col = _journalCol(uid);
      final snap = await col
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        // Convert Firestore Timestamp → ISO string for fromJson
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        }
        return JournalEntry.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] getJournalEntries error: $e');
      return [];
    }
  }

  /// Deletes a journal entry by its ID.
  static Future<void> deleteJournalEntry(String uid, String id) async {
    try {
      final col = _journalCol(uid);
      await col.doc(id).delete();
    } catch (e) {
      debugPrint('[Firestore] deleteJournalEntry error: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static SleepReport _mapToReport(Map<String, dynamic> data) {
    final recordedAt = data['recordedAt'] is Timestamp
        ? (data['recordedAt'] as Timestamp).toDate()
        : DateTime.parse(data['recordedAt'] as String);

    List<dynamic> eventsData = [];
    if (data['snoringEvents'] is String) {
      try {
        final decodedBytes = base64Decode(data['snoringEvents'] as String);
        final decompressed = gzip.decode(decodedBytes);
        eventsData = jsonDecode(utf8.decode(decompressed)) as List<dynamic>;
      } catch (e) {
        debugPrint('Error decoding snoring events: $e');
      }
    } else {
      eventsData = (data['snoringEvents'] as List?) ?? [];
    }

    List<dynamic> timelineData = [];
    if (data['amplitudeTimeline'] is String) {
      try {
        final decodedBytes = base64Decode(data['amplitudeTimeline'] as String);
        final decompressed = gzip.decode(decodedBytes);
        timelineData = jsonDecode(utf8.decode(decompressed)) as List<dynamic>;
      } catch (e) {
        debugPrint('Error decoding timeline: $e');
      }
    } else {
      timelineData = (data['amplitudeTimeline'] as List?) ?? [];
    }

    return SleepReport(
      fileName: data['fileName'] as String? ?? '',
      recordedAt: recordedAt,
      totalDuration: Duration(milliseconds: (data['totalDurationMs'] as num?)?.toInt() ?? 0),
      snoringDuration: Duration(milliseconds: (data['snoringDurationMs'] as num?)?.toInt() ?? 0),
      snoringEventCount: (data['snoringEventCount'] as num?)?.toInt() ?? 0,
      qualityScore: (data['qualityScore'] as num?)?.toDouble() ?? 0.0,
      quality: SleepQuality.values.firstWhere(
        (q) => q.name == data['quality'],
        orElse: () => SleepQuality.good,
      ),
      snoringEvents: eventsData
          .map((e) => SnoringEvent(
                timestamp: Duration(milliseconds: (e['timestampMs'] as num).toInt()),
                amplitude: (e['amplitude'] as num).toDouble(),
                duration: Duration(milliseconds: (e['durationMs'] as num).toInt()),
              ))
          .toList(),
      amplitudeTimeline: timelineData
          .map((s) => AmplitudeSample.fromJson(s as Map<String, dynamic>))
          .toList(),
      insights: (data['insights'] as List?)
              ?.map((i) => SleepInsight(
                    title: i['title'] as String? ?? '',
                    description: i['description'] as String? ?? '',
                    emoji: i['emoji'] as String? ?? '',
                  ))
              .toList() ??
          [],
      sleepDebtHours: (data['sleepDebtHours'] as num?)?.toDouble() ?? 0.0,
      lightSleepPercent: (data['lightSleepPercent'] as num?)?.toDouble() ?? 0.50,
      deepSleepPercent: (data['deepSleepPercent'] as num?)?.toDouble() ?? 0.25,
      remSleepPercent: (data['remSleepPercent'] as num?)?.toDouble() ?? 0.25,
      apneaRiskLevel: data['apneaRiskLevel'] as String? ?? 'Low',
      cpapUsageDuration: Duration(milliseconds: (data['cpapUsageDurationMs'] as num?)?.toInt() ?? (data['totalDurationMs'] as num?)?.toInt() ?? 0),
      apneaHypopneaIndex: (data['apneaHypopneaIndex'] as num?)?.toDouble() ?? 0.0,
      detectedApneaEvents: ((data['detectedApneaEvents'] as List?) ?? []).map((e) {
        return SuspectedApneaEvent(
          timestamp: Duration(milliseconds: (e['timestampMs'] as num?)?.toInt() ?? 0),
          gapDuration: Duration(milliseconds: (e['gapDurationMs'] as num?)?.toInt() ?? 0),
          type: ApneaEventType.values.firstWhere(
            (t) => t.name == e['type'],
            orElse: () => ApneaEventType.breathingPause,
          ),
          peakRecoveryAmplitude: (e['peakRecoveryAmplitude'] as num?)?.toDouble() ?? 0.0,
          confidence: (e['confidence'] as num?)?.toDouble() ?? 0.5,
        );
      }).toList(),
      snoreAudioClips: (data['snoreAudioClips'] as List?)?.map((c) => SnoreAudioClip.fromJson(c as Map<String, dynamic>)).toList() ?? [],
    );
  }
  /// Migrates data from a guest UID to an authenticated UID.
  /// SAFETY: Only runs if the guestUid is a local device UUID (not a Firebase Auth UID).
  /// This prevents cross-account data contamination when switching between Google accounts.
  static Future<void> migrateGuestData(String guestUid, String authUid, {String? email}) async {
    // GUARD: Firebase Auth UIDs are 28-char alphanumeric. Local UUIDs have dashes.
    // Never migrate from one Firebase Auth UID to another.
    if (!guestUid.contains('-')) {
      debugPrint('[Firestore] Skipping migration: guestUid $guestUid looks like an auth UID, not a device UUID.');
      return;
    }

    // GUARD: Don't migrate if this guest device has no profile (nothing to move)
    final guestDoc = _db.collection('users').doc(guestUid);
    final guestSnap = await guestDoc.get();
    if (!guestSnap.exists) {
      debugPrint('[Firestore] Skipping migration: no guest data found for $guestUid.');
      return;
    }

    try {
      final authDoc = _db.collection('users').doc(authUid);
      final authSnap = await authDoc.get();

      // 1. Migrate Profile (only if auth user has no profile yet)
      if (!authSnap.exists) {
        if (guestSnap.data() != null) {
          final data = Map<String, dynamic>.from(guestSnap.data()!);
          // Inject the email from the auth provider if it's not in the guest data
          final existingEmail = data['email'] as String?;
          if (email != null && (existingEmail == null || existingEmail.isEmpty)) {
            data['email'] = email;
          }
          await authDoc.set(data, SetOptions(merge: false));
        }
      } else {
        debugPrint('[Firestore] Auth profile $authUid already exists. Skipping profile copy, but migrating sub-collections.');
      }

      // 2. Migrate sub-collections (reports, journals)
      await _migrateSubCollections(guestUid, authUid);

      // 3. Delete the old guest profile to prevent data leaking into future accounts
      await guestDoc.delete();
      debugPrint('[Firestore] Migration complete: $guestUid -> $authUid');
    } catch (e) {
      debugPrint('[Firestore] Migration error: $e');
    }
  }

  /// Internal helper to copy sub-collections from one UID to another.
  static Future<void> _migrateSubCollections(String oldUid, String newUid) async {
    final oldDoc = _userDoc(oldUid);
    final newDoc = _userDoc(newUid);

    // 1. Migrate Sleep Reports
    final reportsSnap = await oldDoc.collection('sleep_reports').get();
    for (var doc in reportsSnap.docs) {
      await newDoc.collection('sleep_reports').doc(doc.id).set(doc.data());
    }

    // 2. Migrate Journal Entries
    final journalSnap = await oldDoc.collection('journal_entries').get();
    for (final doc in journalSnap.docs) {
      await newDoc.collection('journal_entries').doc(doc.id).set(doc.data());
    }
    
    debugPrint('[Firestore] Sub-collections migrated: $oldUid -> $newUid');
  }
}

