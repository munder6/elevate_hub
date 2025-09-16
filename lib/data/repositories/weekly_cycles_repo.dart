import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/weekly_cycle.dart';
import '../models/plan.dart';
import '../models/subscription_category.dart';
import 'debts_repo.dart';
import 'wallet_repo.dart';
import 'weekly_days_repo.dart';
import 'plans_repo.dart';

class WeeklyCloseResult {
  final num drinksTotal;
  final num priceAtStart;
  final int daysUsed;
  const WeeklyCloseResult({
    required this.drinksTotal,
    required this.priceAtStart,
    required this.daysUsed,
  });
}

class WeeklyCyclesRepo {
  final fs = FirestoreService();
  final auth = AuthService();
  final wallet = WalletRepo();
  final daysRepo = WeeklyDaysRepo();
  final plansRepo = PlansRepo();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('weekly_cycles');
  CollectionReference<Map<String, dynamic>> get _days => fs.col('weekly_days');

  String _dateKey(DateTime d) => d.toIso8601String().substring(0, 10); // YYYY-MM-DD

  Future<num> _weeklyPriceFromSettings() async {
    final s = await fs.getDoc('settings/app');
    final m = s.data();
    return (m?['prices']?['weekly'] ?? 0) as num; // تأكد أنه موجود
  }

