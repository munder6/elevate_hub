class WeeklyDay {
  final String id;
  final String cycleId;
  final String memberId;
  final String dateKey;            // 'YYYY-MM-DD' لمنع يومين بنفس التاريخ
  final DateTime startAt;
  final DateTime expectedCloseAt;  // start + 8h
  final DateTime? stopAt;          // وقت الإغلاق الفعلي
  final String status;             // open | closed
  final num dayCost;               // كلفة اليوم لحظة الإنشاء
  final String memberName;

  WeeklyDay({
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

  factory WeeklyDay.fromMap(String id, Map<String, dynamic> m) => WeeklyDay(
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
    'dayCost': dayCost,
    'memberName': memberName,
  };
}
