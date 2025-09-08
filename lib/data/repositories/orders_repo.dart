import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'debts_repo.dart';

class OrdersRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('orders');

  // ===== Watchers =====

  Stream<List<OrderModel>> watchBySession(String sessionId) {
    return _col
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<OrderModel>> watchByWeekly(String cycleId) {
    return _col
        .where('weeklyCycleId', isEqualTo: cycleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<OrderModel>> watchByMonthly(String cycleId) {
    return _col
        .where('monthlyCycleId', isEqualTo: cycleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }

  /// أحدث الطلبات بشكل عام (لالـ OrdersListView)
  Stream<List<OrderModel>> watchLatest({int limit = 100}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }

  // ===== Mutations =====

  /// إضافة طلب على جلسة يومية + تحديث drinksTotal للجلسة (Transaction)
  Future<void> addOrder({
    required String sessionId,
    required String itemName,
    required num unitPriceAtTime,
    required int qty,
  }) async {
    final total = unitPriceAtTime * qty;

    final user = auth.currentUser;
    final uid = user?.uid ?? 'system';
    final createdByName = user?.displayName ?? user?.email ?? 'unknown';
    final now = DateTime.now();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // ========== READS (كلها قبل أي WRITE) ==========
      // 1) جلسة
      final sessionRef = fs.doc('sessions/$sessionId');
      final ssnap = await tx.get(sessionRef);
      final sm = ssnap.data() as Map<String, dynamic>?;

      if (sm == null) {
        throw Exception('Session not found');
      }

      final String? memberIdFromSession = sm['memberId'] as String?;
      String? memberName = sm['memberName'] as String?;

      // 2) لو الاسم مش مخزّن بالجسلة: اقرأه من members (قراءة فقط هنا)
      if ((memberName == null || memberName.isEmpty) && memberIdFromSession != null) {
        final memberRef = fs.doc('members/$memberIdFromSession');
        final msnap = await tx.get(memberRef);
        final mm = msnap.data() as Map<String, dynamic>?;
        if (mm != null) {
          memberName = (mm['name'] as String?) ?? memberName;
        }
      }

      // 3) دين الجلسة (debts/session_<id>) — قراءة مسبقة لتقرير إن كان موجود
      final debtRef = fs.doc('debts/session_$sessionId');
      final dsnap = await tx.get(debtRef);
      final bool hasExistingDebt = dsnap.exists;
      num existingDebtAmount = 0;
      String existingDebtStatus = 'open';
      if (hasExistingDebt) {
        final dm = dsnap.data() as Map<String, dynamic>? ?? {};
        existingDebtAmount = (dm['amount'] ?? 0) as num;
        existingDebtStatus = (dm['status'] as String?) ?? 'open';
      }

      // ========== WRITES (كلها بعد إتمام القراءات) ==========
      // 4) إنشاء الطلب
      final orderRef = _col.doc();
      tx.set(orderRef, {
        'sessionId': sessionId,
        if (memberIdFromSession != null) 'memberId': memberIdFromSession,
        if (memberName != null) 'memberName': memberName,
        'itemName': itemName,
        'unitPriceAtTime': unitPriceAtTime,
        'qty': qty,
        'total': total,
        'createdAt': now.toIso8601String(),
        'createdBy': uid,
        'createdByName': createdByName,
      });

      // 5) تحديث إجمالي مشروبات الجلسة
      tx.update(sessionRef, {'drinksTotal': FieldValue.increment(total)});

      // (اختياري) خزن memberName بالجسلة لو كان ناقص — كتابة مسموحة الآن
      if ((sm['memberName'] == null || (sm['memberName'] as String).isEmpty) && memberName != null) {
        tx.update(sessionRef, {'memberName': memberName});
      }

      // 6) إنشاء/تحديث دين الجلسة
      if (!hasExistingDebt) {
        tx.set(debtRef, {
          'memberId': memberIdFromSession,
          'memberName': memberName,
          'amount': total,
          'reason': 'Session drinks',
          'status': 'open',
          'createdAt': now.toIso8601String(),
          'refType': 'session',
          'refId': sessionId,
          'payments': <Map<String, dynamic>>[],
        });
      } else {
        // لو كان مغلق بالغلط، نعيد فتحه ونزيد المبلغ
        final newAmount = existingDebtAmount + total;
        tx.update(debtRef, {
          'amount': newAmount,
          'status': 'open',
          if (memberIdFromSession != null) 'memberId': memberIdFromSession,
          if (memberName != null) 'memberName': memberName,
        });
      }
    });
  }





// =============== WEEKLY ===============
  Future<void> addOrderForWeekly({
    required String cycleId,
    required String itemName,
    required num unitPriceAtTime,
    required int qty,
  }) async {
    final total = unitPriceAtTime * qty;

    final user = auth.currentUser;
    final uid = user?.uid ?? 'system';
    final createdByName = user?.displayName ?? user?.email ?? 'unknown';
    final now = DateTime.now();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // ====== READS أولاً ======
      final cycleRef = fs.doc('weekly_cycles/$cycleId');
      final csnap = await tx.get(cycleRef);
      final cm = csnap.data() as Map<String, dynamic>?;

      if (cm == null) {
        throw Exception('Weekly cycle not found');
      }

      final String? memberId = cm['memberId'] as String?;
      String? memberName = cm['memberName'] as String?;

      // لو الاسم مش مخزّن بالدورة: إقراه من members
      if ((memberName == null || memberName.isEmpty) && memberId != null) {
        final msnap = await tx.get(fs.doc('members/$memberId'));
        final mm = msnap.data() as Map<String, dynamic>?;
        if (mm != null) memberName = (mm['name'] as String?) ?? memberName;
      }

      // دين خاص بالدورة الأسبوعية
      final debtRef = fs.doc('debts/weekly_$cycleId');
      final dsnap = await tx.get(debtRef);
      final hasDebt = dsnap.exists;
      num existingAmount = 0;
      String existingStatus = 'open';
      if (hasDebt) {
        final dm = dsnap.data() as Map<String, dynamic>? ?? {};
        existingAmount = (dm['amount'] ?? 0) as num;
        existingStatus = (dm['status'] as String?) ?? 'open';
      }

      // ====== WRITES بعد ما خلصنا قراءات ======
      // 1) إنشاء الطلب
      final orderRef = _col.doc();
      tx.set(orderRef, {
        'weeklyCycleId': cycleId,
        if (memberId != null) 'memberId': memberId,
        if (memberName != null) 'memberName': memberName,
        'itemName': itemName,
        'unitPriceAtTime': unitPriceAtTime,
        'qty': qty,
        'total': total,
        'createdAt': now.toIso8601String(),
        'createdBy': uid,
        'createdByName': createdByName,
      });

      // 2) تحديث drinksTotal في الدورة
      tx.update(cycleRef, {'drinksTotal': FieldValue.increment(total)});

      // 3) تحديث/إنشاء دين الدورة (مشروبات تُسجّل كدين)
      if (!hasDebt) {
        tx.set(debtRef, {
          'memberId': memberId,
          'memberName': memberName,
          'amount': total,
          'reason': 'Weekly drinks',
          'status': 'open',
          'createdAt': now.toIso8601String(),
          'refType': 'weekly',
          'refId': cycleId,
          'payments': <Map<String, dynamic>>[],
        });
      } else {
        final newAmount = existingAmount + total;
        tx.update(debtRef, {
          'amount': newAmount,
          'status': 'open',
          if (memberId != null) 'memberId': memberId,
          if (memberName != null) 'memberName': memberName,
        });
      }
    });
  }

