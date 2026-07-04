import 'package:flutter/material.dart';
import '../models/reward_models.dart';
import '../services/rewards_firestore_service.dart';
import '../services/earn_event_guard.dart';

class RewardsProvider extends ChangeNotifier {
  RewardsWallet? _wallet;
  List<LedgerEntry> _ledger = [];
  List<EarningRule> _rules = [];
  RewardsConfig _config = const RewardsConfig();
  bool _isLoading = false;
  String? _error;
  String? _currentUid;
  int? _lastEarnedPoints; // for UI animation

  // Getters
  RewardsWallet? get wallet => _wallet;
  List<LedgerEntry> get ledger => _ledger;
  List<EarningRule> get rules => _rules;
  RewardsConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RewardsTier get currentTier => _wallet?.tier ?? RewardsTier.bronze;
  int get balance => _wallet?.availableBalance ?? 0;
  int? get lastEarnedPoints => _lastEarnedPoints;

  /// Initialize rewards for a user
  Future<void> init(String uid) async {
    _currentUid = uid;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _wallet = await RewardsFirestoreService.getOrCreateWallet(uid);
      _rules = await RewardsFirestoreService.getEarningRules();
      _config = await RewardsFirestoreService.getConfig();
      _ledger = await RewardsFirestoreService.getLedger(uid);
      
      // Credit daily login
      await _creditDailyLogin(uid);
    } catch (e) {
      debugPrint('[Rewards] Init error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Earn points for an event. Returns the points earned, or null if skipped/failed.
  Future<int?> earn(String eventType, String sourceRefId, {String? description}) async {
    if (_currentUid == null) return null;
    
    // Client-side dedup
    if (!EarnEventGuard().tryEarn(sourceRefId)) {
      debugPrint('[Rewards] Duplicate earn blocked: $sourceRefId');
      return null;
    }

    try {
      final entry = await RewardsFirestoreService.earnPoints(
        uid: _currentUid!,
        eventType: eventType,
        sourceRefId: sourceRefId,
        description: description,
      );
      
      if (entry != null) {
        _ledger.insert(0, entry);
        _wallet = await RewardsFirestoreService.getOrCreateWallet(_currentUid!);
        _lastEarnedPoints = entry.points;
        notifyListeners();
        
        // Clear the animation flag after a delay
        Future.delayed(const Duration(seconds: 3), () {
          _lastEarnedPoints = null;
          try {
            notifyListeners();
          } catch (_) {}
        });
        
        return entry.points;
      }
    } catch (e) {
      debugPrint('[Rewards] Earn error: $e');
    }
    return null;
  }

  /// Lock points for a redemption
  Future<RedemptionRecord?> lockForRedemption(int points, String orderId) async {
    if (_currentUid == null) return null;
    try {
      final record = await RewardsFirestoreService.lockPoints(
        uid: _currentUid!,
        points: points,
        orderId: orderId,
      );
      if (record != null) {
        _wallet = await RewardsFirestoreService.getOrCreateWallet(_currentUid!);
        notifyListeners();
      }
      return record;
    } catch (e) {
      debugPrint('[Rewards] Lock error: $e');
      return null;
    }
  }

  /// Confirm a redemption
  Future<bool> confirmRedemption(String redemptionId) async {
    if (_currentUid == null) return false;
    final ok = await RewardsFirestoreService.confirmRedemption(_currentUid!, redemptionId);
    if (ok) {
      _wallet = await RewardsFirestoreService.getOrCreateWallet(_currentUid!);
      _ledger = await RewardsFirestoreService.getLedger(_currentUid!);
      notifyListeners();
    }
    return ok;
  }

  /// Cancel a redemption (release locked points)
  Future<bool> cancelRedemption(String redemptionId) async {
    if (_currentUid == null) return false;
    final ok = await RewardsFirestoreService.cancelRedemption(_currentUid!, redemptionId);
    if (ok) {
      _wallet = await RewardsFirestoreService.getOrCreateWallet(_currentUid!);
      notifyListeners();
    }
    return ok;
  }

  Future<void> refreshWallet() async {
    if (_currentUid == null) return;
    _wallet = await RewardsFirestoreService.getOrCreateWallet(_currentUid!);
    _ledger = await RewardsFirestoreService.getLedger(_currentUid!);
    notifyListeners();
  }

  Future<void> _creditDailyLogin(String uid) async {
    final today = DateTime.now();
    final sourceRef = 'daily_login_${today.year}_${today.month}_${today.day}';
    await earn('daily_login', sourceRef, description: 'Daily login bonus');
  }

  void reset() {
    _currentUid = null;
    _wallet = null;
    _ledger = [];
    _rules = [];
    _config = const RewardsConfig();
    _isLoading = false;
    _error = null;
    _lastEarnedPoints = null;
    EarnEventGuard().clear();
    notifyListeners();
  }
}
