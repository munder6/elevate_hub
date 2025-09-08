class BalanceTx {
  final String id;
  final String memberId;
  /// 'credit' | 'debit' | 'adjust'
  final String type;
  /// قيمة موجبة دائمًا (منطق الإشارة حسب النوع)
  final num amount;
  final String? reason;
  /// refType: 'session' | 'weekly' | 'monthly' | 'order' | غيره
  final String? refType;
  final String? refId;
  final DateTime createdAt;
  final String? createdBy;

  const BalanceTx({
    required this.id,
    required this.memberId,
    required this.type,
    required this.amount,
    this.reason,
    this.refType,
    this.refId,
    required this.createdAt,
    this.createdBy,
  });

  factory BalanceTx.fromMap(String id, Map<String, dynamic> m) {
    return BalanceTx(
      id: id,
      memberId: (m['memberId'] as String?) ?? '',
      type: (m['type'] as String?) ?? 'credit',
      amount: (m['amount'] ?? 0) as num,
      reason: m['reason'] as String?,
      refType: m['refType'] as String?,
      refId: m['refId'] as String?,
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
      createdBy: m['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'type': type,
    'amount': amount,
    if (reason != null) 'reason': reason,
    if (refType != null) 'refType': refType,
    if (refId != null) 'refId': refId,
    'createdAt': createdAt.toIso8601String(),
    if (createdBy != null) 'createdBy': createdBy,
  };
}
