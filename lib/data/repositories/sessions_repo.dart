// lib/data/repositories/sessions_repo.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/session.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'debts_repo.dart';
import 'balance_repo.dart'; // NEW
import 'plans_repo.dart';
import '../models/subscription_category.dart';

/* ======================= Helpers & Models (top-level) ======================= */

/// امتدادات نطاقات التاريخ (لازم تكون top-level، مش داخل كلاس)
extension SessionsDateRanges on DateTime {
  DateTime get dayStart => DateTime(year, month, day);
  DateTime get dayEnd => DateTime(year, month, day, 23, 59, 59, 999);

  /// ISO week (Mon-Sun) نبدأ الاثنين
  DateTime get weekStart {
    final int weekdayMon1 = weekday == DateTime.sunday ? 7 : weekday;
    final start = dayStart.subtract(Duration(days: weekdayMon1 - 1));
    return DateTime(start.year, start.month, start.day);
  }

  DateTime get weekEnd => DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day,
    23,
    59,
    59,
    999,
  ).add(const Duration(days: 6));

  DateTime get monthStart => DateTime(year, month, 1);
  DateTime get monthEnd {
    final firstNext =
    (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    // آخر لحظة من الشهر الحالي
    return firstNext.subtract(const Duration(milliseconds: 1));
  }
}

/// محولات آمنة للـ int/num
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return int.tryParse('$v');
}

num? asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return num.tryParse('$v');
}

/// ملخص سريع للفترة
class SessionsSummary {
  final int count;
  final int minutes;
  final num sessionAmount;
  final num drinks;
  final num discount;
  final num grand;
  const SessionsSummary({
    required this.count,
    required this.minutes,
    required this.sessionAmount,
    required this.drinks,
    required this.discount,
    required this.grand,
  });
}

/// نتيجة إغلاق الجلسة
class SessionCloseResult {
  final num minutes;
  final num rate;
  final num sessionAmount;
  final num drinks;
  final num discount;
  final num grandTotal;
  final String paymentMethod; // cash|card|other|app|unpaid
  final SubscriptionCategory? category;
  final BalanceChargeResult? balanceCharge; // لو استخدم رصيد
  final String? paymentProofUrl;

  const SessionCloseResult({
    required this.minutes,
    required this.rate,
    required this.sessionAmount,
    required this.drinks,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    this.balanceCharge,
    this.category,
    this.paymentProofUrl,
  });
}



/* ============================ Repository class ============================ */

class SessionsRepo {
  final debts = DebtsRepo();
  final fs = FirestoreService();
  final auth = AuthService();
  final balance = BalanceRepo(); // NEW
  final plans = PlansRepo();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('sessions');

  int _roundTo5Minutes(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    final rem = mins % 5;
    return rem == 0 ? mins : mins + (5 - rem);
  }




