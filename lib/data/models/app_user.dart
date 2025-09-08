class AppPerms {
  final bool isAdmin;
  final bool settings;
  final bool reports;
  final bool orders;
  final bool sessions;
  final bool expensesVar;
  final bool expensesFixed;
  final bool inventory;
  final bool assets;
  final bool debts;
  final bool coupons;

  const AppPerms({
    this.isAdmin = false,
    this.settings = false,
    this.reports = false,
    this.orders = true,
    this.sessions = true,
    this.expensesVar = true,
    this.expensesFixed = false,
    this.inventory = true,
    this.assets = false,
    this.debts = true,
    this.coupons = false,
  });

  factory AppPerms.fromMap(Map<String, dynamic>? m) {
    m ??= const {};
    return AppPerms(
      isAdmin: m['isAdmin'] == true,
      settings: m['settings'] == true,
      reports: m['reports'] == true,
      orders: m['orders'] != false,
      sessions: m['sessions'] != false,
      expensesVar: m['expenses_var'] != false,
      expensesFixed: m['expenses_fixed'] == true,
      inventory: m['inventory'] != false,
      assets: m['assets'] == true,
      debts: m['debts'] != false,
      coupons: m['coupons'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'isAdmin': isAdmin,
    'settings': settings,
    'reports': reports,
    'orders': orders,
    'sessions': sessions,
    'expenses_var': expensesVar,
    'expenses_fixed': expensesFixed,
    'inventory': inventory,
    'assets': assets,
    'debts': debts,
    'coupons': coupons,
  };

  // ✅ Getter جديد
  bool get expenses => expensesVar || expensesFixed;
}


class AppUser {
  final String id;
  final String email;
  final String? name;
  final String status; // 'pending' | 'active'
  final AppPerms perms;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.status,
    required this.perms,
    this.name,
    this.createdAt,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> m) {
    return AppUser(
      id: id,
      email: (m['email'] as String?) ?? '',
      name: m['name'] as String?,
      status: (m['status'] as String?) ?? 'pending',
      perms: AppPerms.fromMap(m['perms'] as Map<String, dynamic>?),
      createdAt: _asDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'status': status,
    'perms': perms.toMap(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
    // (serverTimestamp سيعود null على الكلاينت حتى يتم التزامن)
  }
}
