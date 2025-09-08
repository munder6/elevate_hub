class StockMovement {
  final String id;
  final String invId;
  final String type; // 'in' | 'out' | 'adjust'
  final num qty;
  final String? reason;
  final String? refType; // optional link
  final String? refId;
  final num before;
  final num after;
  final String? createdAt;
  final String? createdBy;

  StockMovement({
    required this.id,
    required this.invId,
    required this.type,
    required this.qty,
    required this.before,
    required this.after,
    this.reason,
    this.refType,
    this.refId,
    this.createdAt,
    this.createdBy,
  });

  factory StockMovement.fromMap(String id, Map<String, dynamic> m) => StockMovement(
    id: id,
    invId: (m['invId'] ?? '').toString(),
    type: (m['type'] ?? '').toString(),
    qty: (m['qty'] ?? 0) as num,
    reason: m['reason']?.toString(),
    refType: m['refType']?.toString(),
    refId: m['refId']?.toString(),
    before: (m['before'] ?? 0) as num,
    after: (m['after'] ?? 0) as num,
    createdAt: m['createdAt']?.toString(),
    createdBy: m['createdBy']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'invId': invId,
    'type': type,
    'qty': qty,
    if (reason != null) 'reason': reason,
    if (refType != null) 'refType': refType,
    if (refId != null) 'refId': refId,
    'before': before,
    'after': after,
    if (createdAt != null) 'createdAt': createdAt,
    if (createdBy != null) 'createdBy': createdBy,
  };
}
