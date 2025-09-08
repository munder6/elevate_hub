class OrderModel {
  final String id;
  final String? sessionId;
  final String? weeklyCycleId;
  final String? monthlyCycleId;
  final String? memberId;
  final String? memberName;

  final String itemName;
  final int qty;
  final num unitPriceAtTime;
  final num total;
  final DateTime? createdAt;
  final String? createdBy;
  final String? createdByName;

  // NEW for standalone
  final bool? standalone;
  final String? customerName;
  final String? note;

  OrderModel({
    required this.id,
    this.sessionId,
    this.weeklyCycleId,
    this.monthlyCycleId,
    this.memberId,
    this.memberName,
    required this.itemName,
    required this.qty,
    required this.unitPriceAtTime,
    required this.total,
    this.createdAt,
    this.createdBy,
    this.createdByName,
    this.standalone,
    this.customerName,
    this.note,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> m) => OrderModel(
    id: id,
    sessionId: m['sessionId'],
    weeklyCycleId: m['weeklyCycleId'],
    monthlyCycleId: m['monthlyCycleId'],
    memberId: m['memberId'],
    memberName: m['memberName'],
    itemName: m['itemName'] ?? '',
    qty: (m['qty'] ?? 0) as int,
    unitPriceAtTime: (m['unitPriceAtTime'] ?? 0) as num,
    total: (m['total'] ?? 0) as num,
    createdAt: DateTime.tryParse('${m['createdAt']}'),
    createdBy: m['createdBy'],
    createdByName: m['createdByName'],
    standalone: m['standalone'] as bool?,
    customerName: m['customerName'] as String?,
    note: m['note'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (sessionId != null) 'sessionId': sessionId,
    if (weeklyCycleId != null) 'weeklyCycleId': weeklyCycleId,
    if (monthlyCycleId != null) 'monthlyCycleId': monthlyCycleId,
    if (memberId != null) 'memberId': memberId,
    if (memberName != null) 'memberName': memberName,
    'itemName': itemName,
    'qty': qty,
    'unitPriceAtTime': unitPriceAtTime,
    'total': total,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (createdBy != null) 'createdBy': createdBy,
    if (createdByName != null) 'createdByName': createdByName,
    if (standalone != null) 'standalone': standalone,
    if (customerName != null) 'customerName': customerName,
    if (note != null) 'note': note,
  };
}
