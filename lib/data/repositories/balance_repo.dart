import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/balance_tx.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class BalanceChargeResult {
  final num deducted;   // قد يكون 0
  final num debtCreated; // قد يكون 0
  final String? debtId;
  const BalanceChargeResult({
    required this.deducted,
    required this.debtCreated,
    this.debtId,
  });
}

class BalanceRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _txCol => fs.col('balance_tx');

  // ===== قراءة الرصيد =====

  Future<num> getBalance(String memberId) async {
    final snap = await fs.getDoc('members/$memberId');
    final m = snap.data();
    return (m?['balance'] ?? 0) as num;
    // لو ما في الحقل اصلا، القيمة الافتراضية 0.
  }

  Stream<num> watchBalance(String memberId) {
    return fs.watchDoc('members/$memberId').map((ds) {
      final m = ds.data();
      return (m?['balance'] ?? 0) as num;
    });
  }


  Future<BalanceChargeResult> chargeAmountAllowNegative({
    required String memberId,
    required num cost,
    required String reason,   // مثال: 'Monthly fee'
    required String refType,  // 'monthly' | 'weekly' | 'session' | ...
    required String refId,
  }) async {
    if (cost <= 0) {
      return const BalanceChargeResult(deducted: 0, debtCreated: 0);
    }

    final uid = auth.currentUser?.uid ?? 'system';
    final nowIso = DateTime.now().toIso8601String();

    String? debtId;
    num deducted = 0;
    num debtCreated = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // اقرأ العضو قبل الكتابة (للاسم في الدين)
      final mRef = fs.doc('members/$memberId');
      final mSnap = await tx.get(mRef);
      final m = mSnap.data() as Map<String, dynamic>?;

      final current = (m?['balance'] ?? 0) as num;
      final memberName = (m?['name'] as String?) ?? '';

      final newBal = current - cost; // قد يصبح سالب
      deducted = cost;

      // 1) حدّث الرصيد (قد يكون سالب)
      tx.update(mRef, {'balance': newBal, 'lastBalanceAt': nowIso});

      // 2) لوق الخصم في balance_tx
      final txRef = _txCol.doc();
      tx.set(txRef, {
        'memberId': memberId,
        'type': 'debit',
        'amount': cost,
        'reason': reason,
        'refType': refType,
        'refId': refId,
        'createdAt': nowIso,
        'createdBy': uid,
      });

      // 3) لو صار سالب => أنشئ دين بالباقي (قيمة موجبة)
      if (newBal < 0) {
        debtCreated = -newBal;
        final debtRef = fs.col('debts').doc();
        debtId = debtRef.id;
        tx.set(debtRef, {
          'memberId': memberId,
          if (memberName.isNotEmpty) 'memberName': memberName,
          'amount': debtCreated,
          'reason': reason,
          'status': 'open',
          'createdAt': nowIso,
          'refType': refType,
          'refId': refId,
          'payments': <Map<String, dynamic>>[],
        });
      }
    });

    return BalanceChargeResult(deducted: deducted, debtCreated: debtCreated, debtId: debtId);
  }

  // ===== حركات الرصيد =====

  /// تاريخ الحركات لعضو (بدون فهارس مركبة: where فقط، ونرتب على الكلاينت)
  Stream<List<BalanceTx>> watchTxByMember(String memberId) {
    return _txCol.where('memberId', isEqualTo: memberId).snapshots().map(
          (q) {
        final list = q.docs
            .map((d) => BalanceTx.fromMap(d.id, d.data()))
            .toList(growable: false);
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      },
    );
  }

  // ===== عمليات على الرصيد =====

  /// شحن رصيد (Top-up). amount يجب أن يكون > 0
  Future<void> addCreditTopUp({
    required String memberId,
    required num amount,
    String reason = 'Top-up',
    String? refType,
    String? refId,
  }) async {
    if (amount <= 0) return;
    final uid = auth.currentUser?.uid ?? 'system';
    final now = DateTime.now();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mRef = fs.doc('members/$memberId');
      final snap = await tx.get(mRef);
      final m = snap.data() as Map<String, dynamic>?;

      final current = (m?['balance'] ?? 0) as num;
      final newBal = current + amount;

      tx.update(mRef, {
        'balance': newBal,
        'lastBalanceAt': now.toIso8601String(),
      });

      final logRef = _txCol.doc();
      tx.set(logRef, {
        'memberId': memberId,
        'type': 'credit',
        'amount': amount,
        'reason': reason,
        if (refType != null) 'refType': refType,
        if (refId != null) 'refId': refId,
        'createdAt': now.toIso8601String(),
        'createdBy': uid,
      });
    });
  }

  /// تعديل يدوي (لـ admin): delta قد يكون موجب/سالب.
  Future<void> adjust({
    required String memberId,
    required num delta,
    String reason = 'Adjust',
  }) async {
    if (delta == 0) return;
    final uid = auth.currentUser?.uid ?? 'system';
    final now = DateTime.now();
    final abs = delta.abs();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mRef = fs.doc('members/$memberId');
      final snap = await tx.get(mRef);
      final m = snap.data() as Map<String, dynamic>?;

      final current = (m?['balance'] ?? 0) as num;
      final newBal = current + delta;
      final finalBal = newBal < 0 ? 0 : newBal; // ما نخلي رصيد سالب بتعديل يدوي

      tx.update(mRef, {
        'balance': finalBal,
        'lastBalanceAt': now.toIso8601String(),
      });

      final logRef = _txCol.doc();
      tx.set(logRef, {
        'memberId': memberId,
        'type': 'adjust',
        'amount': abs,
        'reason': reason,
        'refType': null,
        'refId': null,
        'createdAt': now.toIso8601String(),
        'createdBy': uid,
      });
    });
  }

  /// خصم تكلفة من الرصيد، وإن ما كفى: ينشئ دين بالباقي ويصفّر الرصيد.
  /// ترجع نتيجة مفصّلة (كم انخصم وكم صار دين).
  Future<BalanceChargeResult> deductOrDebt({
    required String memberId,
    required num cost,
    String reason = 'Charge',
    String? refType, // 'session' | 'weekly' | 'monthly' | ...
    String? refId,
  }) async {
    if (cost <= 0) {
      return const BalanceChargeResult(deducted: 0, debtCreated: 0);
    }
    final uid = auth.currentUser?.uid ?? 'system';
    final now = DateTime.now();

    String? createdDebtId;
    num deducted = 0;
    num debtCreated = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final mRef = fs.doc('members/$memberId');
      final mSnap = await tx.get(mRef);
      final m = mSnap.data() as Map<String, dynamic>?;

      final current = (m?['balance'] ?? 0) as num;

      if (current >= cost) {
        // الرصيد يغطي كامل التكلفة
        deducted = cost;
        final newBal = current - cost;

        tx.update(mRef, {
          'balance': newBal,
          'lastBalanceAt': now.toIso8601String(),
        });

        final logRef = _txCol.doc();
        tx.set(logRef, {
          'memberId': memberId,
          'type': 'debit',
          'amount': cost,
          'reason': reason,
          if (refType != null) 'refType': refType,
          if (refId != null) 'refId': refId,
          'createdAt': now.toIso8601String(),
          'createdBy': uid,
        });
      } else {
        // الرصيد لا يغطي: نخصم الموجود وننشئ دين بالباقي
        deducted = current; // قد يكون 0
        debtCreated = cost - current;

        // صفّر الرصيد
        tx.update(mRef, {
          'balance': 0,
          'lastBalanceAt': now.toIso8601String(),
        });

        // سجّل عملية الخصم بما تبقى من الرصيد (إن وجد)
        if (deducted > 0) {
          final logRef = _txCol.doc();
          tx.set(logRef, {
            'memberId': memberId,
            'type': 'debit',
            'amount': deducted,
            'reason': reason,
            if (refType != null) 'refType': refType,
            if (refId != null) 'refId': refId,
            'createdAt': now.toIso8601String(),
            'createdBy': uid,
          });
        }

        // أنشئ دين بالباقي
        final debtRef = fs.col('debts').doc();
        createdDebtId = debtRef.id;
        tx.set(debtRef, {
          'memberId': memberId,
          'amount': debtCreated,
          'reason': reason,
          'status': 'open',
          'createdAt': now.toIso8601String(),
          if (refType != null) 'refType': refType,
          if (refId != null) 'refId': refId,
          'payments': <Map<String, dynamic>>[],
        });
      }
    });

    return BalanceChargeResult(
      deducted: deducted,
      debtCreated: debtCreated,
      debtId: createdDebtId,
    );
  }

  // ===== مساعدات جاهزة لحالات خاصة =====

  /// اعتماد الدفع المقدّم لدورة أسبوعية/شهرية كـ credit للرصيد
  Future<void> addPrepaidCredit({
    required String memberId,
    required num amount,
    required String cycleType, // 'weekly' | 'monthly'
    required String cycleId,
  }) async {
    if (amount <= 0) return;
    await addCreditTopUp(
      memberId: memberId,
      amount: amount,
      reason: '${cycleType[0].toUpperCase()}${cycleType.substring(1)} prepaid',
      refType: cycleType,
      refId: cycleId,
    );
  }

  /// خصم تكلفة جلسة يومية مباشرة من الرصيد (وتوليد دين لو ما كفى)
  Future<BalanceChargeResult> chargeSession({
    required String memberId,
    required String sessionId,
    required num grandTotal,
  }) {
    return deductOrDebt(
      memberId: memberId,
      cost: grandTotal,
      reason: 'Session charge',
      refType: 'session',
      refId: sessionId,
    );
  }

  /// خصم تكلفة مشروبات دورة أسبوعية/شهرية عند الإغلاق
  Future<BalanceChargeResult> chargeCycle({
    required String memberId,
    required String cycleType, // 'weekly' | 'monthly'
    required String cycleId,
    required num drinksTotalAfterDiscounts,
  }) {
    return deductOrDebt(
      memberId: memberId,
      cost: drinksTotalAfterDiscounts,
      reason: '${cycleType[0].toUpperCase()}${cycleType.substring(1)} drinks',
      refType: cycleType,
      refId: cycleId,
    );
  }
}
