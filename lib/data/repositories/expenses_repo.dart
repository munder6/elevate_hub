import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/expense.dart';

class ExpensesRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('expenses');

  String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10); // YYYY-MM-DD
  String _monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  // ===== Create =====
  Future<void> addVariable({
    required num amount,
    required String category,
    String? reason,
    DateTime? at,
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final now = at ?? DateTime.now();
    await _col.add({
      'amount': amount,
      'category': category,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'type': 'variable',
      'dayKey': _dayKey(now),
      'monthKey': _monthKey(now),
      'createdAt': now.toIso8601String(),
      'byUserId': uid,
    });
  }

  /// ثابتة شهرية (مرة لكل شهر — أو أكثر حسب حاجتك)
  Future<void> addFixedMonthly({
    required num amount,
    required String category,
    String? reason,
    DateTime? month, // لو تركتها null بيأخذ الشهر الحالي
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final base = month ?? DateTime.now();
    final mKey = _monthKey(base);
    await _col.add({
      'amount': amount,
      'category': category,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'type': 'fixedMonthly',
      'monthKey': mKey,
      'createdAt': DateTime.now().toIso8601String(),
      'byUserId': uid,
    });
  }

  Future<void> updateExpense(Expense e) async {
    await fs.update('expenses/${e.id}', e.toMap());
  }

  Future<void> delete(String id) async {
    await fs.delete('expenses/$id');
  }

  // ===== Watch =====

  /// يوم معيّن (بدون فهرس مركّب): where واحد على dayKey + orderBy createdAt
  Stream<List<Expense>> watchByDay(DateTime day) {
    final dk = _dayKey(day);
    return _col
        .where('dayKey', isEqualTo: dk)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  /// شهر معيّن للثابتة الشهرية
  Stream<List<Expense>> watchFixedByMonth(DateTime month) {
    final mk = _monthKey(month);
    return _col
        .where('type', isEqualTo: 'fixedMonthly')
        .where('monthKey', isEqualTo: mk)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  /// متغيّرة ضمن نطاق أيام (fallback بدون فهرس): نجيب الشهر ونفلتر على العميل
  Stream<List<Expense>> watchVariableRange(DateTime from, DateTime to) {
    // نستعمل monthKey لنقلل القراءة (تقديرياً)، ثم نفصل على العميل
    final fromMk = _monthKey(from);
    final toMk = _monthKey(to);
    return _col
        .where('type', isEqualTo: 'variable')
        .where('monthKey', isGreaterThanOrEqualTo: fromMk)
        .where('monthKey', isLessThanOrEqualTo: toMk)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs
        .map((d) => Expense.fromMap(d.id, d.data()))
        .where((e) {
      final day = DateTime.tryParse(e.createdAt ?? '') ?? DateTime.now();
      return !day.isBefore(from) && !day.isAfter(to);
    })
        .toList());
  }
}
