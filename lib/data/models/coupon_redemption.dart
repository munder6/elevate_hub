class CouponRedemption {
  final String id;
  final String couponId;
  final String? memberId;
  final String refType; // 'session' | 'weekly' | 'monthly'
  final String refId;
  final num amountDiscounted;
  final DateTime at;

  CouponRedemption({
    required this.id,
    required this.couponId,
    this.memberId,
    required this.refType,
    required this.refId,
    required this.amountDiscounted,
    required this.at,
  });

  factory CouponRedemption.fromMap(String id, Map<String, dynamic> m) => CouponRedemption(
    id: id,
    couponId: m['couponId'],
    memberId: m['memberId'],
    refType: m['refType'],
    refId: m['refId'],
    amountDiscounted: (m['amountDiscounted'] ?? 0) as num,
    at: DateTime.tryParse(m['at']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'couponId': couponId,
    if (memberId != null) 'memberId': memberId,
    'refType': refType,
    'refId': refId,
    'amountDiscounted': amountDiscounted,
    'at': at.toIso8601String(),
  };
}
