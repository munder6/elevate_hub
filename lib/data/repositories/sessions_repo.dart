// lib/data/repositories/sessions_repo.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/session.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'debts_repo.dart';
import 'settings_repo.dart';
import 'balance_repo.dart'; // NEW

/* ======================= Helpers & Models (top-level) ======================= */

/// امتدادات نطاقات التاريخ (لازم تكون top-level، مش داخل كلاس)
extension SessionsDateRanges on DateTime {
  DateTime get dayStart => DateTime(year, month, day);
  DateTime get dayEnd   => DateTime(year, month, day, 23, 59, 59, 999);

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
    final firstNext = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    // آخر لحظة من الشهر الحالي
    return firstNext.subtract(const Duration(milliseconds: 1));
  }
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
  final BalanceChargeResult? balanceCharge; // لو استخدم رصيد

  const SessionCloseResult({
    required this.minutes,
    required this.rate,
    required this.sessionAmount,
    required this.drinks,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    this.balanceCharge,
  });
}

/* ============================ Repository class ============================ */

class SessionsRepo {
  final debts = DebtsRepo();
  final fs = FirestoreService();
  final auth = AuthService();
  final settings = SettingsRepo();
  final balance = BalanceRepo(); // NEW

  CollectionReference<Map<String, dynamic>> get _col => fs.col('sessions');

  int _roundTo5Minutes(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    final rem = mins % 5;
    return rem == 0 ? mins : mins + (5 - rem);
  }

  Future<num> _getHourly() async {
    final snap = await fs.getDoc('settings/app');
    final m = snap.data();
    return (m?['prices']?['hourly'] ?? 0) as num;
  }

  Future<String> startSession(
      String memberId, {
        String? memberName,
        DateTime? checkInAt, // جديد
      }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final rate = await _getHourly();
    final when = checkInAt ?? DateTime.now();

    final doc = await _col.add({
      'memberId': memberId,
      if (memberName != null) 'memberName': memberName,
      'checkInAt': when.toIso8601String(), // ISO8601
      'minutes': 0,
      'hourlyRateAtTime': rate,
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
      );
    }

    final checkIn = DateTime.parse(data['checkInAt']);
    final checkOut = DateTime.now();

    final minutes = _roundTo5Minutes(checkOut.difference(checkIn));
    final rate = (data['hourlyRateAtTime'] ?? 0) as num;
    final drinks = (data['drinksTotal'] ?? 0) as num;
    final discount =
    manualDiscount > 0 ? manualDiscount : (data['discount'] ?? 0) as num;

    final sessionAmount = (minutes / 60) * rate;
    final grandTotal = sessionAmount + drinks - discount;

    await fs.update('sessions/$sessionId', {
      'checkOutAt': checkOut.toIso8601String(),
      'minutes': minutes,
      'paymentMethod': paymentMethod,
      'discount': discount,
      'sessionAmount': sessionAmount,
      'grandTotal': grandTotal,
      'status': 'closed',
    });

    // تسوية ديون تلقائية لو مش unpaid
    if (paymentMethod != 'unpaid') {
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
      discount: discount,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
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
      return status == null
          ? all
          : all.where((s) => s.status == status).toList();
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
