import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elevate_hub/data/repositories/settings_repo.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/monthly_cycle.dart';
import 'wallet_repo.dart';
import 'monthly_days_repo.dart';

class MonthlyCloseResult {
  final num drinksTotal;
  final num priceAtStart;
  final int daysUsed;
  const MonthlyCloseResult({
    required this.drinksTotal,
    required this.priceAtStart,
    required this.daysUsed,
  });
}

class MonthlyCyclesRepo {
  final fs = FirestoreService();
  final auth = AuthService();
  final wallet = WalletRepo();
  final daysRepo = MonthlyDaysRepo();
  final settings = SettingsRepo();


  // Future<String> startWithPrepaidAndAutoCharge({
  //   required String memberId,
  //   required String memberName,
  //   required num prepaidAmount, // مثال: 100
  // }) async {
  //   // 1) أنشئ الدورة
  //   final cycleId = await startCycle(memberId: memberId, memberName: memberName);
  //
  //   // 2) اعتمد المقدم (إن وُجد) كـ top-up مرتبط بالدورة
  //   if (prepaidAmount > 0) {
  //     await wallet.addPrepaidCredit(
  //       memberId: memberId,
  //       amount: prepaidAmount,
  //       cycleType: 'monthly',
  //       cycleId: cycleId,
  //     );
  //   }
  //
  //   // 3) اقرأ سعر الشهري من الإعدادات
  //   final sSnap = await fs.getDoc('settings/app');
  //   final sm = sSnap.data();
  //   final monthlyPrice = (sm?['prices']?['monthly'] ?? 0) as num;
  //
  //   // 4) اخصم السعر كاملًا مع السماح بالسالب + توليد دين بالباقي
  //   await wallet.chargeAmountAllowNegative(
  //     memberId: memberId,
  //     cost: monthlyPrice,
  //     reason: 'Monthly fee',
  //     refType: 'monthly',
  //     refId: cycleId,
  //   );
  //
  //   return cycleId;
  // }








  CollectionReference<Map<String, dynamic>> get _col => fs.col('monthly_cycles');
  CollectionReference<Map<String, dynamic>> get _days => fs.col('monthly_days');

  String _dateKey(DateTime d) => d.toIso8601String().substring(0,10); // YYYY-MM-DD

  Future<num> _fetchMonthlyPrice() async {
    final s = await fs.getDoc('settings/app');
    final m = s.data();
    return (m?['prices']?['monthly'] ?? 0) as num;
  }