  Future<String> startSession(
      String memberId, {
        required String planId,
        String? memberName,
        DateTime? checkInAt, // جديد
      }) async {
    final uid = auth.currentUser?.uid ?? 'system';

    // التحقق وجلب بيانات الخطة النشطة المسموح بها (بالساعات أو يومية)
    final plan = await plans.requireActivePlan(
      planId,
      allowedCategories: const [
        SubscriptionCategory.hours,
        SubscriptionCategory.daily,
      ],
    );

    final num rate = plan.category == SubscriptionCategory.hours
        ? plan.price
        : plan.dayCostSnapshot;
    final when = checkInAt ?? DateTime.now();

    final doc = await _col.add({
      'memberId': memberId,
      if (memberName != null) 'memberName': memberName,
      'checkInAt': when.toIso8601String(), // ISO8601
      'minutes': 0,
      'hourlyRateAtTime': rate, // احتفاظ قديم للتوافق
      'pricePerHourSnapshot': rate, // اللقطة الجديدة للسعر
      'planId': plan.id,
      'category': plan.category.rawValue,
      'bandwidthMbpsSnapshot': plan.bandwidthMbps,
      'drinksTotal': 0,
      'discount': 0,
      'paymentMethod': 'cash',
      'sessionAmount': 0,
      'grandTotal': 0,
      'status': 'open',
      'createdBy': uid,
    });
    return doc.id;
  }
  Future<String> startDailyWithPlan({
    required String memberId,
    required String memberName,
    required String planId,
    required String paymentMethod,
    String? proofUrl,
    DateTime? checkInAt,
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final plan = await plans.getPlanOnce(planId);
    if (plan == null) {
      throw Exception('الخطة غير موجودة');
    }
    if (plan.category != SubscriptionCategory.daily) {
      throw Exception('الخطة ليست يومية');
    }
    if (!plan.active) {
      throw Exception('الخطة غير مفعلة');
    }

    final trimmedProof = proofUrl?.trim();
    if (paymentMethod == 'app' && (trimmedProof == null || trimmedProof.isEmpty)) {
      throw Exception('الدفع عبر التطبيق يتطلّب إرفاق إثبات دفع');
    }

    final doc = _col.doc();

    final when = checkInAt ?? DateTime.now();

    String? chargeRef;
    if (plan.price > 0) {
      if (paymentMethod == 'cash') {
        final charge = await balance.chargeAmountAllowNegative(
          memberId: memberId,
          cost: plan.price,
          reason: 'Daily session fee',
          refType: 'session',
          refId: doc.id,
        );
        chargeRef = charge.debtId != null
            ? 'balance:${charge.debtId}'
            : 'balance';
      } else if (paymentMethod == 'unpaid') {
        final nowIso = DateTime.now().toIso8601String();
        final debtDocId = 'session_${doc.id}';
        final debtRef = fs.doc('debts/$debtDocId');
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(debtRef);
          final existing = snap.data();
          final createdAt = existing?['createdAt']?.toString() ?? nowIso;
          final List<Map<String, dynamic>> payments =
          ((existing?['payments'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          tx.set(
            debtRef,
            {
              'memberId': memberId,
              if (memberName.isNotEmpty) 'memberName': memberName,
              'amount': plan.price,
              'reason': 'جلسة يومية غير مدفوعة',
              'status': 'open',
              'createdAt': createdAt,
              'refType': 'session',
              'refId': doc.id,
              'sessionId': doc.id,
              'payments': payments,
            },
            SetOptions(merge: true),
          );
        });
        chargeRef = 'debt:$debtDocId';
      } else if (paymentMethod == 'app') {
        chargeRef = 'app';
      } else {
        chargeRef = paymentMethod;
      }
    } else {
      chargeRef = paymentMethod;
    }

    await doc.set({
      'memberId': memberId,
      if (memberName.isNotEmpty) 'memberName': memberName,
      'checkInAt': when.toIso8601String(),
      'minutes': 0,
      'planId': plan.id,
      'hourlyRateAtTime': plan.price,
      'pricePerHourSnapshot': plan.price,
      'category': SubscriptionCategory.daily.rawValue,
      'bandwidthMbpsSnapshot': plan.bandwidthMbps,
      'drinksTotal': 0,
      'discount': 0,
      'paymentMethod': paymentMethod,
      'sessionAmount': plan.price,
      'grandTotal': plan.price,
      'status': 'open',
      'createdBy': uid,
      'dailyPriceSnapshot': plan.price,
      if (chargeRef != null) 'dailyChargeRef': chargeRef,
      if (paymentMethod == 'app' && trimmedProof != null)
        'paymentProofUrl': trimmedProof,
    });



    return doc.id;
  }
  Future<void> finishDailySession({
    required String sessionId,
    required String paymentMethod,
    required num discount,
    String? proofUrl,
  }) async {
    final snap = await fs.getDoc('sessions/$sessionId');
    final data = snap.data();
    if (data == null) {
      throw Exception('لم يتم العثور على الجلسة');
    }

    final checkInRaw = data['checkInAt']?.toString();
    final checkInAt = checkInRaw != null ? DateTime.tryParse(checkInRaw) : null;
    final checkOutAt = DateTime.now();
    final minutes = checkInAt != null
        ? checkOutAt.difference(checkInAt).inMinutes
        : 0;

    final base =
    (data['dailyPriceSnapshot'] ?? data['sessionAmount'] ?? 0) as num;
    final drinks = (data['drinksTotal'] ?? 0) as num;
    final appliedDiscount = discount < 0 ? 0 : discount;

    num grand = base + drinks - appliedDiscount;
    if (grand < 0) grand = 0;
    num delta = grand - base;
    if (delta < 0) delta = 0;

    final memberId = (data['memberId'] as String?) ?? '';
    final memberName = (data['memberName'] as String?) ?? '';
    final existingProof = (data['paymentProofUrl'] as String?)?.trim();

    String? proofToPersist;
    if (paymentMethod == 'app') {
      final trimmed = proofUrl?.trim();
      proofToPersist = (trimmed != null && trimmed.isNotEmpty)
          ? trimmed
          : (existingProof != null && existingProof.isNotEmpty
          ? existingProof
          : null);
      if (proofToPersist == null) {
        throw Exception('الدفع عبر التطبيق يتطلّب إرفاق إثبات دفع');
      }
    }

    String? chargeRef = data['dailyChargeRef']?.toString();

    if (delta > 0 && memberId.isNotEmpty) {
      if (paymentMethod == 'cash') {
        final charge = await balance.chargeAmountAllowNegative(
          memberId: memberId,
          cost: delta,
          reason: '[daily extras]',
          refType: 'session',
          refId: sessionId,
        );
        chargeRef = charge.debtId != null
            ? 'balance:${charge.debtId}'
            : 'balance';
      } else if (paymentMethod == 'unpaid') {
        final nowIso = DateTime.now().toIso8601String();
        final debtDocId = 'session_$sessionId';
        final debtRef = fs.doc('debts/$debtDocId');
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(debtRef);
          final existing = snap.data();
          final createdAt = existing?['createdAt']?.toString() ?? nowIso;
          final List<Map<String, dynamic>> payments =
          ((existing?['payments'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final currentAmount = (existing?['amount'] ?? 0) as num;

          tx.set(
            debtRef,
            {
              'memberId': memberId,
              if (memberName.isNotEmpty) 'memberName': memberName,
              'amount': currentAmount + delta,
              'reason': 'جلسة يومية غير مدفوعة',
              'status': 'open',
              'createdAt': createdAt,
              'refType': 'session',
              'refId': sessionId,
              'sessionId': sessionId,
              'payments': payments,
            },
            SetOptions(merge: true),
          );
        });
        chargeRef = 'debt:$debtDocId';
      } else if (paymentMethod == 'app') {
        chargeRef = 'app';
      } else {
        chargeRef = paymentMethod;
      }
    }

    final update = <String, dynamic>{
      'checkOutAt': checkOutAt.toIso8601String(),
      'minutes': minutes,
      'paymentMethod': paymentMethod,
      'discount': appliedDiscount,
      'drinksTotal': drinks,
      'grandTotal': grand,
      'status': 'closed',
      'sessionAmount': base,
      if (chargeRef != null) 'dailyChargeRef': chargeRef,
    };

    if (paymentMethod == 'app') {
      update['paymentProofUrl'] = proofToPersist;
    } else if (existingProof != null && existingProof.isNotEmpty) {
      update['paymentProofUrl'] = FieldValue.delete();
      update['paymentProofUploadedAt'] = FieldValue.delete();
      update['paymentProofUploadedBy'] = FieldValue.delete();
    }

    await fs.update('sessions/$sessionId', update);

    if (paymentMethod != 'unpaid') {
      try {
        await debts.settleByRef(
          refType: 'session',
          refId: sessionId,
          method: paymentMethod,
        );
      } catch (_) {
        // تجاهل أخطاء التسوية
      }
    }
  }


  Future<void> stopSession(
      String sessionId, {
        String paymentMethod = 'cash',
      }) async {
    await stopSessionWithOptions(
      sessionId: sessionId,
      paymentMethod: paymentMethod,
    );
  }

  Future<String> uploadPaymentProof({
    required String sessionId,
    required File file,
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final ref = FirebaseStorage.instance
        .ref()
        .child('payment_proofs')
        .child('$sessionId-${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await fs.update('sessions/$sessionId', {
      'paymentProofUrl': url,
      'paymentProofUploadedAt': DateTime.now().toIso8601String(),
      'paymentProofUploadedBy': uid,
    });

    return url;
  }



  /// حذف إثبات الدفع (اختياري)
  Future<void> clearPaymentProof(String sessionId) async {
    final snap = await fs.getDoc('sessions/$sessionId');
    final m = snap.data();
    final url = m?['paymentProofUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {
        // تجاهل
      }
    }
    await fs.update('sessions/$sessionId', {
      'paymentProofUrl': FieldValue.delete(),
      'paymentProofUploadedAt': FieldValue.delete(),
      'paymentProofUploadedBy': FieldValue.delete(),
    });
  }

  /// إغلاق مع الخيارات (خصم/طريقة دفع/…)
  Future<SessionCloseResult> stopSessionWithOptions({
    required String sessionId,
    required String paymentMethod, // 'cash' | 'card' | 'other' | 'app' | 'unpaid'
    num manualDiscount = 0,
  }) async {
    final ds = await fs.getDoc('sessions/$sessionId');
    final data = ds.data();
    if (data == null) {
      return const SessionCloseResult(
        minutes: 0,
        rate: 0,
        sessionAmount: 0,
        drinks: 0,
        discount: 0,
        grandTotal: 0,
        paymentMethod: 'cash',
        paymentProofUrl: null,
      );
    }

    final category =
    subscriptionCategoryFromRaw(data['category']?.toString());
    final discountValue = manualDiscount > 0
        ? manualDiscount
        : (data['discount'] ?? 0) as num;

    if (category == SubscriptionCategory.daily) {
      final checkIn =
      DateTime.tryParse(data['checkInAt']?.toString() ?? '');
      final checkOut = DateTime.now();
      final minutes = checkIn != null
          ? checkOut.difference(checkIn).inMinutes
          : 0;
      final base =
      (data['dailyPriceSnapshot'] ?? data['sessionAmount'] ?? 0) as num;
      final drinks = (data['drinksTotal'] ?? 0) as num;
      num grand = base + drinks - discountValue;
      if (grand < 0) grand = 0;

      await finishDailySession(
        sessionId: sessionId,
        paymentMethod: paymentMethod,
        discount: discountValue,
        proofUrl: null,
      );

      return SessionCloseResult(
        minutes: minutes,
        rate: base,
        sessionAmount: base,
        drinks: drinks,
        discount: discountValue,
        grandTotal: grand,
        paymentMethod: paymentMethod,
        category: category,
        paymentProofUrl: data['paymentProofUrl'] as String?,
      );
    }

    final checkIn = DateTime.parse(data['checkInAt']);
    final checkOut = DateTime.now();

    final minutes = _roundTo5Minutes(checkOut.difference(checkIn));

    // دعم الحقل الجديد pricePerHourSnapshot مع التوافق backward
    final rate =
    (data['pricePerHourSnapshot'] ?? data['hourlyRateAtTime'] ?? 0) as num;

    final drinks = (data['drinksTotal'] ?? 0) as num;


    // فَوترة بالساعة مع التقريب للأعلى: أي جزء ساعة يحتسب ساعة كاملة
    final int roundedHours = minutes <= 0 ? 0 : ((minutes + 59) ~/ 60);
    final sessionAmount = roundedHours * rate;
    final grandTotal = sessionAmount + drinks - discountValue;

    await fs.update('sessions/$sessionId', {
      'checkOutAt': checkOut.toIso8601String(),
      'minutes': minutes,
      'paymentMethod': paymentMethod,
      'discount': discountValue,
      'sessionAmount': sessionAmount,
      'grandTotal': grandTotal,
      'status': 'closed',
    });

    final memberId = (data['memberId'] as String?) ?? '';
    String memberName = (data['memberName'] as String?) ?? '';
    if (memberName.isEmpty && memberId.isNotEmpty) {
      try {
        final ms = await fs.getDoc('members/$memberId');
        memberName = (ms.data()?['name'] as String?) ?? '';
      } catch (_) {}
    }

    final debtDocId = 'session_$sessionId';
    final debtRef = fs.doc('debts/$debtDocId');

    if (paymentMethod == 'unpaid') {
      if (grandTotal > 0 && memberId.isNotEmpty) {
        final nowIso = DateTime.now().toIso8601String();
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(debtRef);
          final existing = snap.data();
          final createdAt = existing?['createdAt']?.toString() ?? nowIso;
          final List<Map<String, dynamic>> payments = ((existing?['payments'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          tx.set(
            debtRef,
            {
              'memberId': memberId,
              'memberName': memberName,
              'amount': grandTotal,
              'reason': 'جلسة يومية غير مدفوعة',
              'status': 'open',
              'createdAt': createdAt,
              'refType': 'session',
              'refId': sessionId,
              'payments': payments,
              'sessionId': sessionId,
            },
            SetOptions(merge: true),
          );
        });

        try {
          final q = await fs
              .col('debts')
              .where('refType', isEqualTo: 'session')
              .where('refId', isEqualTo: sessionId)
              .get();
          for (final d in q.docs) {
            if (d.id != debtDocId) {
              await d.reference.delete();
            }
          }
        } catch (_) {}
      }
    } else {
      try {
        await debts.settleByRef(
          refType: 'session',
          refId: sessionId,
          method: paymentMethod,
        );
      } catch (_) {
        // لا تمنع الإغلاق لو فشلت التسوية
      }
    }

    return SessionCloseResult(
      minutes: minutes,
      rate: rate,
      sessionAmount: sessionAmount,
      drinks: drinks,
      discount: discountValue,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      category: category,
      paymentProofUrl: null,
    );
  }

  /* ===================== Watchers: by ranges & summaries ===================== */

  /// كل الجلسات بين تاريخين (مع فلترة حالة اختيارية)
  Stream<List<Session>> watchSessionsBetween(
      DateTime start,
      DateTime end, {
        String? status,
      }) {
    final qs = _col
        .orderBy('checkInAt', descending: true)
        .where('checkInAt', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('checkInAt', isLessThanOrEqualTo: end.toIso8601String())
        .snapshots();

    return qs.map((q) {
      final all = q.docs.map((d) => Session.fromMap(d.id, d.data())).toList();
      return status == null ? all : all.where((s) => s.status == status).toList();
    });
  }

  /// ملخص سريع بين تاريخين
  Stream<SessionsSummary> watchSummaryBetween(
      DateTime start,
      DateTime end, {
        String? status,
      }) {
    return watchSessionsBetween(start, end, status: status).map((list) {
      final count = list.length;
      final minutes = list.fold<int>(0, (a, s) => a + s.minutes);
      final sessionAmount = list.fold<num>(0, (a, s) => a + s.sessionAmount);
      final drinks = list.fold<num>(0, (a, s) => a + s.drinksTotal);
      final discount = list.fold<num>(0, (a, s) => a + s.discount);
      final grand = list.fold<num>(0, (a, s) => a + s.grandTotal);
      return SessionsSummary(
        count: count,
        minutes: minutes,
        sessionAmount: sessionAmount,
        drinks: drinks,
        discount: discount,
        grand: grand,
      );
    });
  }

  // Conveniences: اليوم/الأسبوع/الشهر
  Stream<List<Session>> watchToday({String? status}) {
    final now = DateTime.now();
    return watchSessionsBetween(now.dayStart, now.dayEnd, status: status);
  }
  Stream<List<Session>> watchThisWeek({String? status}) {
    final now = DateTime.now();
    return watchSessionsBetween(now.weekStart, now.weekEnd, status: status);
  }

  Stream<List<Session>> watchThisMonth({String? status}) {
    final now = DateTime.now();
    return watchSessionsBetween(now.monthStart, now.monthEnd, status: status);
  }

  Stream<SessionsSummary> watchTodaySummary({String? status}) {
    final now = DateTime.now();
    return watchSummaryBetween(now.dayStart, now.dayEnd, status: status);
  }

  Stream<SessionsSummary> watchThisWeekSummary({String? status}) {
    final now = DateTime.now();
    return watchSummaryBetween(now.weekStart, now.weekEnd, status: status);
  }

  Stream<SessionsSummary> watchThisMonthSummary({String? status}) {
    final now = DateTime.now();
    return watchSummaryBetween(now.monthStart, now.monthEnd, status: status);
  }

  /* ====================== Existing member-specific watchers ====================== */

  Stream<List<Session>> watchMemberOpenSessions(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .orderBy('checkInAt', descending: true)
        .snapshots()
        .map((q) => q.docs
        .map((d) => Session.fromMap(d.id, d.data()))
        .where((s) => s.status == 'open')
        .toList());
  }

  Stream<List<Session>> watchMemberClosedSessions(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .orderBy('checkInAt', descending: true)
        .snapshots()
        .map((q) => q.docs
        .map((d) => Session.fromMap(d.id, d.data()))
        .where((s) => s.status == 'closed')
        .toList());
  }
}
