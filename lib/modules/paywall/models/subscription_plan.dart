enum PlanTier { free, monthly, annual }

class PlanFeature {
  final String name;
  final bool includedInFree;
  final bool includedInPremium;

  const PlanFeature({
    required this.name,
    required this.includedInFree,
    required this.includedInPremium,
  });
}

class SubscriptionPlan {
  final PlanTier tier;
  final String name;
  final String price;
  final String billingCycle;
  final String description;
  final String? badge;
  final String razorpayPlanId; // Set in Razorpay dashboard
  final double priceInPaise; // Razorpay uses smallest currency unit

  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.description,
    this.badge,
    required this.razorpayPlanId,
    required this.priceInPaise,
  });

  bool get isPremium => tier != PlanTier.free;
}

/// All available plans
class Plans {
  Plans._();

  static const free = SubscriptionPlan(
    tier: PlanTier.free,
    name: '7-Day Trial',
    price: '₹0',
    billingCycle: 'for 7 days',
    description: 'Experience all premium sleep tracking features initially',
    razorpayPlanId: '',
    priceInPaise: 0,
  );

  static const monthly = SubscriptionPlan(
    tier: PlanTier.monthly,
    name: 'Premium',
    price: '₹299',
    billingCycle: '/ month',
    description: 'Full analysis, unlimited history & insights after trial',
    razorpayPlanId: 'plan_monthly_sleep_premium', // replace with real ID
    priceInPaise: 29900,
  );

  static const annual = SubscriptionPlan(
    tier: PlanTier.annual,
    name: 'Premium Annual',
    price: '₹1,999',
    billingCycle: '/ year',
    description: 'Best value — 44% savings over monthly',
    badge: 'Best Value',
    razorpayPlanId: 'plan_annual_sleep_premium', // replace with real ID
    priceInPaise: 199900,
  );

  static const List<PlanFeature> features = [
    PlanFeature(
      name: 'Basic Sleep Report',
      includedInFree: true,
      includedInPremium: true,
    ),
    PlanFeature(
      name: 'Snoring Detection',
      includedInFree: true,
      includedInPremium: true,
    ),
    PlanFeature(
      name: '7-Day History',
      includedInFree: true,
      includedInPremium: true,
    ),
    PlanFeature(
      name: 'Detailed Amplitude Chart',
      includedInFree: false,
      includedInPremium: true,
    ),
    PlanFeature(
      name: 'AI Sleep Insights',
      includedInFree: false,
      includedInPremium: true,
    ),
    PlanFeature(
      name: 'Unlimited History',
      includedInFree: false,
      includedInPremium: true,
    ),

    PlanFeature(
      name: 'Sleep Trend Analysis',
      includedInFree: false,
      includedInPremium: true,
    ),
    PlanFeature(
      name: 'Priority Support',
      includedInFree: false,
      includedInPremium: true,
    ),
  ];
}
