class Member {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;

  /// 'hour' | 'week' | 'month' (اختياري)
  final String? preferredPlan;

  final num balance;
  final DateTime? lastBalanceAt;

  Member({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.preferredPlan,
    this.balance = 0,
    this.lastBalanceAt,
  });

  factory Member.fromMap(String id, Map<String, dynamic> m) => Member(
    id: id,
    name: m['name'] ?? '',
    phone: m['phone'],
    notes: m['notes'],
    isActive: m['isActive'] ?? true,
    createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? ''),
    preferredPlan: m['preferredPlan'],
    balance: (m['balance'] ?? 0) as num,
    lastBalanceAt: _asDate(m['lastBalanceAt']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    if (phone != null) 'phone': phone,
    if (notes != null) 'notes': notes,
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (preferredPlan != null) 'preferredPlan': preferredPlan,
    'balance': balance,
    if (lastBalanceAt != null) 'lastBalanceAt': lastBalanceAt!.toIso8601String(),
  };

  Member copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    String? preferredPlan,
    num? balance,
    DateTime? lastBalanceAt,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      preferredPlan: preferredPlan ?? this.preferredPlan,
      balance: balance ?? this.balance,
      lastBalanceAt: lastBalanceAt ?? this.lastBalanceAt,
    );
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