  Stream<List<MonthlyCycle>> watchByMember(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => MonthlyCycle.fromMap(d.id, d.data())).toList());
  }

  Stream<MonthlyCycle?> watchActiveCycleForMember(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: 'active')
        .orderBy('startDate', descending: true)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isEmpty ? null : MonthlyCycle.fromMap(q.docs.first.id, q.docs.first.data()));
  }

  Future<String> startCycle({
    required String memberId,
    required String memberName,
    num? price,
    num? dayCost,
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final p = price ?? await _fetchMonthlyPrice();
    final dc = dayCost ?? p / 26;

    final doc = await _col.add({
      'memberId': memberId,
      'startDate': DateTime.now().toIso8601String(),
      'days': 26,
      'drinksTotal': 0,
      'status': 'active',
      'priceAtStart': p,
      'memberName': memberName,
      'dayCost': dc,
      'daysUsed': 0,
      'openDayId': null,
      'createdBy': uid,
    });
    return doc.id;
  }

  Future<String> startDay(String cycleId) async {
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final already = await daysRepo.existsForDate(cycleId: cycleId, dateKey: todayKey);
    if (already) {
      throw Exception('You already used a day today.');
    }

    late String dayId;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final cref = fs.doc('monthly_cycles/$cycleId');
      final csnap = await tx.get(cref);
      final c = csnap.data();
      if (c == null) { throw Exception('Cycle not found'); }

      if ((c['status'] ?? 'active') != 'active') {
        throw Exception('Cycle is not active');
      }
      final int days = (c['days'] ?? 26) as int;
      final int used = (c['daysUsed'] ?? 0) as int;
      final String? openDayId = c['openDayId'] as String?;
      if (openDayId != null) {
        throw Exception('A day is already open.');
      }
      if (used >= days) {
        throw Exception('No remaining days.');
      }

      final memberId = (c['memberId'] ?? '') as String;
      final memberName = (c['memberName'] ?? '') as String;
      final expectedCloseAt = now.add(const Duration(hours: 8));

      final dref = fs.col('monthly_days').doc();
      tx.set(dref, {
        'cycleId': cycleId,
        'memberId': memberId,
        'memberName': memberName,
        'dateKey': todayKey,
        'startAt': now.toIso8601String(),
        'expectedCloseAt': expectedCloseAt.toIso8601String(),
        'status': 'open',
        'dayCost': (c['dayCost'] ?? 0),
      });

      tx.update(cref, {'openDayId': dref.id});
      dayId = dref.id;
    });

    return dayId;
  }



  Future<String> startWithPrepaidAndAutoCharge({
    required String memberId,
    required String memberName,
    required num prepaidAmount,
  }) async {
    // أنشئ الدورة
    // السعر الشهري مرة واحدة (للاستخدام في كل الخطوات)
    final monthlyPrice = await _fetchMonthlyPrice();
    final dayCost = monthlyPrice / 26;

    // أنشئ الدورة مع تمرير السعر وتكلفة اليوم
    final cycleId = await startCycle(
      memberId: memberId,
      memberName: memberName,
      price: monthlyPrice,
      dayCost: dayCost,
    );

    // سجّل المقدم في المحفظة (إن وجد)
    if (prepaidAmount > 0) {
      await wallet.topUp(
        memberId: memberId,
        amount: prepaidAmount,
        note: 'Monthly prepaid',
        refType: 'monthly',
        refId: cycleId,
      );
    }

    // خصم السعر الشهري من المحفظة مع السماح بالسالب (يُنشأ دين تلقائيًا عند عدم كفاية الرصيد)
    await wallet.chargeAmountAllowNegative(
      memberId: memberId,
      cost: monthlyPrice,
      reason: 'Monthly fee',
      refType: 'monthly',
      refId: cycleId,
    );

    return cycleId;
  }



  Future<void> closeOpenDay(String cycleId) async {
    // 1) استعلام خارج الترانزكشن للحصول على مرجع الدين (إن وُجد)
    final preDebtQ = await fs
        .col('debts')
        .where('refType', isEqualTo: 'monthly')
        .where('refId', isEqualTo: cycleId)
        .limit(1)
        .get();

    final DocumentReference<Map<String, dynamic>>? debtRef =
    preDebtQ.docs.isNotEmpty ? preDebtQ.docs.first.reference : null;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // ===== READS =====
      final cref = fs.doc('monthly_cycles/$cycleId');
      final csnap = await tx.get(cref);
      final c = csnap.data();
      if (c == null) return;

      final String? openDayId = c['openDayId'] as String?;
      if (openDayId == null) return;

      final dref = fs.doc('monthly_days/$openDayId');
      final dsnap = await tx.get(dref);
      final d = dsnap.data();
      if (d == null) return;
      if ((d['status'] ?? 'open') != 'open') return;

      final now = DateTime.now();
      final memberId = (c['memberId'] ?? '') as String;
      final used = (c['daysUsed'] ?? 0) as int;

      // تكلفة اليوم
      final num dayCost = (d['dayCost'] ?? c['dayCost'] ?? 0) as num;

      // رصيد المحفظة الحالي
      final wRef = fs.doc('wallets/$memberId');
      final wSnap = await tx.get(wRef);
      final currentBal = (wSnap.data()?['balance'] ?? 0) as num;

      // اقرأ الدين (إن وُجد) الآن من داخل الترانزكشن باستخدام DocumentReference
      Map<String, dynamic>? debt;
      if (debtRef != null) {
        final debtSnap = await tx.get(debtRef);
        if (debtSnap.exists) {
          debt = debtSnap.data();
        }
      }

      // كم سنخصم؟ لا نجعل الرصيد سالب بسبب اليوم
      final toDeduct = (currentBal > 0)
          ? (currentBal >= dayCost ? dayCost : currentBal)
          : 0;

      // ===== WRITES =====
      // إغلاق اليوم + زيادة daysUsed
      tx.update(dref, {
        'status': 'closed',
        'stopAt': now.toIso8601String(),
      });
      tx.update(cref, {
        'openDayId': null,
        'daysUsed': used + 1,
      });

      // خصم من المحفظة بدون سالب
      if (toDeduct > 0) {
        tx.set(wRef, {
          'balance': FieldValue.increment(-toDeduct),
          'lastBalanceAt': now.toIso8601String(),
        }, SetOptions(merge: true));

        tx.set(fs.col('wallet_tx').doc(), {
          'memberId': memberId,
          'amount': -toDeduct,
          'type': 'charge',
          'note': 'monthly-day',
          'refType': 'monthly',
          'refId': cycleId,
          'at': now.toIso8601String(),
        });

        // تخفيض الدين المرتبط بالدورة إن وُجد
        if (debtRef != null && debt != null) {
          final total = (debt['amount'] ?? 0) as num;
          final payments =
              (debt['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final paidSoFar =
          payments.fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));
          final remain = total - paidSoFar;
          final payAmount = toDeduct >= remain ? remain : toDeduct;

          if (payAmount > 0) {
            payments.add({
              'amount': payAmount,
              'at': now.toIso8601String(),
              'by': auth.currentUser?.uid ?? 'system',
              'method': 'wallet',
            });

            final newStatus = (remain - payAmount) <= 0 ? 'settled' : 'open';
            tx.update(debtRef, {
              'payments': payments,
              'status': newStatus,
            });
          }
        }
      }

      // ⚠️ لا ننشئ دين جديد هنا إطلاقًا
      // ✅ الدين لو موجود فهو مسجّل عند بداية الدورة فقط.
    });
  }





  Future<void> ensureAutoClose(String cycleId) async {
    final cref = fs.doc('monthly_cycles/$cycleId');
    final csnap = await cref.get();
    final c = csnap.data();
    if (c == null) return;
    final openDayId = c['openDayId'] as String?;
    if (openDayId == null) return;

    final dref = fs.doc('monthly_days/$openDayId');
    final dsnap = await dref.get();
    final d = dsnap.data();
    if (d == null) return;
    if ((d['status'] ?? 'open') != 'open') return;

    final expectedCloseAt = DateTime.tryParse(d['expectedCloseAt']?.toString() ?? '');
    if (expectedCloseAt == null) return;

    if (DateTime.now().isAfter(expectedCloseAt)) {
      await closeOpenDay(cycleId);
    }
  }

  Future<MonthlyCloseResult> closeCycle(String cycleId) async {
    final ref = fs.doc('monthly_cycles/$cycleId');
    final snap = await ref.get();
    final m = snap.data();
    if (m == null) {
      throw Exception('Monthly cycle not found');
    }

    await ensureAutoClose(cycleId);

    final priceAtStart = (m['priceAtStart'] ?? 0) as num;
    final drinks = (m['drinksTotal'] ?? 0) as num;
    final daysUsed = (m['daysUsed'] ?? 0) as int;

    await ref.update({'status': 'closed', 'openDayId': null});

    return MonthlyCloseResult(
      drinksTotal: drinks,
      priceAtStart: priceAtStart,
      daysUsed: daysUsed,
    );
  }
}
