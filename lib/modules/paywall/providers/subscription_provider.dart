import 'package:flutter/foundation.dart';

import '../../../../core/services/firestore_service.dart';
import '../models/subscription_plan.dart';
import '../services/payment_service.dart';

enum PaymentState { idle, processing, success, failed }

class SubscriptionProvider extends ChangeNotifier {
  final PaymentService _service = PaymentService();

  PlanTier _currentTier = PlanTier.free;
  DateTime? _expiryDate;
  PaymentState _paymentState = PaymentState.idle;
  String? _errorMessage;
  SubscriptionPlan? _pendingPlan;
  String? _uid;

  // ── Getters ──────────────────────────────────────────────
  PlanTier get currentTier => _currentTier;
  bool get isPremium => _currentTier != PlanTier.free;
  DateTime? get expiryDate => _expiryDate;
  PaymentState get paymentState => _paymentState;
  String? get errorMessage => _errorMessage;

  SubscriptionPlan get currentPlan {
    switch (_currentTier) {
      case PlanTier.monthly:
        return Plans.monthly;
      case PlanTier.annual:
        return Plans.annual;
      case PlanTier.free:
        return Plans.free;
    }
  }

  // ── Init ─────────────────────────────────────────────────

  Future<void> init(String uid) async {
    _uid = uid;
    _service.init();
    _service.onDemoSuccess = _onDemoSuccess;
    await _loadSaved();
  }

  Future<void> _loadSaved() async {
    if (_uid == null) return;
    
    // 1. Check Firestore as the source of truth
    try {
      final profile = await FirestoreService.getProfile(_uid!);
      if (profile != null) {
        if (profile.isPremium) {
           _currentTier = profile.subscriptionTier == 'annual' ? PlanTier.annual : PlanTier.monthly;
           _expiryDate = profile.subscriptionExpiry;
           
           // If expired in firestore, clean it up
           if (_expiryDate != null && DateTime.now().isAfter(_expiryDate!)) {
             _currentTier = PlanTier.free;
             _expiryDate = null;
             await FirestoreService.updateSubscriptionStatus(_uid!, false, 'free', null);
           } else {
             notifyListeners();
             return; // Successfully loaded from Firestore
           }
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionProvider] Error fetching profile: $e');
    }

    // 2. Fallback to local SharedPreferences
    final result = await _service.loadSubscription();
    _currentTier = result.tier;
    _expiryDate = result.expiry;
    
    // If local has premium, sync it UP to firestore
    if (_currentTier != PlanTier.free) {
       await FirestoreService.updateSubscriptionStatus(_uid!, true, _currentTier.name, _expiryDate);
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  // ── Public API ───────────────────────────────────────────

  void startPurchase({
    required SubscriptionPlan plan,
    String? userEmail,
    String? userPhone,
  }) {
    _pendingPlan = plan;
    _paymentState = PaymentState.processing;
    _errorMessage = null;
    notifyListeners();

    _service.openCheckout(
      plan: plan,
      userEmail: userEmail,
      userPhone: userPhone,
    );
  }

  Future<void> restorePurchase() async {
    await _loadSaved();
  }

  Future<void> cancelSubscription() async {
    await _service.clearSubscription();
    _currentTier = PlanTier.free;
    _expiryDate = null;
    if (_uid != null) {
      await FirestoreService.updateSubscriptionStatus(_uid!, false, 'free', null);
    }
    notifyListeners();
  }

  void resetPaymentState() {
    _paymentState = PaymentState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Callbacks ────────────────────────────────────────────

  void _onDemoSuccess() async {
    final plan = _pendingPlan;
    if (plan == null) return;

    await _service.saveSubscription(plan.tier);
    _currentTier = plan.tier;
    _expiryDate = plan.tier == PlanTier.annual
        ? DateTime.now().add(const Duration(days: 365))
        : DateTime.now().add(const Duration(days: 30));
        
    if (_uid != null) {
      await FirestoreService.updateSubscriptionStatus(_uid!, true, _currentTier.name, _expiryDate);
    }
    
    _paymentState = PaymentState.success;
    _pendingPlan = null;
    notifyListeners();
  }
}
