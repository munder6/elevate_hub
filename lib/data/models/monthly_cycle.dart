class MonthlyCycle {
  final String id;
  final String memberId;
  final DateTime startDate;
  final int days;           // 26
  final num drinksTotal;    // all drinks in the cycle
  final String status;      // active | closed

  final num priceAtStart;   // snapshot from settings at start
  final num dayCost;        // priceAtStart / days
  final int daysUsed;       // increments on day close
  final String? openDayId;  // current open day if any
  final String memberName;
  final String? planId;
  final num? bandwidthMbpsSnapshot;
  final String? planTitleSnapshot;
  MonthlyCycle({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.startDate,
    this.days = 26,
    this.drinksTotal = 0,
    this.status = 'active',
    required this.priceAtStart,
    required this.dayCost,
    this.daysUsed = 0,
    this.openDayId,
    this.planId,
    this.bandwidthMbpsSnapshot,
    this.planTitleSnapshot,
  });

  factory MonthlyCycle.fromMap(String id, Map<String, dynamic> m) => MonthlyCycle(
    id: id,
    memberId: (m['memberId'] ?? '') as String,
    memberName: m['memberName'] ?? '',
    startDate: DateTime.tryParse(m['startDate']?.toString() ?? '') ?? DateTime.now(),
    days: (m['days'] ?? 26) as int,
    drinksTotal: (m['drinksTotal'] ?? 0) as num,
    status: (m['status'] ?? 'active') as String,
    priceAtStart: (m['priceAtStart'] ?? 0) as num,
    dayCost: (m['dayCost'] ?? 0) as num,
    daysUsed: (m['daysUsed'] ?? 0) as int,
    openDayId: m['openDayId'] as String?,
    planId: m['planId'] as String?,
    bandwidthMbpsSnapshot: m['bandwidthMbpsSnapshot'] as num?,
    planTitleSnapshot: m['planTitleSnapshot'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'startDate': startDate.toIso8601String(),
    'days': days,
    'drinksTotal': drinksTotal,
    'status': status,
    'priceAtStart': priceAtStart,
    'dayCost': dayCost,
    'memberName': memberName,
    'daysUsed': daysUsed,
    if (openDayId != null) 'openDayId': openDayId,
    if (planId != null) 'planId': planId,
    if (bandwidthMbpsSnapshot != null)
      'bandwidthMbpsSnapshot': bandwidthMbpsSnapshot,
    if (planTitleSnapshot != null) 'planTitleSnapshot': planTitleSnapshot,
  };
}
