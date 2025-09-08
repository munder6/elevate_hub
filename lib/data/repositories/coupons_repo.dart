import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coupon.dart';
import '../models/coupon_redemption.dart';
import '../services/firestore_service.dart';

class CouponsRepo {
  final fs = FirestoreService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('coupons');
  CollectionReference<Map<String, dynamic>> get _red => fs.col('coupon_redemptions');

  // ===== CRUD أساسية =====

  Stream<List<Coupon>> watchAll() {
    return _col.orderBy('code').snapshots().map(
          (q) => q.docs.map((d) => Coupon.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<void> add(Coupon c) async {
    await _col.add(c.toMap());
  }

  Future<void> update(Coupon c) async {
    await fs.update('coupons/${c.id}', c.toMap());
  }

  Future<void> delete(String id) async {
    await fs.delete('coupons/$id');
  }

  // ===== منطق الاختيار/التطبيق =====

  Future<int> _countRedemptions(String couponId) async {
    final s = await _red.where('couponId', isEqualTo: couponId).get();
    return s.docs.length;
  }

  bool _isWithinDates(Coupon c, DateTime now) {
    if (c.validFrom != null && now.isBefore(c.validFrom!)) return false;
    if (c.validTo != null && now.isAfter(c.validTo!)) return false;
    return true;
  }

  num _discountForBase(Coupon c, num base) {
    if (base <= 0) return 0;
    if (c.isPercent) {
      final d = (c.value / 100) * base;
      return d < 0 ? 0 : d;
    } else {
      return c.value <= base ? c.value : base;
    }
  }

  /// اختر أفضل كوبون قابل للتطبيق على جلسة يومية:
  /// - scope: sessions | drinks | all
  /// - appliesTo: member أو all
  /// - active + ضمن المدة + maxRedemptions
  /// يُعيد: (coupon, discountAmount)
  Future<({Coupon coupon, num discount})?> bestForDailySession({
    required String memberId,
    required num sessionAmount,
    required num drinksTotal,
    DateTime? now,
  }) async {
    final _now = now ?? DateTime.now();

    // نجلب مرشحين على دفعتين (بدون OR مركّب): member-specific ثم العامة
    final candMember = await _col
        .where('active', isEqualTo: true)
        .where('appliesTo', isEqualTo: 'member')
        .where('memberId', isEqualTo: memberId)
        .get();

    final candAll = await _col
        .where('active', isEqualTo: true)
        .where('appliesTo', isEqualTo: 'all')
        .get();

    final candidates = <Coupon>[
      ...candMember.docs.map((d) => Coupon.fromMap(d.id, d.data())),
      ...candAll.docs.map((d) => Coupon.fromMap(d.id, d.data())),
    ];

    Coupon? best;
    num bestDiscount = 0;

    for (final c in candidates) {
      if (!_isWithinDates(c, _now)) continue;

      // check redemptions limit
      if (c.maxRedemptions != null) {
        final used = await _countRedemptions(c.id);
        if (used >= c.maxRedemptions!) continue;
      }

      // حدد الـ base حسب الـ scope
      num base = 0;
      switch (c.scope) {
        case 'sessions':
          base = sessionAmount;
          break;
        case 'drinks':
          base = drinksTotal;
          break;
        case 'all':
          base = sessionAmount + drinksTotal;
          break;
        default:
          base = sessionAmount + drinksTotal;
      }

      final d = _discountForBase(c, base);
      if (d > bestDiscount) {
        bestDiscount = d;
        best = c;
      }
    }

    if (best == null || bestDiscount <= 0) return null;
    return (coupon: best, discount: bestDiscount);
  }

  /// سجل عملية استخدام كوبون
  Future<void> recordRedemption({
    required String couponId,
    String? memberId,
    required String refType, // 'session' | 'weekly' | 'monthly'
    required String refId,
    required num amountDiscounted,
  }) async {
    await _red.add({
      'couponId': couponId,
      if (memberId != null) 'memberId': memberId,
      'refType': refType,
      'refId': refId,
      'amountDiscounted': amountDiscounted,
      'at': DateTime.now().toIso8601String(),
    });
  }

  Future<({Coupon coupon, num discount})?> bestForWeekly({
    required String memberId,
    required num drinksTotal,
    DateTime? now,
  }) async {
    final _now = now ?? DateTime.now();

    final candMember = await _col
        .where('active', isEqualTo: true)
        .where('appliesTo', isEqualTo: 'member')
        .where('memberId', isEqualTo: memberId)
        .get();

    final candAll = await _col
        .where('active', isEqualTo: true)
        .where('appliesTo', isEqualTo: 'all')
        .get();

    final candidates = <Coupon>[
      ...candMember.docs.map((d) => Coupon.fromMap(d.id, d.data())),
      ...candAll.docs.map((d) => Coupon.fromMap(d.id, d.data())),
    ];

    Coupon? best;
    num bestDiscount = 0;

    for (final c in candidates) {
      if (!_isWithinDates(c, _now)) continue;
      if (c.maxRedemptions != null) {
        final used = await _countRedemptions(c.id);
        if (used >= c.maxRedemptions!) continue;
      }

      // Weekly: نطبّق فقط إذا كان scope = drinks أو all
      if (c.scope != 'drinks' && c.scope != 'all') continue;

      final base = drinksTotal;
      final d = _discountForBase(c, base);
      if (d > bestDiscount) {
        bestDiscount = d;
        best = c;
      }
    }

    if (best == null || bestDiscount <= 0) return null;
    return (coupon: best, discount: bestDiscount);
  }

  /// أفضل كوبون لدورة شهرية:
  /// - افتراضيًا نخصم على drinks فقط (ممكن توسّع لاحقًا للرسوم إن وجدت)
  Future<({Coupon coupon, num discount})?> bestForMonthly({
    required String memberId,
    required num drinksTotal,
    DateTime? now,
  }) async {
    final _now = now ?? DateTime.now();

    final candMember = await _col
        .where('active', isEqualTo: true)
        .where('appliesTo', isEqualTo: 'member')
        .where('memberId', isEqualTo: memberId)
        .get();

    final candAll = await _col
        .where('active', isEqualTo: true)
        .where('appliesTo', isEqualTo: 'all')
        .get();

    final candidates = <Coupon>[
      ...candMember.docs.map((d) => Coupon.fromMap(d.id, d.data())),
      ...candAll.docs.map((d) => Coupon.fromMap(d.id, d.data())),
    ];

    Coupon? best;
    num bestDiscount = 0;

    for (final c in candidates) {
      if (!_isWithinDates(c, _now)) continue;
      if (c.maxRedemptions != null) {
        final used = await _countRedemptions(c.id);
        if (used >= c.maxRedemptions!) continue;
      }

      // Monthly: نطبّق إذا كان scope = drinks أو all (حالياً نخصم على drinksTotal)
      if (c.scope != 'drinks' && c.scope != 'all') continue;

      final base = drinksTotal;
      final d = _discountForBase(c, base);
      if (d > bestDiscount) {
        bestDiscount = d;
        best = c;
      }
    }

    if (best == null || bestDiscount <= 0) return null;
    return (coupon: best, discount: bestDiscount);
  }
}
