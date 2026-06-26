import 'package:flutter/foundation.dart';

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

  Future<void> init() async {
    _service.init();
    _service.onDemoSuccess = _onDemoSuccess;
    await _loadSaved();
  }

  Future<void> _loadSaved() async {
    final result = await _service.loadSubscription();
    _currentTier = result.tier;
    _expiryDate = result.expiry;
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
    _paymentState = PaymentState.success;
    _pendingPlan = null;
    notifyListeners();
  }
}