// =============== MONTHLY ===============
  Future<void> addOrderForMonthly({
    required String cycleId,
    required String itemName,
    required num unitPriceAtTime,
    required int qty,
  }) async {
    final total = unitPriceAtTime * qty;

    final user = auth.currentUser;
    final uid = user?.uid ?? 'system';
    final createdByName = user?.displayName ?? user?.email ?? 'unknown';
    final now = DateTime.now();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // ====== READS أولاً ======
      final cycleRef = fs.doc('monthly_cycles/$cycleId');
      final csnap = await tx.get(cycleRef);
      final cm = csnap.data() as Map<String, dynamic>?;

      if (cm == null) {
        throw Exception('Monthly cycle not found');
      }

      final String? memberId = cm['memberId'] as String?;
      String? memberName = cm['memberName'] as String?;

      if ((memberName == null || memberName.isEmpty) && memberId != null) {
        final msnap = await tx.get(fs.doc('members/$memberId'));
        final mm = msnap.data() as Map<String, dynamic>?;
        if (mm != null) memberName = (mm['name'] as String?) ?? memberName;
      }

      // دين خاص بالدورة الشهرية
      final debtRef = fs.doc('debts/monthly_$cycleId');
      final dsnap = await tx.get(debtRef);
      final hasDebt = dsnap.exists;
      num existingAmount = 0;
      String existingStatus = 'open';
      if (hasDebt) {
        final dm = dsnap.data() as Map<String, dynamic>? ?? {};
        existingAmount = (dm['amount'] ?? 0) as num;
        existingStatus = (dm['status'] as String?) ?? 'open';
      }

      // ====== WRITES بعد القراءات ======
      // 1) إنشاء الطلب
      final orderRef = _col.doc();
      tx.set(orderRef, {
        'monthlyCycleId': cycleId,
        if (memberId != null) 'memberId': memberId,
        if (memberName != null) 'memberName': memberName,
        'itemName': itemName,
        'unitPriceAtTime': unitPriceAtTime,
        'qty': qty,
        'total': total,
        'createdAt': now.toIso8601String(),
        'createdBy': uid,
        'createdByName': createdByName,
      });

      // 2) تحديث drinksTotal في الدورة
      tx.update(cycleRef, {'drinksTotal': FieldValue.increment(total)});

      // 3) تحديث/إنشاء دين الدورة
      if (!hasDebt) {
        tx.set(debtRef, {
          'memberId': memberId,
          'memberName': memberName,
          'amount': total,
          'reason': 'Monthly drinks',
          'status': 'open',
          'createdAt': now.toIso8601String(),
          'refType': 'monthly',
          'refId': cycleId,
          'payments': <Map<String, dynamic>>[],
        });
      } else {
        final newAmount = existingAmount + total;
        tx.update(debtRef, {
          'amount': newAmount,
          'status': 'open',
          if (memberId != null) 'memberId': memberId,
          if (memberName != null) 'memberName': memberName,
        });
      }
    });
  }




  /// طلب مستقل (غير مرتبط بعضو/جلسة)
  Future<void> addStandaloneOrder({
    required String customerName,      // اسم الزبون اليدوي (Walk-in)
    required String itemName,
    required num unitPriceAtTime,
    required int qty,
    String? note,                      // اختياري: ملاحظة سريعة
  }) async {
    final total = unitPriceAtTime * qty;
    final user = auth.currentUser;
    final uid = user?.uid ?? 'system';
    final createdByName = user?.displayName ?? user?.email ?? 'unknown';
    final now = DateTime.now();

    await _col.add({
      'standalone': true,              // فلاج يسهّل الفرز/العرض
      'customerName': customerName,
      'itemName': itemName,
      'unitPriceAtTime': unitPriceAtTime,
      'qty': qty,
      'total': total,
      'note': note,
      'createdAt': now.toIso8601String(),
      'createdBy': uid,
      'createdByName': createdByName,
    });
  }

  /// جلب آخر الطلبات المستقلة فقط (للعرض السريع إن احتجت)
  Stream<List<OrderModel>> watchLatestStandalone({int limit = 100}) {
    return _col
        .where('standalone', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }


  /// حذف طلب وإرجاع drinksTotal لكيان الأب
  Future<void> removeOrder(OrderModel order) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final orderRef = _col.doc(order.id);

      if (order.sessionId != null) {
        final parentRef = fs.doc('sessions/${order.sessionId}');
        tx.update(parentRef, {'drinksTotal': FieldValue.increment(-order.total!)});
      } else if (order.weeklyCycleId != null) {
        final parentRef = fs.doc('weekly_cycles/${order.weeklyCycleId}');
        tx.update(parentRef, {'drinksTotal': FieldValue.increment(-order.total!)});
      } else if (order.monthlyCycleId != null) {
        final parentRef = fs.doc('monthly_cycles/${order.monthlyCycleId}');
        tx.update(parentRef, {'drinksTotal': FieldValue.increment(-order.total!)});
      }

      tx.delete(orderRef);
      try {
        await DebtsRepo().deleteByOrderId(order.id);
      } catch (_) {}
    });
  }
}
