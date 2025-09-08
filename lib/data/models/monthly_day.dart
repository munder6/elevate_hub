class MonthlyDay {
  final String id;
  final String cycleId;
  final String memberId;
  final String dateKey;            // 'YYYY-MM-DD'
  final DateTime startAt;
  final DateTime expectedCloseAt;  // start + 8h
  final DateTime? stopAt;          // close time
  final String status;             // open | closed
  final num dayCost;               // captured at start
  final String memberName;

  MonthlyDay({
    required this.id,
    required this.memberName,
    required this.cycleId,
    required this.memberId,
    required this.dateKey,
    required this.startAt,
    required this.expectedCloseAt,
    this.stopAt,
    required this.status,
    required this.dayCost,
  });

  factory MonthlyDay.fromMap(String id, Map<String, dynamic> m) => MonthlyDay(
    id: id,
    cycleId: (m['cycleId'] ?? '') as String,
    memberName: m['memberName'] ?? '',
    memberId: (m['memberId'] ?? '') as String,
    dateKey: (m['dateKey'] ?? '') as String,
    startAt: DateTime.tryParse(m['startAt']?.toString() ?? '') ?? DateTime.now(),
    expectedCloseAt: DateTime.tryParse(m['expectedCloseAt']?.toString() ?? '') ?? DateTime.now(),
    stopAt: m['stopAt'] != null ? DateTime.tryParse(m['stopAt'].toString()) : null,
    status: (m['status'] ?? 'open') as String,
    dayCost: (m['dayCost'] ?? 0) as num,
  );

  Map<String, dynamic> toMap() => {
    'cycleId': cycleId,
    'memberId': memberId,
    'dateKey': dateKey,
    'startAt': startAt.toIso8601String(),
    'expectedCloseAt': expectedCloseAt.toIso8601String(),
    if (stopAt != null) 'stopAt': stopAt!.toIso8601String(),
    'status': status,
    'memberName': memberName,
    'dayCost': dayCost,
  };
}
