import '../models/plan.dart';
import '../models/subscription_category.dart';
import '../services/firestore_service.dart';

class PlansMigrationV1 {
  final fs = FirestoreService();

  Future<void> run() async {
    await _seedIfNeeded();
    await _backfillCycles();
  }

  Future<void> _seedIfNeeded() async {
    final existing = await fs.getCol('plans');
    if (existing.docs.isNotEmpty) {
      return;
    }

    final nowIso = DateTime.now().toIso8601String();
    final seeds = <_PlanSeed>[
      const _PlanSeed(
        id: 'hours_8',
        title: '1 ساعة @ 8 Mbps',
        category: SubscriptionCategory.hours,
        bandwidth: 8,
        daysCount: 0,
        price: 3,
      ),
      const _PlanSeed(
        id: 'hours_16',
        title: '1 ساعة @ 16 Mbps',
        category: SubscriptionCategory.hours,
        bandwidth: 16,
        daysCount: 0,
        price: 4,
      ),
      const _PlanSeed(
        id: 'hours_32',
        title: '1 ساعة @ 32 Mbps',
        category: SubscriptionCategory.hours,
        bandwidth: 32,
        daysCount: 0,
        price: 6,
      ),
      const _PlanSeed(
        id: 'daily_8',
        title: '1 يوم @ 8 Mbps',
        category: SubscriptionCategory.daily,
        bandwidth: 8,
        daysCount: 1,
        price: 20,
      ),
      const _PlanSeed(
        id: 'daily_16',
        title: '1 يوم @ 16 Mbps',
        category: SubscriptionCategory.daily,
        bandwidth: 16,
        daysCount: 1,
        price: 25,
      ),
      const _PlanSeed(
        id: 'daily_32',
        title: '1 يوم @ 32 Mbps',
        category: SubscriptionCategory.daily,
        bandwidth: 32,
        daysCount: 1,
        price: 35,
      ),
      const _PlanSeed(
        id: 'weekly_8',
        title: '6 أيام @ 8 Mbps',
        category: SubscriptionCategory.weekly,
        bandwidth: 8,
        daysCount: 6,
        price: 100,
      ),
      const _PlanSeed(
        id: 'weekly_16',
        title: '6 أيام @ 16 Mbps',
        category: SubscriptionCategory.weekly,
        bandwidth: 16,
        daysCount: 6,
        price: 120,
      ),
      const _PlanSeed(
        id: 'weekly_32',
        title: '6 أيام @ 32 Mbps',
        category: SubscriptionCategory.weekly,
        bandwidth: 32,
        daysCount: 6,
        price: 150,
      ),
      const _PlanSeed(
        id: 'monthly_8',
        title: '26 يوم @ 8 Mbps',
        category: SubscriptionCategory.monthly,
        bandwidth: 8,
        daysCount: 26,
        price: 380,
      ),
      const _PlanSeed(
        id: 'monthly_16',
        title: '26 يوم @ 16 Mbps',
        category: SubscriptionCategory.monthly,
        bandwidth: 16,
        daysCount: 26,
        price: 400,
      ),
      const _PlanSeed(
        id: 'monthly_32',
        title: '26 يوم @ 32 Mbps',
        category: SubscriptionCategory.monthly,
        bandwidth: 32,
        daysCount: 26,
        price: 450,
      ),
    ];

    for (final seed in seeds) {
      await fs.set('plans/${seed.id}', {
        'title': seed.title,
        'category': seed.category.rawValue,
        'bandwidthMbps': seed.bandwidth,
        'daysCount': seed.daysCount,
        'price': seed.price,
        'active': true,
        'createdAt': nowIso,
        'updatedAt': nowIso,
      }, merge: false);
    }
  }

  Future<void> _backfillCycles() async {
    final plansSnap = await fs.getCol('plans');
    final plans = plansSnap.docs
        .map((d) => Plan.fromMap(d.id, d.data()))
        .toList();
    final weeklyByPrice = {
      for (final p in plans.where((p) => p.category == SubscriptionCategory.weekly))
        p.price: p,
    };
    final monthlyByPrice = {
      for (final p in plans.where((p) => p.category == SubscriptionCategory.monthly))
        p.price: p,
    };

    final weeklySnap = await fs.getCol('weekly_cycles');
    for (final doc in weeklySnap.docs) {
      final data = doc.data();
      final planId = data['planId'] as String?;
      if (planId != null && planId.isNotEmpty) {
        continue;
      }
      final price = (data['priceAtStart'] ?? 0) as num;
      final days = (data['days'] ?? 0) as int;
      final plan = weeklyByPrice[price];
      if (plan == null || plan.daysCount != days) {
        continue;
      }
      await doc.reference.update({
        'planId': plan.id,
        'planTitleSnapshot': plan.title,
        'bandwidthMbpsSnapshot': plan.bandwidthMbps,
      });
    }

    final monthlySnap = await fs.getCol('monthly_cycles');
    for (final doc in monthlySnap.docs) {
      final data = doc.data();
      final planId = data['planId'] as String?;
      if (planId != null && planId.isNotEmpty) {
        continue;
      }
      final price = (data['priceAtStart'] ?? 0) as num;
      final days = (data['days'] ?? 0) as int;
      final plan = monthlyByPrice[price];
      if (plan == null || plan.daysCount != days) {
        continue;
      }
      await doc.reference.update({
        'planId': plan.id,
        'planTitleSnapshot': plan.title,
        'bandwidthMbpsSnapshot': plan.bandwidthMbps,
      });
    }
  }
}

class _PlanSeed {
  final String id;
  final String title;
  final SubscriptionCategory category;
  final int bandwidth;
  final int daysCount;
  final num price;
  const _PlanSeed({
    required this.id,
    required this.title,
    required this.category,
    required this.bandwidth,
    required this.daysCount,
    required this.price,
  });
}