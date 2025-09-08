import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/monthly_cycle.dart';
import 'coupons_repo.dart';

class MonthlyRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('monthly_cycles');

  Future<String> start(String memberId) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final doc = await _col.add({
      'memberId': memberId,
      'startDate': DateTime.now().toIso8601String(),
      'days': 26,
      'drinksTotal': 0,
      'status': 'active',
      'createdBy': uid,
    });
    return doc.id;
  }

  Stream<List<MonthlyCycle>> watchActiveByMember(String memberId) {
    return _col
        .where('memberId', isEqualTo: memberId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((q) => q.docs
        .map((d) => MonthlyCycle.fromMap(d.id, d.data()))
        .where((c) => c.status == 'active')
        .toList());
  }

  // إغلاق شهري:
  // - حالياً نخصم كوبون على drinks فقط (لا يوجد prepaid/fee هنا حسب الـ Spec عندنا)
  // - نحدث الحالة إلى closed، ويمكنك لاحقاً إنشاء دين إذا عرّفت رسوم شهرية ثابتة غير مدفوعة
  Future<void> close(String cycleId) async {
    final ds = await fs.getDoc('monthly_cycles/$cycleId');
    final m = ds.data();
    if (m == null) return;

    final memberId = m['memberId'] as String;
    final drinks = (m['drinksTotal'] ?? 0) as num;

    num couponDiscount = 0;
    String? couponId;

    try {
      final best = await CouponsRepo().bestForMonthly(
        memberId: memberId,
        drinksTotal: drinks,
      );
      if (best != null) {
        couponDiscount = best.discount;
        couponId = best.coupon.id;
      }
    } catch (_) {
      // تجاهل أي خطأ كوبونات
    }

    await fs.update('monthly_cycles/$cycleId', {
      // نقدر نضيف حقل 'discount' إذا تحب تعرضه لاحقاً
      'status': 'closed',
    });

    if (couponId != null && couponDiscount > 0) {
      await CouponsRepo().recordRedemption(
        couponId: couponId,
        memberId: memberId,
        refType: 'monthly',
        refId: cycleId,
        amountDiscounted: couponDiscount,
      );
    }
  }
}
