class Expense {
  final String id;
  final num amount;
  final String category;
  final String type; // 'variable' | 'fixedMonthly'
  final String? reason;
  final String? byUserId;
  final String? dayKey;    // للمتغيّرة
  final String? monthKey;  // للثابتة/وأيضًا للفلترة
  final String? createdAt;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.type,
    this.reason,
    this.byUserId,
    this.dayKey,
    this.monthKey,
    this.createdAt,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> m) => Expense(
    id: id,
    amount: (m['amount'] ?? 0) as num,
    category: (m['category'] ?? '').toString(),
    type: (m['type'] ?? 'variable').toString(),
    reason: m['reason']?.toString(),
    byUserId: m['byUserId']?.toString(),
    dayKey: m['dayKey']?.toString(),
    monthKey: m['monthKey']?.toString(),
    createdAt: m['createdAt']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'category': category,
    'type': type,
    if (reason != null) 'reason': reason,
    if (byUserId != null) 'byUserId': byUserId,
    if (dayKey != null) 'dayKey': dayKey,
    if (monthKey != null) 'monthKey': monthKey,
    if (createdAt != null) 'createdAt': createdAt,
  };

  Expense copyWith({
    String? id,
    num? amount,
    String? category,
    String? type,
    String? reason,
    String? byUserId,
    String? dayKey,
    String? monthKey,
    String? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      byUserId: byUserId ?? this.byUserId,
      dayKey: dayKey ?? this.dayKey,
      monthKey: monthKey ?? this.monthKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
