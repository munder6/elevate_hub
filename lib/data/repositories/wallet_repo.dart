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
    String? refType, // اختياري
    String? refId,   // اختياري
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1) جيب مراجع الديون المفتوحة أقدم فأحدث (خارج الترانزاكشن فقط لاستخراج الـ refs)
    final openDebtsQs = await fs.col('debts')
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: false) // FIFO
        .get();
    final debtRefs = openDebtsQs.docs.map((d) => d.reference).toList();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // ===== READS أولاً =====
      final wRef = fs.doc('wallets/$memberId');
      final wSnap = await tx.get(wRef);
      num pre = (wSnap.data()?['balance'] ?? 0) as num;

      // اقرأ كل وثائق الديون داخل الترانزاكشن (للالتزام بشروط القراءة قبل الكتابة)
      final debtSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in debtRefs) {
        debtSnaps.add(await tx.get(ref));
      }

      // ===== احسب التوزيع قبل أي write =====
      num pool = amount;                 // المبلغ المتاح من الشحن لتسديد الديون حسب FIFO
      num currentWallet = pre + amount;  // الرصيد بعد الشحن (سنعدله إن كان سالب أثناء التسديد)
      final paymentsUpdates = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
      final walletTxWrites = <Map<String, dynamic>>[];

      for (int i = 0; i < debtSnaps.length; i++) {
        if (pool <= 0) break;
        final snap = debtSnaps[i];
        if (!snap.exists) continue;
        final m = snap.data()!;
        final total = (m['amount'] ?? 0) as num;

        // payments الحالية كـ List<Map>
        final existingPayments = ((m['payments'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final paidSoFar = existingPayments.fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));
        final remaining = total - paidSoFar;
        if (remaining <= 0) continue;

        final pay = pool >= remaining ? remaining : pool;
        pool -= pay;

        // سنضيف دفعة جديدة بسبب الشحن
        final newPayments = List<Map<String, dynamic>>.from(existingPayments)
          ..add({
            'amount': pay,
            'at': now,
            'by': 'system',            // أو مرّر اسم/معرّف الموظف لو بدك
            'method': 'wallet_topup',  // تمييز إنها سُدِّدت من الشحن
          });

        final willSettle = (remaining - pay) <= 0;
        paymentsUpdates[snap.reference] = {
          'payments': newPayments,
          if (willSettle) 'status': 'settled',
        };

        // لو المحفظة ما زالت سالبة، ارفعها تدريجيًا بنفس منطق addPayment/settleAll
        if (currentWallet < 0) {
          final delta = pay > -currentWallet ? -currentWallet : pay; // كم نقدر نرفع
          if (delta > 0) {
            currentWallet += delta; // نقربها للصفر
            walletTxWrites.add({
              'memberId': memberId,
              'amount': delta,
              'type': 'topup',
              'note': 'Debt payment',
              'refType': 'debt',
              'refId': snap.id,
              'at': now,
            });
          }
        }
      }

      // ===== WRITES بعد الانتهاء من كل القراءات والحسابات =====

      // 1) حدّث الرصيد بعد الشحن + أي زيادات حصلت أثناء رفع السالب
      tx.set(wRef, {
        'balance': currentWallet,
        'lastBalanceAt': now,
      }, SetOptions(merge: true));

      // 2) سجّل حركة الشحن الأساسية
      tx.set(_tx.doc(), {
        'memberId': memberId,
        'amount': amount,
        'type': 'topup',
        if (note != null && note.isNotEmpty) 'note': note,
        if (refType != null) 'refType': refType,
        if (refId != null) 'refId': refId,
        'at': now,
      });

      // 3) سجّل أي حركات topup إضافية نتجت عن تسديد الديون ورفع السالب
      for (final row in walletTxWrites) {
        tx.set(_tx.doc(), row);
      }

      // 4) طبّق تحديثات الديون (payments + status)
      paymentsUpdates.forEach((ref, update) {
        tx.update(ref, update);
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
