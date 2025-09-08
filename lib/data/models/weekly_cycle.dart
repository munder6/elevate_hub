class WeeklyCycle {
  final String id;
  final String memberId;
  final DateTime startDate;
  final int days;           // 6
  final num drinksTotal;    // مجموع المشروبات خلال الأسبوع
  final String status;      // active | closed
  final String memberName;
  // حقول الدورة:
  final num priceAtStart;   // سعر الأسبوع من الإعدادات لحظة البدء (مرجعية)
  final num dayCost;        // priceAtStart / days
  final int daysUsed;       // يزيد عند إغلاق اليوم
  final String? openDayId;  // يوم مفتوح حاليًا (إن وجد)

  WeeklyCycle({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.startDate,
    this.days = 6,
    this.drinksTotal = 0,
    this.status = 'active',
    required this.priceAtStart,
    required this.dayCost,
    this.daysUsed = 0,
    this.openDayId,
  });

  factory WeeklyCycle.fromMap(String id, Map<String, dynamic> m) => WeeklyCycle(
    id: id,
    memberId: (m['memberId'] ?? '') as String,
    memberName: m['memberName'] ?? '',
    startDate: DateTime.tryParse(m['startDate']?.toString() ?? '') ?? DateTime.now(),
    days: (m['days'] ?? 6) as int,
    drinksTotal: (m['drinksTotal'] ?? 0) as num,
    status: (m['status'] ?? 'active') as String,
    priceAtStart: (m['priceAtStart'] ?? 0) as num,
    dayCost: (m['dayCost'] ?? 0) as num,
    daysUsed: (m['daysUsed'] ?? 0) as int,
    openDayId: m['openDayId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'startDate': startDate.toIso8601String(),
    'days': days,
    'drinksTotal': drinksTotal,
    'status': status,
    'priceAtStart': priceAtStart,
    'dayCost': dayCost,
    'daysUsed': daysUsed,
    'memberName': memberName,
    if (openDayId != null) 'openDayId': openDayId,
  };
}
