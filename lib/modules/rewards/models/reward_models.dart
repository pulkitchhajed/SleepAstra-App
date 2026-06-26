import 'package:cloud_firestore/cloud_firestore.dart';

// ── Tier System ──────────────────────────────────────────────────────

enum RewardsTier {
  bronze(threshold: 0, multiplier: 1.0, label: 'Bronze', emoji: '🥉'),
  silver(threshold: 500, multiplier: 1.2, label: 'Silver', emoji: '🥈'),
  gold(threshold: 2000, multiplier: 1.5, label: 'Gold', emoji: '🥇'),
  platinum(threshold: 5000, multiplier: 2.0, label: 'Platinum', emoji: '💎');

  final int threshold;
  final double multiplier;
  final String label;
  final String emoji;
  const RewardsTier({required this.threshold, required this.multiplier, required this.label, required this.emoji});

  static RewardsTier fromLifetimePoints(int points) {
    if (points >= RewardsTier.platinum.threshold) return RewardsTier.platinum;
    if (points >= RewardsTier.gold.threshold) return RewardsTier.gold;
    if (points >= RewardsTier.silver.threshold) return RewardsTier.silver;
    return RewardsTier.bronze;
  }

  RewardsTier? get nextTier {
    final idx = RewardsTier.values.indexOf(this);
    if (idx < RewardsTier.values.length - 1) return RewardsTier.values[idx + 1];
    return null;
  }

  int get pointsToNextTier {
    final next = nextTier;
    return next?.threshold ?? threshold;
  }
}

// ── Earning Rule ─────────────────────────────────────────────────────

class EarningRule {
  final String ruleId;
  final String eventType;
  final int basePoints;
  final double multiplier;
  final int maxPerDay;
  final int maxPerUser; // -1 = unlimited
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool isActive;
  final String description;
  final String emoji;

  const EarningRule({
    required this.ruleId,
    required this.eventType,
    required this.basePoints,
    this.multiplier = 1.0,
    this.maxPerDay = -1,
    this.maxPerUser = -1,
    this.validFrom,
    this.validTo,
    this.isActive = true,
    this.description = '',
    this.emoji = '🪙',
  });

  int get effectivePoints => (basePoints * multiplier).round();

  bool get isCurrentlyValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validTo != null && now.isAfter(validTo!)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'ruleId': ruleId,
    'eventType': eventType,
    'basePoints': basePoints,
    'multiplier': multiplier,
    'maxPerDay': maxPerDay,
    'maxPerUser': maxPerUser,
    'validFrom': validFrom?.toIso8601String(),
    'validTo': validTo?.toIso8601String(),
    'isActive': isActive,
    'description': description,
    'emoji': emoji,
  };

  factory EarningRule.fromJson(Map<String, dynamic> json) => EarningRule(
    ruleId: json['ruleId'] as String? ?? '',
    eventType: json['eventType'] as String? ?? '',
    basePoints: (json['basePoints'] as num?)?.toInt() ?? 0,
    multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
    maxPerDay: (json['maxPerDay'] as num?)?.toInt() ?? -1,
    maxPerUser: (json['maxPerUser'] as num?)?.toInt() ?? -1,
    validFrom: json['validFrom'] != null ? DateTime.tryParse(json['validFrom'] as String) : null,
    validTo: json['validTo'] != null ? DateTime.tryParse(json['validTo'] as String) : null,
    isActive: json['isActive'] as bool? ?? true,
    description: json['description'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '🪙',
  );
}

// ── Ledger Entry ─────────────────────────────────────────────────────

enum LedgerStatus { pending, confirmed, reversed }

class LedgerEntry {
  final String transactionId;
  final String userId;
  final String eventType;
  final int points; // positive = earn, negative = spend/reversal
  final int balanceAfter;
  final String sourceRefId;
  final String description;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final LedgerStatus status;

  const LedgerEntry({
    required this.transactionId,
    required this.userId,
    required this.eventType,
    required this.points,
    required this.balanceAfter,
    required this.sourceRefId,
    required this.description,
    required this.createdAt,
    this.expiresAt,
    this.status = LedgerStatus.confirmed,
  });

  bool get isEarning => points > 0;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'userId': userId,
    'eventType': eventType,
    'points': points,
    'balanceAfter': balanceAfter,
    'sourceRefId': sourceRefId,
    'description': description,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'status': status.name,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    transactionId: json['transactionId'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    eventType: json['eventType'] as String? ?? '',
    points: (json['points'] as num?)?.toInt() ?? 0,
    balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
    sourceRefId: json['sourceRefId'] as String? ?? '',
    description: json['description'] as String? ?? '',
    createdAt: json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    expiresAt: json['expiresAt'] is Timestamp
        ? (json['expiresAt'] as Timestamp).toDate()
        : (json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null),
    status: LedgerStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => LedgerStatus.confirmed,
    ),
  );
}

