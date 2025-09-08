import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session.dart';
import '../models/order.dart';
import '../models/expense.dart';
import '../models/inventory_item.dart';
import '../models/debt.dart';

import '../services/firestore_service.dart';

class ReportsRepo {
  final fs = FirestoreService();

  // Helpers
  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// جلب السيشنز ضمن مدى التاريخ (باستخدام orderBy على checkInAt فقط)
  Future<List<Session>> fetchSessions(DateTime from, DateTime to) async {
    final snap = await fs.col('sessions')
        .orderBy('checkInAt')
        .get();

    return snap.docs
        .map((d) => Session.fromMap(d.id, d.data()))
        .where((s) {
      final c = _asDate(s.checkInAt);
      return c != null && !c.isBefore(from) && !c.isAfter(to);
    })
        .toList();
  }

  /// جلب الطلبات ضمن مدى التاريخ (orderBy createdAt فقط)
  Future<List<OrderModel>> fetchOrders(DateTime from, DateTime to) async {
    final snap = await fs.col('orders')
        .orderBy('createdAt')
        .get();

    return snap.docs
        .map((d) => OrderModel.fromMap(d.id, d.data()))
        .where((o) {
      final c = _asDate(o.createdAt);
      return c != null && !c.isBefore(from) && !c.isAfter(to);
    })
        .toList();
  }

  /// جلب المصاريف المتغيرة بنطاق الشهر ثم فلترة بالعميل محليًا على التاريخ
  Future<List<Expense>> fetchVariableExpenses(DateTime from, DateTime to) async {
    String _mKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}';

    final fromMk = _mKey(from);
    final toMk = _mKey(to);

    final snap = await fs.col('expenses')
        .where('type', isEqualTo: 'variable')
        .where('monthKey', isGreaterThanOrEqualTo: fromMk)
        .where('monthKey', isLessThanOrEqualTo: toMk)
        .orderBy('createdAt')
        .get();

    final list = snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();
    return list.where((e) {
      final c = _asDate(e.createdAt);
      return c != null && !c.isBefore(from) && !c.isAfter(to);
    }).toList();
  }

  /// جلب المصاريف الثابتة لشهر معيّن (monthKey)
  Future<List<Expense>> fetchFixedMonthlyExpenses(DateTime month) async {
    String _mKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}';
    final mk = _mKey(month);
    final snap = await fs.col('expenses')
        .where('type', isEqualTo: 'fixedMonthly')
        .where('monthKey', isEqualTo: mk)
        .orderBy('createdAt')
        .get();
    return snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();
  }

  /// جلب الديون ضمن مدى (orderBy createdAt فقط ثم فلترة محلية)
  Future<List<Debt>> fetchDebts(DateTime from, DateTime to) async {
    final snap = await fs.col('debts')
        .orderBy('createdAt')
        .get();
    return snap.docs
        .map((d) => Debt.fromMap(d.id, d.data()))
        .where((e) {
      final c = _asDate(e.createdAt);
      return c != null && !c.isBefore(from) && !c.isAfter(to);
    })
        .toList();
  }

  /// لقطة مخزون حالية (بدون نطاق)
  Future<List<InventoryItem>> inventorySnapshot({bool activeOnly = true}) async {
    final snap = await fs.col('inventory_items').orderBy('name').get();
    final list = snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList();
    return activeOnly ? list.where((e) => e.isActive).toList() : list;
  }

  /// Summary مبسّط:
  /// revenue = مجموع grandTotal للسيشنز المغلقة فقط ضمن المدى.
  /// expenses = متغيرة ضمن المدى + الثابتة لشهر/شهور المدى (تبسّط: خذ الثابتة لكل شهر داخل المدى).
  /// net = revenue - expenses
  Future<({num revenue, num expenses, num net, String? topDrink})> summary(
      DateTime from,
      DateTime to,
      ) async {
    // Sessions revenue
    final sessions = await fetchSessions(from, to);
    final closed = sessions.where((s) => s.status == 'closed');
    final revenue = closed.fold<num>(0, (sum, s) => sum + (s.grandTotal ?? 0));

    // Expenses
    final variable = await fetchVariableExpenses(from, to);

    // ثابتة: اجمع لكل شهر داخل المدى
    num fixedSum = 0;
    DateTime cursor = DateTime(from.year, from.month, 1);
    while (!cursor.isAfter(DateTime(to.year, to.month, 1))) {
      final fixed = await fetchFixedMonthlyExpenses(cursor);
      fixedSum += fixed.fold<num>(0, (s, e) => s + e.amount);
      final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
      cursor = nextMonth;
    }
    final variableSum = variable.fold<num>(0, (s, e) => s + e.amount);
    final expenses = variableSum + fixedSum;

    // Top Drink (تقريبية): الأكثر تكرارًا بالطلبات خلال المدى
    final orders = await fetchOrders(from, to);
    final counts = <String, int>{};
    for (final o in orders) {
      final name = (o.itemName ?? '').trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + (o.qty ?? 1);
    }
    String? topDrink;
    if (counts.isNotEmpty) {
      counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topDrink = counts.entries.first.key;
    }

    final net = revenue - expenses;
    return (revenue: revenue, expenses: expenses, net: net, topDrink: topDrink);
  }
}
