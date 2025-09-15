import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class WalletChargeResult {
  final num deducted;     // كم انخصم من الرصيد
  final num debtCreated;  // دين منشأ إن وُجد
  final num preBalance;   // الرصيد قبل
  final num postBalance;  // الرصيد بعد
  const WalletChargeResult({
    required this.deducted,
    required this.debtCreated,
    required this.preBalance,
    required this.postBalance,
  });
}

class WalletRepo {
  final fs = FirestoreService();
  CollectionReference<Map<String, dynamic>> get _wallets => fs.col('wallets');
  CollectionReference<Map<String, dynamic>> get _tx => fs.col('wallet_tx');

  // Stream<num> watchBalance(String memberId) {
  //   return _wallets.doc(memberId).snapshots().map((d) {
  //     final m = d.data();
  //     return (m?['balance'] ?? 0) as num;
  //   });
  // }

  Future<num> getBalance(String memberId) async {
    final d = await fs.getDoc('wallets/$memberId');
    final m = d.data();
    return (m?['balance'] ?? 0) as num;
  }

  Future<void> topUp({
    required String memberId,
    required num amount,
    String? note,
    String? refType, // NEW (اختياري)
    String? refId,   // NEW (اختياري)
  }) async {
    final now = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final wRef = fs.doc('wallets/$memberId');
      final wSnap = await tx.get(wRef);
      final pre = (wSnap.data()?['balance'] ?? 0) as num;
      final post = pre + amount;

      final debt = post < 0 ? -post : 0;
      if (debt > 0) {
        // الرصيد غير كافٍ → أنشئ دين بالباقي وحدّث الرصيد إلى صفر
        tx.set(wRef, {
          'balance': 0,
          'lastBalanceAt': now,
        }, SetOptions(merge: true));

        tx.set(fs.col('debts').doc(), {
          'memberId': memberId,
          'amount': debt,
          'reason': note ?? 'wallet_topup',
          'status': 'open',
          'createdAt': now,
          if (refType != null) 'refType': refType,
          if (refId != null) 'refId': refId,
          'payments': <Map<String, dynamic>>[],
        });
      } else {
        // لا يوجد دين → حدّث الرصيد كالمعتاد
        tx.set(wRef, {
          'balance': post,
          'lastBalanceAt': now,
        }, SetOptions(merge: true));
      }

      final noteWithDebt = () {
        if (debt <= 0) return note;
        final debtMsg = 'إنشاء دين ₪ ${debt.toString()}';
        if (note == null || note.isEmpty) return debtMsg;
        return '$note - $debtMsg';
      }();

      tx.set(_tx.doc(), {
        'memberId': memberId,
        'amount': amount,
        'type': 'topup',
        if (noteWithDebt != null) 'note': noteWithDebt,
        if (refType != null) 'refType': refType, // NEW
        if (refId != null) 'refId': refId,       // NEW
        'at': now,
      });
    });
  }

  /// يخصم المبلغ (amountDue) للأسبوعي/الشهري فقط.
  /// لو الرصيد أقل → يخصم كل المتاح ويُنشئ دين بالباقي.
  Future<WalletChargeResult> charge({
    required String memberId,
    required num amountDue,
    required String refType, // 'weekly' | 'monthly'
    required String refId,
  }) async {
    num pre = 0, post = 0, deducted = 0, debt = 0;
    final now = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final wRef = fs.doc('wallets/$memberId');
      final wSnap = await tx.get(wRef);
      pre = (wSnap.data()?['balance'] ?? 0) as num;

      if (pre >= amountDue) {
        deducted = amountDue;
        post = pre - amountDue;
        tx.set(wRef, {'balance': post}, SetOptions(merge: true));
        tx.set(_tx.doc(), {
          'memberId': memberId,
          'amount': -deducted,
          'type': 'charge',
          'refType': refType,
          'refId': refId,
          'at': now,
        });
      } else {
        deducted = pre;
        post = 0;
        debt = amountDue - pre;

        tx.set(wRef, {'balance': post}, SetOptions(merge: true));
        if (deducted > 0) {
          tx.set(_tx.doc(), {
            'memberId': memberId,
            'amount': -deducted,
            'type': 'charge',
            'refType': refType,
            'refId': refId,
            'at': now,
          });
        }

        // أنشئ دين بالباقي (بدون استدعاء ريبوز تانية عشان نظافة الترانزاكشن)
        final mRef = fs.doc('members/$memberId');
        final mSnap = await tx.get(mRef);
        final memberName = (mSnap.data()?['name'] as String?) ?? '';
        final debtRef = fs.col('debts').doc();
        tx.set(debtRef, {
          'memberId': memberId,
          'amount': debt,
          'memberName': memberName,
          'reason': '$refType:$refId',
          'status': 'open',
          'createdAt': now,
          'refType': refType,
          'refId': refId,
          if (refType == 'monthly') 'monthlyCycleId': refId,
          if (refType == 'weekly') 'weeklyCycleId': refId,
          'payments': <Map<String, dynamic>>[],
        });
      }
    });

    return WalletChargeResult(
      deducted: deducted,
      debtCreated: debt,
      preBalance: pre,
      postBalance: post,
    );
  }


  /// يعتمد المبلغ كمقدم (Top-up) ويربطه بمرجع الدورة
  Future<void> addPrepaidCredit({
    required String memberId,
    required num amount,
    required String cycleType, // 'monthly' | 'weekly'
    required String cycleId,
  }) async {
    if (amount <= 0) return;

    final now = DateTime.now().toIso8601String();
    final wRef = fs.doc('wallets/$memberId');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // اقرأ الرصيد الحالي
      final wSnap = await tx.get(wRef);
      final current = (wSnap.data()?['balance'] ?? 0) as num;
      final newBal = current + amount;

      // حدّث الرصيد
      tx.set(wRef, {
        'balance': newBal,
        'lastBalanceAt': now,
      }, SetOptions(merge: true));

      // سجّل حركة شحن wallet_tx
      tx.set(fs.col('wallet_tx').doc(), {
        'memberId': memberId,
        'type': 'topup',
        'amount': amount,
        'note': '${cycleType}_prepaid',
        'refType': cycleType,
        'refId': cycleId,
        'at': now,
      });
    });
  }

  /// لو صار الرصيد سالب، ينشئ دين بالباقي (قيمة موجبة) ويعيد نتيجة الخصم.
  Future<WalletChargeResult> chargeAmountAllowNegative({
    required String memberId,
    required num cost,
    required String reason, // مثال: 'Monthly fee'
    required String refType, // 'monthly' | 'weekly' | 'session' ...
    required String refId,
  }) async {
    if (cost <= 0) {
      final bal = await getBalanceOnce(memberId);
      return WalletChargeResult(
        deducted: 0,
        debtCreated: 0,
        preBalance: bal,
        postBalance: bal,
      );
    }

    final now = DateTime.now().toIso8601String();

    num pre = 0, post = 0, debtCreated = 0;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // 1) اقرأ المحفظة + اسم العضو للاستخدام في الدين
      final wRef = fs.doc('wallets/$memberId');
      final wSnap = await tx.get(wRef);
      pre = (wSnap.data()?['balance'] ?? 0) as num;

      final mRef = fs.doc('members/$memberId');
      final mSnap = await tx.get(mRef);
      final memberName = (mSnap.data()?['name'] as String?) ?? '';

      // 2) خصم كامل
      post = pre - cost;

      // 3) حدّث الرصيد (قد يصبح سالب)
      tx.set(wRef, {
        'balance': post,
        'lastBalanceAt': now,
      }, SetOptions(merge: true));

      // 4) لوق الخصم
      tx.set(fs.col('wallet_tx').doc(), {
        'memberId': memberId,
        'type': 'charge',
        'amount': -cost, // نكتبها سالبة في اللوق (اتجاه خصم)
        'note': reason,
        'refType': refType,
        'refId': refId,
        'at': now,
      });

      // 5) إن صار سالب => أنشئ دين بالمقدار الموجب الباقي
      if (post < 0) {
        debtCreated = -post; // قيمة موجبة
        tx.set(fs.col('debts').doc(), {
          'memberId': memberId,
          if (memberName.isNotEmpty) 'memberName': memberName,
          'amount': debtCreated,
          'reason': reason,
          'status': 'open',
          'createdAt': now,
          'refType': refType,
          'refId': refId,
          if (refType == 'monthly') 'monthlyCycleId': refId,
          if (refType == 'weekly') 'weeklyCycleId': refId,
          'payments': <Map<String, dynamic>>[],
        });

      }
    });
    return WalletChargeResult(
      deducted: cost,
      debtCreated: debtCreated,
      preBalance: pre,
      postBalance: post,
    );
  }



  Stream<num> watchBalance(String memberId) {
    return fs.watchDoc('wallets/$memberId').map((ds) {
      final m = ds.data();
      return (m?['balance'] ?? 0) as num;
    });
  }

  Future<num> getBalanceOnce(String memberId) async {
    final snap = await fs.getDoc('wallets/$memberId');
    final m = snap.data();
    return (m?['balance'] ?? 0) as num;
  }
}