// ── Rewards Wallet ───────────────────────────────────────────────────

class RewardsWallet {
  final String userId;
  final int availableBalance;
  final int lockedBalance;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final RewardsTier tier;
  final DateTime updatedAt;

  const RewardsWallet({
    required this.userId,
    this.availableBalance = 0,
    this.lockedBalance = 0,
    this.lifetimeEarned = 0,
    this.lifetimeRedeemed = 0,
    this.tier = RewardsTier.bronze,
    required this.updatedAt,
  });

  int get totalBalance => availableBalance + lockedBalance;

  RewardsWallet copyWith({
    int? availableBalance,
    int? lockedBalance,
    int? lifetimeEarned,
    int? lifetimeRedeemed,
    RewardsTier? tier,
    DateTime? updatedAt,
  }) => RewardsWallet(
    userId: userId,
    availableBalance: availableBalance ?? this.availableBalance,
    lockedBalance: lockedBalance ?? this.lockedBalance,
    lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
    lifetimeRedeemed: lifetimeRedeemed ?? this.lifetimeRedeemed,
    tier: tier ?? this.tier,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'availableBalance': availableBalance,
    'lockedBalance': lockedBalance,
    'lifetimeEarned': lifetimeEarned,
    'lifetimeRedeemed': lifetimeRedeemed,
    'tier': tier.name,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory RewardsWallet.fromJson(Map<String, dynamic> json) => RewardsWallet(
    userId: json['userId'] as String? ?? '',
    availableBalance: (json['availableBalance'] as num?)?.toInt() ?? 0,
    lockedBalance: (json['lockedBalance'] as num?)?.toInt() ?? 0,
    lifetimeEarned: (json['lifetimeEarned'] as num?)?.toInt() ?? 0,
    lifetimeRedeemed: (json['lifetimeRedeemed'] as num?)?.toInt() ?? 0,
    tier: RewardsTier.values.firstWhere(
      (t) => t.name == json['tier'],
      orElse: () => RewardsTier.bronze,
    ),
    updatedAt: json['updatedAt'] is Timestamp
        ? (json['updatedAt'] as Timestamp).toDate()
        : DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
  );

  factory RewardsWallet.empty(String userId) => RewardsWallet(
    userId: userId,
    updatedAt: DateTime.now(),
  );
}

// ── Redemption Record ────────────────────────────────────────────────

enum RedemptionStatus { initiated, applied, completed, failed, refunded }

class RedemptionRecord {
  final String redemptionId;
  final String userId;
  final int pointsUsed;
  final double cashEquivalent;
  final String? orderId;
  final RedemptionStatus status;
  final double conversionRate;
  final DateTime createdAt;

  const RedemptionRecord({
    required this.redemptionId,
    required this.userId,
    required this.pointsUsed,
    required this.cashEquivalent,
    this.orderId,
    this.status = RedemptionStatus.initiated,
    required this.conversionRate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'redemptionId': redemptionId,
    'userId': userId,
    'pointsUsed': pointsUsed,
    'cashEquivalent': cashEquivalent,
    'orderId': orderId,
    'status': status.name,
    'conversionRate': conversionRate,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory RedemptionRecord.fromJson(Map<String, dynamic> json) => RedemptionRecord(
    redemptionId: json['redemptionId'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    pointsUsed: (json['pointsUsed'] as num?)?.toInt() ?? 0,
    cashEquivalent: (json['cashEquivalent'] as num?)?.toDouble() ?? 0.0,
    orderId: json['orderId'] as String?,
    status: RedemptionStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => RedemptionStatus.initiated,
    ),
    conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0.1,
    createdAt: json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

// ── Rewards Config ───────────────────────────────────────────────────

class RewardsConfig {
  final double conversionRate; // e.g., 0.1 means 100 points = ₹10
  final double maxRedemptionPercent; // e.g., 0.5 means max 50% of cart
  final int minRedemptionPoints;

  const RewardsConfig({
    this.conversionRate = 0.1,
    this.maxRedemptionPercent = 0.5,
    this.minRedemptionPoints = 100,
  });

  double pointsToRupees(int points) => points * conversionRate;
  int rupeesToPoints(double rupees) => (rupees / conversionRate).round();

  Map<String, dynamic> toJson() => {
    'conversionRate': conversionRate,
    'maxRedemptionPercent': maxRedemptionPercent,
    'minRedemptionPoints': minRedemptionPoints,
  };

  factory RewardsConfig.fromJson(Map<String, dynamic> json) => RewardsConfig(
    conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0.1,
    maxRedemptionPercent: (json['maxRedemptionPercent'] as num?)?.toDouble() ?? 0.5,
    minRedemptionPoints: (json['minRedemptionPoints'] as num?)?.toInt() ?? 100,
  );
}
