import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/reward_models.dart';

class RewardsFirestoreService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _walletDoc(String uid) {
    return _db.collection('users').doc(uid).collection('rewards_wallet').doc('current');
  }

  static CollectionReference<Map<String, dynamic>> _ledgerCol(String uid) {
    return _db.collection('users').doc(uid).collection('rewards_ledger');
  }

  static DocumentReference<Map<String, dynamic>> _rulesDoc() {
    return _db.collection('rewards_config').doc('rules');
  }

  static DocumentReference<Map<String, dynamic>> _settingsDoc() {
    return _db.collection('rewards_config').doc('settings');
  }

  static final List<EarningRule> _defaultRules = [
    const EarningRule(ruleId: 'sleep_log_complete', eventType: 'sleep_log_complete', basePoints: 30, maxPerDay: 1, description: 'Complete a sleep recording', emoji: '🛏️'),
    const EarningRule(ruleId: 'journal_entry', eventType: 'journal_entry', basePoints: 15, maxPerDay: 2, description: 'Write a journal entry', emoji: '📓'),
    const EarningRule(ruleId: 'meditation_session', eventType: 'meditation_session', basePoints: 20, maxPerDay: 2, description: 'Complete a meditation session', emoji: '🧘'),
    const EarningRule(ruleId: 'daily_login', eventType: 'daily_login', basePoints: 5, maxPerDay: 1, description: 'Open the app daily', emoji: '✅'),
    const EarningRule(ruleId: 'streak_milestone', eventType: 'streak_milestone', basePoints: 50, maxPerDay: -1, description: 'Reach a streak milestone', emoji: '🔥'),
    const EarningRule(ruleId: 'profile_complete', eventType: 'profile_complete', basePoints: 100, maxPerDay: 1, maxPerUser: 1, description: 'Complete your profile', emoji: '👤'),
    const EarningRule(ruleId: 'goal_achieved', eventType: 'goal_achieved', basePoints: 25, maxPerDay: 1, description: 'Achieve a sleep goal', emoji: '🎯'),
  ];

  static Future<RewardsWallet> getOrCreateWallet(String uid) async {
    try {
      final doc = _walletDoc(uid);
      final snap = await doc.get();
      if (!snap.exists) {
        final wallet = RewardsWallet.empty(uid);
        await doc.set(wallet.toJson());
        return wallet;
      }
      return RewardsWallet.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('[RewardsFirestore] getOrCreateWallet error: $e');
      return RewardsWallet.empty(uid);
    }
  }

  static Future<List<LedgerEntry>> getLedger(String uid, {int limit = 50}) async {
    try {
      final snap = await _ledgerCol(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => LedgerEntry.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('[RewardsFirestore] getLedger error: $e');
      return [];
    }
  }

  static Future<List<EarningRule>> getEarningRules() async {
    try {
      final doc = _rulesDoc();
      final snap = await doc.get();
      if (!snap.exists) {
        // Seed default rules
        final rulesMapList = _defaultRules.map((r) => r.toJson()).toList();
        await doc.set({'rules': rulesMapList});
        return _defaultRules;
      }
      final data = snap.data()!;
      final rulesData = data['rules'] as List<dynamic>? ?? [];
      return rulesData.map((r) => EarningRule.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[RewardsFirestore] getEarningRules error: $e');
      return _defaultRules;
    }
  }

  static Future<RewardsConfig> getConfig() async {
    try {
      final doc = _settingsDoc();
      final snap = await doc.get();
      if (!snap.exists) {
        const config = RewardsConfig();
        await doc.set(config.toJson());
        return config;
      }
      return RewardsConfig.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('[RewardsFirestore] getConfig error: $e');
      return const RewardsConfig();
    }
  }

  static Future<LedgerEntry?> earnPoints({
    required String uid,
    required String eventType,
    required String sourceRefId,
    String? description,
  }) async {
    try {
      return await _db.runTransaction((transaction) async {
        final entryDoc = _ledgerCol(uid).doc(sourceRefId);
        final entrySnap = await transaction.get(entryDoc);
        if (entrySnap.exists) {
          debugPrint('[RewardsFirestore] Entry already exists for $sourceRefId');
          return null; // Idempotency check
        }

        final rules = await getEarningRules(); // Outside transaction to keep simple, could cache this
        final rule = rules.firstWhere(
          (r) => r.eventType == eventType && r.isCurrentlyValid,
          orElse: () => EarningRule(ruleId: 'unknown', eventType: eventType, basePoints: 0, isActive: false),
        );

        if (!rule.isActive || rule.basePoints == 0) return null;

        // Note: For a robust system, daily limits should be checked here by querying the ledger.
        // For simplicity in this transaction, we'll proceed and rely on client-side limits mostly
        // or a more complex query setup later.

        final walletDoc = _walletDoc(uid);
        final walletSnap = await transaction.get(walletDoc);
        
        int currentBalance = 0;
        int lifetimeEarned = 0;
        RewardsTier currentTier = RewardsTier.bronze;

        if (walletSnap.exists) {
          final w = RewardsWallet.fromJson(walletSnap.data()!);
          currentBalance = w.availableBalance;
          lifetimeEarned = w.lifetimeEarned;
          currentTier = w.tier;
        }

        final pointsToEarn = (rule.effectivePoints * currentTier.multiplier).round();

        final newBalance = currentBalance + pointsToEarn;
        final newLifetimeEarned = lifetimeEarned + pointsToEarn;
        final newTier = RewardsTier.fromLifetimePoints(newLifetimeEarned);

        final now = DateTime.now();
        final entry = LedgerEntry(
          transactionId: entryDoc.id,
          userId: uid,
          eventType: eventType,
          points: pointsToEarn,
          balanceAfter: newBalance,
          sourceRefId: sourceRefId,
          description: description ?? rule.description,
          createdAt: now,
        );

        transaction.set(entryDoc, entry.toJson());

        final updatedWallet = RewardsWallet(
          userId: uid,
          availableBalance: newBalance,
          lockedBalance: walletSnap.exists ? walletSnap.data()!['lockedBalance'] as int? ?? 0 : 0,
          lifetimeEarned: newLifetimeEarned,
          lifetimeRedeemed: walletSnap.exists ? walletSnap.data()!['lifetimeRedeemed'] as int? ?? 0 : 0,
          tier: newTier,
          updatedAt: now,
        );

        transaction.set(walletDoc, updatedWallet.toJson(), SetOptions(merge: true));

        return entry;
      });
    } catch (e) {
      debugPrint('[RewardsFirestore] earnPoints error: $e');
      return null;
    }
  }

  static Future<RedemptionRecord?> lockPoints({
    required String uid,
    required int points,
    required String orderId,
  }) async {
    try {
      return await _db.runTransaction((transaction) async {
        final walletDoc = _walletDoc(uid);
        final walletSnap = await transaction.get(walletDoc);
        
        if (!walletSnap.exists) return null;
        
        final wallet = RewardsWallet.fromJson(walletSnap.data()!);
        
        if (wallet.availableBalance < points) {
          return null; // Insufficient funds
        }

        final config = await getConfig();

        final updatedWallet = wallet.copyWith(
          availableBalance: wallet.availableBalance - points,
          lockedBalance: wallet.lockedBalance + points,
          updatedAt: DateTime.now(),
        );

        transaction.set(walletDoc, updatedWallet.toJson(), SetOptions(merge: true));

        final redemptionDoc = _db.collection('users').doc(uid).collection('redemptions').doc();
        final record = RedemptionRecord(
          redemptionId: redemptionDoc.id,
          userId: uid,
          pointsUsed: points,
          cashEquivalent: config.pointsToRupees(points),
          orderId: orderId,
          conversionRate: config.conversionRate,
          createdAt: DateTime.now(),
        );

        transaction.set(redemptionDoc, record.toJson());

        return record;
      });
    } catch (e) {
      debugPrint('[RewardsFirestore] lockPoints error: $e');
      return null;
    }
  }

  static Future<bool> confirmRedemption(String uid, String redemptionId) async {
    try {
      await _db.runTransaction((transaction) async {
        final redemptionDoc = _db.collection('users').doc(uid).collection('redemptions').doc(redemptionId);
        final redemptionSnap = await transaction.get(redemptionDoc);

        if (!redemptionSnap.exists) throw Exception('Redemption not found');
        final record = RedemptionRecord.fromJson(redemptionSnap.data()!);

        if (record.status != RedemptionStatus.initiated) throw Exception('Redemption already processed');

        final walletDoc = _walletDoc(uid);
        final walletSnap = await transaction.get(walletDoc);
        final wallet = RewardsWallet.fromJson(walletSnap.data()!);

        final updatedWallet = wallet.copyWith(
          lockedBalance: wallet.lockedBalance - record.pointsUsed,
          lifetimeRedeemed: wallet.lifetimeRedeemed + record.pointsUsed,
          updatedAt: DateTime.now(),
        );

        transaction.set(walletDoc, updatedWallet.toJson(), SetOptions(merge: true));
        transaction.update(redemptionDoc, {'status': RedemptionStatus.completed.name});

        final entryDoc = _ledgerCol(uid).doc('redeem_$redemptionId');
        final entry = LedgerEntry(
          transactionId: entryDoc.id,
          userId: uid,
          eventType: 'redemption_completed',
          points: -record.pointsUsed, // Negative points for spending
          balanceAfter: updatedWallet.availableBalance,
          sourceRefId: redemptionId,
          description: 'Points redeemed for order ${record.orderId ?? ""}',
          createdAt: DateTime.now(),
        );

        transaction.set(entryDoc, entry.toJson());
      });
      return true;
    } catch (e) {
      debugPrint('[RewardsFirestore] confirmRedemption error: $e');
      return false;
    }
  }

  static Future<bool> cancelRedemption(String uid, String redemptionId) async {
    try {
      await _db.runTransaction((transaction) async {
        final redemptionDoc = _db.collection('users').doc(uid).collection('redemptions').doc(redemptionId);
        final redemptionSnap = await transaction.get(redemptionDoc);

        if (!redemptionSnap.exists) throw Exception('Redemption not found');
        final record = RedemptionRecord.fromJson(redemptionSnap.data()!);

        if (record.status != RedemptionStatus.initiated) throw Exception('Redemption already processed');

        final walletDoc = _walletDoc(uid);
        final walletSnap = await transaction.get(walletDoc);
        final wallet = RewardsWallet.fromJson(walletSnap.data()!);

        final updatedWallet = wallet.copyWith(
          lockedBalance: wallet.lockedBalance - record.pointsUsed,
          availableBalance: wallet.availableBalance + record.pointsUsed,
          updatedAt: DateTime.now(),
        );

        transaction.set(walletDoc, updatedWallet.toJson(), SetOptions(merge: true));
        transaction.update(redemptionDoc, {'status': RedemptionStatus.failed.name});
      });
      return true;
    } catch (e) {
      debugPrint('[RewardsFirestore] cancelRedemption error: $e');
      return false;
    }
  }
}
