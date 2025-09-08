class Debt {
  final String id;
  final String memberId;
  final String? memberName;
  final num amount;
  final String? reason;
  final String status; // open | settled
  final DateTime createdAt;
  final String? refType; // 'weekly' | 'monthly' | 'session'
  final String? refId;

  /// قائمة الدفعات (amount, at, by)
  final List<Map<String, dynamic>> payments;

  Debt({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.amount,
    this.reason,
    required this.status,
    required this.createdAt,
    this.refType,
    this.refId,
    this.payments = const [],
  });

  factory Debt.fromMap(String id, Map<String, dynamic> m) => Debt(
    id: id,
    memberId: m['memberId'] ?? '',
    amount: (m['amount'] ?? 0) as num,
    memberName: m['memberName'],
    reason: m['reason'],
    status: m['status'] ?? 'open',
    createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
    refType: m['refType'],
    refId: m['refId'],
    payments: (m['payments'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ??
        const [],
  );

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'amount': amount,
    if (reason != null) 'reason': reason,
    if (memberName != null) 'memberName': memberName,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    if (refType != null) 'refType': refType,
    if (refId != null) 'refId': refId,
    'payments': payments,
  };
}
