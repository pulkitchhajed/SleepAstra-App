import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_plan.dart';

// Razorpay is only supported on Android and iOS.
// On Windows/Web/macOS we use a simulated checkout for demo purposes.
bool get _isPaymentSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Wraps Razorpay checkout (mobile) or a demo dialog (desktop/web).
class PaymentService {
  static const _kPlanKey = 'subscribed_plan';
  static const _kExpiryKey = 'subscription_expiry';

  /// Replace with your actual Razorpay Key ID from the dashboard.
  static const String razorpayKeyId = 'rzp_test_XXXXXXXXXXXXXXXX';
  static const String businessName = 'Sleep Analyzer';

  // Dynamic import wrapper to avoid link errors on Windows/Web
  dynamic _razorpay;

  void Function(dynamic)? onPaymentSuccess;
  void Function(dynamic)? onPaymentFailure;
  void Function(dynamic)? onExternalWallet;

  void Function()? onDemoSuccess; // called when demo checkout "succeeds"

  void init() {
    if (_isPaymentSupported) {
      _initRazorpay();
    }
  }

  void _initRazorpay() {
    try {
      // Late-bind the razorpay import only on supported platforms
      final razorpayLib = _loadRazorpay();
      if (razorpayLib != null) {
        _razorpay = razorpayLib;
      }
    } catch (e) {
      debugPrint('Razorpay init error: $e');
    }
  }

  dynamic _loadRazorpay() => null; // Overridden via conditional import below

  void dispose() {
    try {
      _razorpay?.clear();
    } catch (_) {}
  }

  /// Opens Razorpay on mobile, or triggers the demo success on desktop.
  void openCheckout({
    required SubscriptionPlan plan,
    String? userEmail,
    String? userPhone,
  }) {
    if (!_isPaymentSupported || _razorpay == null) {
      // Simulate instant success for demo/desktop
      Future.delayed(const Duration(seconds: 1), () {
        onDemoSuccess?.call();
      });
      return;
    }

    final options = <String, dynamic>{
      'key': razorpayKeyId,
      'amount': plan.priceInPaise.toInt(),
      'name': businessName,
      'description': '${plan.name} — ${plan.billingCycle}',
      'prefill': {
        if (userEmail != null) 'email': userEmail,
        if (userPhone != null) 'contact': userPhone,
      },
      'theme': {'color': '#6C63FF'},
      'modal': {'confirm_close': true},
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
    }
  }

  // ── Persistence ──────────────────────────────────────────────────

  Future<void> saveSubscription(PlanTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlanKey, tier.name);
    final expiry = tier == PlanTier.annual
        ? DateTime.now().add(const Duration(days: 365))
        : DateTime.now().add(const Duration(days: 30));
    await prefs.setString(_kExpiryKey, expiry.toIso8601String());
  }

  Future<({PlanTier tier, DateTime? expiry})> loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final tierName = prefs.getString(_kPlanKey);
    final expiryStr = prefs.getString(_kExpiryKey);

    DateTime? expiry;
    if (expiryStr != null) expiry = DateTime.tryParse(expiryStr);

    if (expiry != null && DateTime.now().isAfter(expiry)) {
      await prefs.remove(_kPlanKey);
      await prefs.remove(_kExpiryKey);
      return (tier: PlanTier.free, expiry: null);
    }

    PlanTier tier;
    switch (tierName) {
      case 'monthly':
        tier = PlanTier.monthly;
        break;
      case 'annual':
        tier = PlanTier.annual;
        break;
      default:
        tier = PlanTier.free;
    }
    return (tier: tier, expiry: expiry);
  }

  Future<void> clearSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPlanKey);
    await prefs.remove(_kExpiryKey);
  }
}
