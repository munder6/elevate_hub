// lib/data/repositories/weekly_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/weekly_cycle.dart';
import 'coupons_repo.dart';
import 'debts_repo.dart';

class WeeklyRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('weekly_cycles');

  /// إنشاء دورة أسبوعية (6 أيام) مع رصيد مدفوع مسبقاً + تخزين اسم العضو
  Future<String> start(
      String memberId, {
        required String memberName,
        required num prepaidAmount,
      }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final doc = await _col.add({
      'memberId': memberId,
      'memberName': memberName,                   // ✅ نخزّن الاسم
      'startDate': DateTime.now().toIso8601String(),
      'days': 6,
      'prepaidAmount': prepaidAmount,
      'drinksTotal': 0,
      'balance': 0,
      'status': 'active',
      'createdBy': uid,
    });
    return doc.id;
  }

  /// الدورات النشطة لعضو
  Stream<List<WeeklyCycle>> watchActiveByMember(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((q) => q.docs
        .map((d) => WeeklyCycle.fromMap(d.id, d.data()))
        .where((c) => c.status == 'active')
        .toList());
  }

  /// إغلاق الدورة:
  /// - اختيار أفضل كوبون (drinks/all) وتطبيقه على drinksTotal
  /// - balance = prepaid - (drinksTotal - couponDiscount)
  /// - لو balance سالب => إنشاء دين مرتبط بالدورة وباسم العضو
  Future<void> close(String cycleId) async {
    final ds = await fs.getDoc('weekly_cycles/$cycleId');
    final m = ds.data();
    if (m == null) return;

    final memberId = m['memberId'] as String;
    // خذ الاسم إن كان مخزن بالدورة، وإلا اقراه من members
    String memberName = (m['memberName'] as String?) ?? '';
    if (memberName.isEmpty) {
      try {
        final ms = await fs.getDoc('members/$memberId');
        final mm = ms.data();
        if (mm != null) memberName = (mm['name'] as String?) ?? '';
      } catch (_) {}
    }

    final prepaid = (m['prepaidAmount'] ?? 0) as num;
    final drinks = (m['drinksTotal'] ?? 0) as num;

    num couponDiscount = 0;
    String? couponId;

    try {
      final best = await CouponsRepo().bestForWeekly(
        memberId: memberId,
        drinksTotal: drinks,
      );
      if (best != null) {
        couponDiscount = best.discount;
        couponId = best.coupon.id;
      }
    } catch (_) {
      // تجاهل أخطاء الكوبونات
    }

    final drinksAfterDiscount =
    (drinks - couponDiscount).clamp(0, double.infinity);
    final balance = prepaid - drinksAfterDiscount;

    await fs.update('weekly_cycles/$cycleId', {
      'balance': balance,
      'status': 'closed',
    });

    // سجّل استخدام الكوبون إن وجد
    if (couponId != null && couponDiscount > 0) {
      await CouponsRepo().recordRedemption(
        couponId: couponId,
        memberId: memberId,
        refType: 'weekly',
        refId: cycleId,
        amountDiscounted: couponDiscount,
      );
    }

    // لو balance سالب => دين (ومع اسم العضو)
    if (balance < 0) {
      await DebtsRepo().createDebt(
        memberId: memberId,
        memberName: memberName,        // ✅ مهم
        amount: -balance,              // موجّبة
        reason: 'Weekly cycle deficit',
        refType: 'weekly',
        refId: cycleId,
      );
    }
  }
}