  Stream<List<WeeklyCycle>> watchByMember(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => WeeklyCycle.fromMap(d.id, d.data())).toList());
  }

  Future<String> _createCycleFromPlan({
    required String memberId,
    required String memberName,
    required Plan plan,
  }) async {
    if (plan.daysCount <= 0) {
      throw Exception('Weekly plan must have daysCount > 0');
    }
    final uid = auth.currentUser?.uid ?? 'system';
    final dayCost = plan.price / plan.daysCount;

    final doc = await _col.add({
      'memberId': memberId,
      'startDate': DateTime.now().toIso8601String(),
      'days': plan.daysCount,
      'drinksTotal': 0,
      'memberName': memberName,
      'status': 'active',
      'priceAtStart': plan.price,
      'dayCost': dayCost,
      'daysUsed': 0,
      'openDayId': null,
      'createdBy': uid,
      'planId': plan.id,
      'planTitleSnapshot': plan.title,
      'bandwidthMbpsSnapshot': plan.bandwidthMbps,
    });
    return doc.id;
  }

  /// يبدأ دورة أسبوعية وفق الخطة المحددة أو يرجع للسعر القديم (Deprecated).
  Future<String> startCycle({
    required String memberId,
    required String memberName,
    String? planId,
    @Deprecated('Use planId instead') num? price,
    @Deprecated('Use planId instead') num? dayCost,
  }) async {
    if (planId != null) {
      final plan = await plansRepo.requireActivePlan(
        planId,
        allowedCategories: const [SubscriptionCategory.weekly],
      );
      return _createCycleFromPlan(
        memberId: memberId,
        memberName: memberName,
        plan: plan,
      );
    }

    final uid = auth.currentUser?.uid ?? 'system';
    final p = price ?? await _weeklyPriceFromSettings();
    final dc = dayCost ?? p / 6;

    final doc = await _col.add({
      'memberId': memberId,
      'startDate': DateTime.now().toIso8601String(),
      'days': 6,
      'drinksTotal': 0,
      'memberName': memberName,
      'status': 'active',
      'priceAtStart': p,
      'dayCost': dc,
      'daysUsed': 0,
      'openDayId': null,
      'createdBy': uid,
    });
    return doc.id;
  }

  Future<String> startWithPrepaidAndAutoCharge({
    required String memberId,
    required String memberName,
    required String planId,
    required num prepaidAmount,
  }) async {
    final plan = await plansRepo.requireActivePlan(
      planId,
      allowedCategories: const [SubscriptionCategory.weekly],
    );
    final cycleId = await _createCycleFromPlan(
      memberId: memberId,
      memberName: memberName,
      plan: plan,
    );

    if (prepaidAmount > 0) {
      await wallet.topUp(
        memberId: memberId,
        amount: prepaidAmount,
        note: 'Weekly prepaid',
        refType: 'weekly',
        refId: cycleId,
      );
    }

    await wallet.chargeAmountAllowNegative(
      memberId: memberId,
      cost: plan.price,
      reason: 'Weekly fee',
      refType: 'weekly',
      refId: cycleId,
    );

    return cycleId;
  }

  /// يبدأ يوم جديد:
  /// - يمنع لو في يوم مفتوح
  /// - يمنع لو استُهلك يوم اليوم (dateKey)
  /// - يمنع لو لا يوجد أيام متبقية
  Future<String> startDay(String cycleId) async {
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    // فحص خارج الترانزاكشن لمنع يومين بنفس اليوم
    final already = await daysRepo.existsForDate(cycleId: cycleId, dateKey: todayKey);
    if (already) {
      throw Exception('You already used a day today.');
    }

    late String dayId;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final cref = fs.doc('weekly_cycles/$cycleId');
      final csnap = await tx.get(cref);
      final c = csnap.data();
      if (c == null) {
        throw Exception('Cycle not found');
      }

      if ((c['status'] ?? 'active') != 'active') {
        throw Exception('Cycle is not active');
      }
      final days = (c['days'] ?? 6) as int;
      final used = (c['daysUsed'] ?? 0) as int;
      final openDayId = c['openDayId'] as String?;
      final dayCost = (c['dayCost'] ?? 0) as num;
      final memberId = (c['memberId'] ?? '') as String;
      final memberName = (c['memberName'] ?? '') as String;

      if (openDayId != null) {
        throw Exception('A day is already open.');
      }
      if (used >= days) {
        throw Exception('No remaining days.');
      }

      // أنشئ اليوم المفتوح (بدون خصم)
      final expectedCloseAt = now.add(const Duration(hours: 8));
      final dref = _days.doc();
      tx.set(dref, {
        'cycleId': cycleId,
        'memberId': memberId,
        'memberName': memberName,
        'dateKey': todayKey,
        'startAt': now.toIso8601String(),
        'expectedCloseAt': expectedCloseAt.toIso8601String(),
        'status': 'open',
        'dayCost': dayCost,
      });

      // اربط في الدورة
      tx.update(cref, {'openDayId': dref.id});

      dayId = dref.id;
    });

    return dayId;
  }

  /// إغلاق اليوم المفتوح (يدويًا أو تلقائيًا):
  /// - يغلق اليوم ويُصفر openDayId
  /// - يزيد daysUsed
  /// - يخصم dayCost من المحفظة ويسجل wallet_tx
  Future<void> closeOpenDay(String cycleId) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final cref = fs.doc('weekly_cycles/$cycleId');
      final csnap = await tx.get(cref); // READ 1
      final c = csnap.data();
      if (c == null) return;

      final openDayId = c['openDayId'] as String?;
      if (openDayId == null) return;

      final dref = fs.doc('weekly_days/$openDayId');
      final dsnap = await tx.get(dref); // READ 2
      final d = dsnap.data();
      if (d == null) return;
      if ((d['status'] ?? 'open') != 'open') return;

      // حضّر كل القيم قبل أي كتابة
      final now = DateTime.now();
      final memberId = (c['memberId'] ?? '') as String;
      final used = (c['daysUsed'] ?? 0) as int;
      final dayCost = (d['dayCost'] ?? c['dayCost'] ?? 0) as num;

      // اقرأ الرصيد قبل الخصم واحسب المبلغ الذي سنخصمه
      final wRef = fs.doc('wallets/$memberId');
      final wSnap = await tx.get(wRef);
      final balance = (wSnap.data()?['balance'] ?? 0) as num;
      final toDeduct = max(0, min(balance, dayCost));
      final debtAmount = dayCost - toDeduct;

      // ====== WRITES تبدأ من هنا: لا مزيد من tx.get بعد الآن ======

      // أغلق اليوم
      tx.update(dref, {
        'status': 'closed',
        'stopAt': now.toIso8601String(),
      });

      // حدث الدورة
      tx.update(cref, {
        'openDayId': null,
        'daysUsed': used + 1,
      });

      // خصم من المحفظة بالمبلغ الفعلي المتوفر
      if (toDeduct > 0) {
        tx.set(
          wRef,
          {
            'balance': FieldValue.increment(-toDeduct),
            'lastBalanceAt': now.toIso8601String(),
          },
          SetOptions(merge: true),
        );

        // سجل حركة المحفظة
        tx.set(fs.col('wallet_tx').doc(), {
          'memberId': memberId,
          'memberName': (c['memberName'] ?? ''),
          'amount': -toDeduct,
          'type': 'charge',
          'note': 'weekly-day',
          'refType': 'weekly',
          'refId': cycleId,
          'at': now.toIso8601String(),
        });
      }

      if (debtAmount > 0) {
        await DebtsRepo().createDebt(
          memberId: memberId,
          memberName: (c['memberName'] ?? ''),
          amount: debtAmount,
          reason: 'Weekly day deficit',
          refType: 'weekly',
          refId: cycleId,
          tx: tx,
        );
      }
    });
  }

  Stream<WeeklyCycle?> watchActiveCycleForMember(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .where('status', isEqualTo: 'active')
        .orderBy('startDate', descending: true)
        .limit(1)
        .snapshots()
        .map((q) =>
    q.docs.isEmpty ? null : WeeklyCycle.fromMap(q.docs.first.id, q.docs.first.data()));
  }

  /// أوتو-كلوز لو خلصت 8 ساعات
  Future<void> ensureAutoClose(String cycleId) async {
    final cref = fs.doc('weekly_cycles/$cycleId');
    final csnap = await cref.get();
    final c = csnap.data();
    if (c == null) return;
    final openDayId = c['openDayId'] as String?;
    if (openDayId == null) return;

    final dref = fs.doc('weekly_days/$openDayId');
    final dsnap = await dref.get();
    final d = dsnap.data();
    if (d == null) return;
    final status = (d['status'] ?? 'open') as String;
    if (status != 'open') return;

    final expectedCloseAt = DateTime.tryParse(d['expectedCloseAt']?.toString() ?? '');
    if (expectedCloseAt == null) return;

    if (DateTime.now().isAfter(expectedCloseAt)) {
      await closeOpenDay(cycleId);
    }
  }

  /// إغلاق الدورة (لا يخصم شيء هنا؛ الخصم صار يوميًا؛ هنا فقط نعيد ملخّصًا)
  Future<WeeklyCloseResult> closeCycle(String cycleId) async {
    final ref = fs.doc('weekly_cycles/$cycleId');
    final snap = await ref.get();
    final m = snap.data();
    if (m == null) {
      throw Exception('Weekly cycle not found');
    }

    // تأكد من إغلاق أي يوم مفتوح
    await ensureAutoClose(cycleId);

    final priceAtStart = (m['priceAtStart'] ?? 0) as num;
    final drinks = (m['drinksTotal'] ?? 0) as num;
    final daysUsed = (m['daysUsed'] ?? 0) as int;

    await ref.update({'status': 'closed', 'openDayId': null});

    return WeeklyCloseResult(
      drinksTotal: drinks,
      priceAtStart: priceAtStart,
      daysUsed: daysUsed,
    );
  }
}
