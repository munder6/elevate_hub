import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/debt.dart';

class DebtsRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('debts');

  Stream<List<Debt>> watchAll({String? status}) {
    Query<Map<String, dynamic>> q = _col.orderBy('createdAt', descending: true);
    if (status != null) {
      // بدون فهارس مركبة: فلترة بالعميل عند الحاجة
      return q.snapshots().map((s) => s.docs
          .map((d) => Debt.fromMap(d.id, d.data()))
          .where((e) => e.status == status)
          .toList());
    }
    return q.snapshots().map((s) => s.docs.map((d) => Debt.fromMap(d.id, d.data())).toList());
  }

  Stream<num> watchOpenTotalForMember(String memberId) {
    return _col.where('memberId', isEqualTo: memberId).snapshots().map((s) {
      final list = s.docs.map((d) => Debt.fromMap(d.id, d.data())).toList();
      return list.where((d) => d.status == 'open').fold<num>(0, (sum, d) => sum + (d.amount ?? 0));
    });
  }

  Stream<List<Debt>> watchByMember(String memberId, {String? status}) {
    final q = _col.where('memberId', isEqualTo: memberId).orderBy('createdAt', descending: true);
    if (status == null) {
      return q.snapshots().map((s) => s.docs.map((d) => Debt.fromMap(d.id, d.data())).toList());
    }
    return q.snapshots().map((s) => s.docs
        .map((d) => Debt.fromMap(d.id, d.data()))
        .where((e) => e.status == status)
        .toList());
  }

  /// createDebt يُستخدم تلقائياً عند إغلاق الـ Weekly إذا كان balance سالب
  Future<void> createDebt({
    required String memberId,
    required String memberName, // صار مطلوب
    required num amount,
    String? reason,
    String? refType,
    String? refId,
    Transaction? tx,
  }) async {
    final data = {
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
      if (reason != null) 'reason': reason,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
      if (refType != null) 'refType': refType,
      if (refId != null) 'refId': refId,
      if (refType == 'monthly' && refId != null) 'monthlyCycleId': refId,
      if (refType == 'weekly' && refId != null) 'weeklyCycleId': refId,
      'payments': <Map<String, dynamic>>[],

    };

    if (tx != null) {
      tx.set(_col.doc(), data);
    } else {
      await _col.add(data);
    }
  }


  Future<String?> createDebtForOrder({
    required String orderId,
    required num amount,
    String? memberId,
    String? memberName,
    String? sessionId,
    String? weeklyCycleId,
    String? monthlyCycleId,
  }) async {
    try {
      // لو موجود دين لنفس الطلب، لا تنشئ واحد جديد
      final exists = await _col
          .where('refType', isEqualTo: 'order')
          .where('refId', isEqualTo: orderId)
          .limit(1)
          .get();
      if (exists.docs.isNotEmpty) return exists.docs.first.id;

      final ref = _col.doc();
      await ref.set({
        if (memberId != null) 'memberId': memberId,
        if (memberName != null) 'memberName': memberName,
        'amount': amount,
        'reason': 'Order',
        'status': 'open',
        'createdAt': DateTime.now().toIso8601String(),
        'refType': 'order',
        'refId': orderId,
        if (sessionId != null) 'sessionId': sessionId,
        if (weeklyCycleId != null) 'weeklyCycleId': weeklyCycleId,
        if (monthlyCycleId != null) 'monthlyCycleId': monthlyCycleId,
        'payments': <Map<String, dynamic>>[],
      });
      return ref.id;
    } catch (_) {
      // ما نكسر الـ flow لو صار خطأ
      return null;
    }
  }

  /// حذف أي دين مرتبط بطلب معيّن
  Future<void> deleteByOrderId(String orderId) async {
    final qs = await _col
        .where('refType', isEqualTo: 'order')
        .where('refId', isEqualTo: orderId)
        .get();
    if (qs.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in qs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// تسوية كل ديون جلسة يومية دفعة واحدة (اختياري للاستخدام عند الإغلاق)
  Future<void> settleDebtsForSession(String sessionId,
      {required String method, String? byName}) async {
    final qs = await _col
        .where('sessionId', isEqualTo: sessionId)
        .where('status', isEqualTo: 'open')
        .get();
    for (final d in qs.docs) {
      await settleAll(d.id, method: method, byName: byName);
    }
  }

  /// Weekly
  Future<void> settleDebtsForWeeklyCycle(String cycleId,
      {required String method, String? byName}) async {
    final qs = await _col
        .where('weeklyCycleId', isEqualTo: cycleId)
        .where('status', isEqualTo: 'open')
        .get();
    for (final d in qs.docs) {
      await settleAll(d.id, method: method, byName: byName);
    }
  }

  /// Monthly
  Future<void> settleDebtsForMonthlyCycle(String cycleId,
      {required String method, String? byName}) async {
    final qs = await _col
        .where('monthlyCycleId', isEqualTo: cycleId)
        .where('status', isEqualTo: 'open')
        .get();
    for (final d in qs.docs) {
      await settleAll(d.id, method: method, byName: byName);
    }
  }

  /// يسدّد كل الديون المفتوحة المرتبطة بمرجع معيّن (جلسة/أسبوع/شهر)
  /// method: 'cash' | 'card' | 'other'
  Future<void> settleByRef({
    required String refType,
    required String refId,
    required String method,
  }) async {
    Query<Map<String, dynamic>> query;
    if (refType == 'monthly') {
      query = _col.where('monthlyCycleId', isEqualTo: refId);
    } else if (refType == 'weekly') {
      query = _col.where('weeklyCycleId', isEqualTo: refId);
    } else {
      query = _col
          .where('refType', isEqualTo: refType)
          .where('refId', isEqualTo: refId);
    }

    final q = await query.where('status', isEqualTo: 'open').get();
    for (final d in q.docs) {
      await settleAll(d.id, method: method);
    }
  }




  // /// يسدد كل الديون المفتوحة المرتبطة بمرجع معيّن (جلسة/أسبوع/شهر)
  // /// method: 'cash' | 'card' | 'other'
  // Future<void> settleByRef({
  //   required String refType,
  //   required String refId,
  //   required String method,
  // }) async {
  //   final uid = auth.currentUser?.uid ?? 'system';
  //   final nowIso = DateTime.now().toIso8601String();
  //
  //   // اسحب الديون المفتوحة لهذا المرجع
  //   final q = await _col
  //       .where('refType', isEqualTo: refType)
  //       .where('refId', isEqualTo: refId)
  //       .where('status', isEqualTo: 'open')
  //       .get();
  //
  //   if (q.docs.isEmpty) return;
  //
  //   final batch = FirebaseFirestore.instance.batch();
  //
  //   for (final d in q.docs) {
  //     final m = d.data();
  //     final total = (m['amount'] ?? 0) as num;
  //
  //     final payments = (m['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  //     final paidSoFar = payments.fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));
  //     final due = total - paidSoFar;
  //     if (due <= 0) {
  //       // ما عليه شيء متبقّي — حوّله مغلق فقط
  //       batch.update(d.reference, {'status': 'settled'});
  //       continue;
  //     }
  //
  //     payments.add({
  //       'amount': due,
  //       'at': nowIso,
  //       'by': uid,
  //       'method': method, // لتقارير الكاش/التطبيق
  //     });
  //
  //     batch.update(d.reference, {
  //       'payments': payments,
  //       'status': 'settled',
  //     });
  //   }
  //
  //   await batch.commit();
  // }




  /// إضافة دفعة (جزئية أو كاملة)
  Future<void> addPayment({
    required String debtId,
    required num amount,
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final ref = fs.doc('debts/$debtId');

      // 1) READS أولًا
      final snap = await tx.get(ref);
      final m = snap.data() as Map<String, dynamic>?;
      if (m == null) return;

      final total = (m['amount'] ?? 0) as num;
      final List<Map<String, dynamic>> payments = ((m['payments'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final paidSoFar = payments.fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));
      final newPaid = paidSoFar + amount;
      final nowIso = DateTime.now().toIso8601String();
      final status = newPaid >= total ? 'settled' : 'open';

      final memberId = (m['memberId'] as String?) ?? '';
      final wRef = memberId.isNotEmpty ? fs.doc('wallets/$memberId') : null;
      final wSnap = wRef != null ? await tx.get(wRef) : null; // READ قبل أي write

      // حضّر الداتا بعد ما خلصت كل القراءات
      final List<Map<String, dynamic>> newPayments = List.of(payments)
        ..add({
          'amount': amount,
          'at': nowIso,
          'by': uid,
        });

      num? currentWallet;
      if (wSnap != null) {
        currentWallet = (wSnap.data()?['balance'] ?? 0) as num;
      }

      // 2) WRITES بعد كل القراءات
      tx.update(ref, {
        'payments': newPayments,
        'status': status,
      });

      if (wRef != null && currentWallet != null && currentWallet < 0) {
        final delta = amount > -currentWallet ? -currentWallet : amount;
        if (delta > 0) {
          tx.set(wRef, {
            'balance': currentWallet + delta,
            'lastBalanceAt': nowIso,
          }, SetOptions(merge: true));

          tx.set(fs.col('wallet_tx').doc(), {
            'memberId': memberId,
            'amount': delta,
            'type': 'topup',
            'note': 'Debt payment',
            'refType': 'debt',
            'refId': debtId,
            'at': nowIso,
          });
        }
      }
    });
  }


  Future<void> settleAll(String debtId, {String? method, String? byName}) async {
    final by = byName ?? (auth.currentUser?.email ?? auth.currentUser?.uid ?? 'system');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final ref = fs.doc('debts/$debtId');

      // 1) READS أولًا
      final snap = await tx.get(ref);
      final m = snap.data() as Map<String, dynamic>?;
      if (m == null) return;

      final total = (m['amount'] ?? 0) as num;
      final List<Map<String, dynamic>> payments = ((m['payments'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final paidSoFar = payments.fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));
      final remaining = total - paidSoFar;
      final nowIso = DateTime.now().toIso8601String();

      final memberId = (m['memberId'] as String?) ?? '';
      final wRef = (memberId.isNotEmpty && remaining > 0) ? fs.doc('wallets/$memberId') : null;
      final wSnap = wRef != null ? await tx.get(wRef) : null; // READ قبل أي write
      final num? currentWallet = wSnap != null ? (wSnap.data()?['balance'] ?? 0) as num : null;

      // حضّر داتا الكتابة
      final List<Map<String, dynamic>> newPayments = List.of(payments);
      if (remaining > 0) {
        newPayments.add({
          'amount': remaining,
          if (method != null) 'method': method,
          'at': nowIso,
          'by': by,
        });
      }

      // 2) WRITES بعد كل القراءات
      tx.update(ref, {
        'payments': newPayments,
        'status': 'settled',
      });

      if (wRef != null && currentWallet != null && currentWallet < 0 && remaining > 0) {
        final delta = remaining > -currentWallet ? -currentWallet : remaining;
        if (delta > 0) {
          tx.set(wRef, {
            'balance': currentWallet + delta,
            'lastBalanceAt': nowIso,
          }, SetOptions(merge: true));

          tx.set(fs.col('wallet_tx').doc(), {
            'memberId': memberId,
            'amount': delta,
            'type': 'topup',
            'note': 'Debt payment',
            'refType': 'debt',
            'refId': debtId,
            'at': nowIso,
          });
        }
      }
    });
  }

  Future<void> delete(String debtId) async {
    await fs.delete('debts/$debtId');
  }

  Future<num> openTotalByRef({required String refType, required String refId}) async {
    Query<Map<String, dynamic>> query;
    if (refType == 'monthly') {
      query = _col.where('monthlyCycleId', isEqualTo: refId);
    } else if (refType == 'weekly') {
      query = _col.where('weeklyCycleId', isEqualTo: refId);
    } else {
      query = _col
          .where('refType', isEqualTo: refType)
          .where('refId', isEqualTo: refId);
    }
    final q = await query.where('status', isEqualTo: 'open').get();
    num total = 0;
    for (final d in q.docs) {
      final m = d.data();
      final amount = (m['amount'] ?? 0) as num;
      final payments = (m['payments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final paidSoFar = payments.fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));
      total += (amount - paidSoFar);
    }
    return total;
  }}
