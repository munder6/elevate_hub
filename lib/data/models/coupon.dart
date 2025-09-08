class Coupon {
  final String id;
  final String code;
  final String kind;    // 'percent' | 'fixed'
  final num value;
  final String scope;   // 'drinks' | 'sessions' | 'all'
  final String appliesTo; // 'all' | 'member'
  final String? memberId;
  final DateTime? validFrom;
  final DateTime? validTo;
  final int? maxRedemptions;
  final bool active;

  Coupon({
    required this.id,
    required this.code,
    required this.kind,
    required this.value,
    required this.scope,
    required this.appliesTo,
    this.memberId,
    this.validFrom,
    this.validTo,
    this.maxRedemptions,
    required this.active,
  });

  bool get isPercent => kind == 'percent';
  bool get isFixed => kind == 'fixed';

  factory Coupon.fromMap(String id, Map<String, dynamic> m) => Coupon(
    id: id,
    code: (m['code'] ?? '').toString(),
    kind: (m['kind'] ?? 'fixed').toString(),
    value: (m['value'] ?? 0) as num,
    scope: (m['scope'] ?? 'all').toString(),
    appliesTo: (m['appliesTo'] ?? 'all').toString(),
    memberId: m['memberId'],
    validFrom: m['validFrom'] != null ? DateTime.tryParse(m['validFrom'].toString()) : null,
    validTo: m['validTo'] != null ? DateTime.tryParse(m['validTo'].toString()) : null,
    maxRedemptions: m['maxRedemptions'],
    active: (m['active'] ?? true) as bool,
  );

  Map<String, dynamic> toMap() => {
    'code': code,
    'kind': kind,
    'value': value,
    'scope': scope,
    'appliesTo': appliesTo,
    if (memberId != null) 'memberId': memberId,
    if (validFrom != null) 'validFrom': validFrom!.toIso8601String(),
    if (validTo != null) 'validTo': validTo!.toIso8601String(),
    if (maxRedemptions != null) 'maxRedemptions': maxRedemptions,
    'active': active,
  };
}
