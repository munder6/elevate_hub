import 'package:elevate_hub/presintation/modules/sessions/widgets/cycle_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/session.dart';
import '../../../data/models/weekly_cycle.dart';
import '../../../data/models/monthly_cycle.dart';

import '../../../data/repositories/cycles_overview_repo.dart';
import '../../../data/repositories/sessions_repo.dart';
import 'sessions_controller.dart';

import 'session_details_sheet.dart';

// صيغة عملة الشيكل
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class SessionsOverviewView extends StatelessWidget {
  const SessionsOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SessionsController(SessionsRepo()));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ملخص الجلسات'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'ساعات'),
                Tab(text: 'أسبوعي'),
                Tab(text: 'شهري'),
              ],
            ),
          ),
          body: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              // ----- بالساعة -----
              _InnerPeriodTabs<Session, SessionsSummary>(
                summaryToday: c.daySummary,
                summaryWeek:  c.weekSummary,
                summaryMonth: c.monthSummary,
                listToday:    c.daySessions,
                listWeek:     c.weekSessions,
                listMonth:    c.monthSessions,
                statsBuilder: (sum) => _StatsCard(
                  items: [
                    _Stat('جلسات', '${sum.count}', Icons.event_available_rounded),
                    _Stat('دقائق', '${sum.minutes}', Icons.schedule_rounded),
                    _Stat('إجمالي', sCurrency(sum.grand), Icons.attach_money_rounded),
                  ],
                ),
                itemBuilder: (ctx, s) => _HourlyTile(
                  s: s,
                  onTap: () => showModalBottomSheet(
                    context: ctx, isScrollControlled: true, useSafeArea: true,
                    builder: (_) => SessionDetailsSheet(session: s),
                  ),
                ),
                emptyText: 'لا توجد جلسات بالساعة في هذا النطاق.',
              ),

              // ----- أسبوعي -----
              _InnerPeriodTabs<WeeklyCycle, CyclesOverviewSummary>(
                summaryToday: c.wDaySummary,
                summaryWeek:  c.wWeekSummary,
                summaryMonth: c.wMonthSummary,
                listToday:    c.wDayList,
                listWeek:     c.wWeekList,
                listMonth:    c.wMonthList,
                statsBuilder: (sum) => _StatsCard(
                  items: [
                    _Stat('دورات أسبوعية', '${sum.count}', Icons.event_note_rounded),
                    _Stat('محصّل', sCurrency(sum.collected), Icons.payments_rounded),
                    _Stat('إجمالي', sCurrency(sum.total), Icons.attach_money_rounded),
                  ],
                ),
                itemBuilder: (ctx, w) => _CycleTile(
                  title: w.memberName,
                  startDate: w.startDate,
                  daysUsed: w.daysUsed,
                  days: w.days,
                  drinks: w.drinksTotal,
                  total: (w.dayCost * w.daysUsed) + w.drinksTotal,
                  status: w.status,
                  badge: 'أسبوعي',
                  onTap: () => showModalBottomSheet(
                    context: ctx, isScrollControlled: true, useSafeArea: true,
                    builder: (_) => CycleDetailsSheet.weekly(cycle: w),
                  ),
                ),
                emptyText: 'لا توجد دورات أسبوعية في هذا النطاق.',
              ),

              // ----- شهري -----
              _InnerPeriodTabs<MonthlyCycle, CyclesOverviewSummary>(
                summaryToday: c.mDaySummary,
                summaryWeek:  c.mWeekSummary,
                summaryMonth: c.mMonthSummary,
                listToday:    c.mDayList,
                listWeek:     c.mWeekList,
                listMonth:    c.mMonthList,
                statsBuilder: (sum) => _StatsCard(
                  items: [
                    _Stat('دورات شهرية', '${sum.count}', Icons.event_note_rounded),
                    _Stat('محصّل', sCurrency(sum.collected), Icons.payments_rounded),
                    _Stat('إجمالي', sCurrency(sum.total), Icons.attach_money_rounded),
                  ],
                ),
                itemBuilder: (ctx, m) => _CycleTile(
                  title: m.memberName,
                  startDate: m.startDate,
                  daysUsed: m.daysUsed,
                  days: m.days,
                  drinks: m.drinksTotal,
                  total: (m.dayCost * m.daysUsed) + m.drinksTotal,
                  status: m.status,
                  badge: 'شهري',
                  onTap: () => showModalBottomSheet(
                    context: ctx, isScrollControlled: true, useSafeArea: true,
                    builder: (_) => CycleDetailsSheet.monthly(cycle: m),
                  ),
                ),
                emptyText: 'لا توجد دورات شهرية في هذا النطاق.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ======================== Tabs (اليوم/الأسبوع/الشهر) ======================== */

class _InnerPeriodTabs<TItem, TSum> extends StatelessWidget {
  final Stream<TSum> summaryToday;
  final Stream<TSum> summaryWeek;
  final Stream<TSum> summaryMonth;

  final Stream<List<TItem>> listToday;
  final Stream<List<TItem>> listWeek;
  final Stream<List<TItem>> listMonth;

  final Widget Function(TSum) statsBuilder;
  final Widget Function(BuildContext, TItem) itemBuilder;

  final String emptyText;

  const _InnerPeriodTabs({
    required this.summaryToday,
    required this.summaryWeek,
    required this.summaryMonth,
    required this.listToday,
    required this.listWeek,
    required this.listMonth,
    required this.itemBuilder,
    required this.statsBuilder,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            color: Colors.transparent,
            child: TabBar(
              tabs: [
                Tab(text: 'اليوم'),
                Tab(text: 'هذا الأسبوع'),
                Tab(text: 'هذا الشهر'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                _RangeBody<TItem, TSum>(
                    summaryStream: summaryToday, listStream: listToday,
                    itemBuilder: itemBuilder, statsBuilder: statsBuilder, emptyText: emptyText),
                _RangeBody<TItem, TSum>(
                    summaryStream: summaryWeek, listStream: listWeek,
                    itemBuilder: itemBuilder, statsBuilder: statsBuilder, emptyText: emptyText),
                _RangeBody<TItem, TSum>(
                    summaryStream: summaryMonth, listStream: listMonth,
                    itemBuilder: itemBuilder, statsBuilder: statsBuilder, emptyText: emptyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeBody<TItem, TSum> extends StatelessWidget {
  final Stream<TSum> summaryStream;
  final Stream<List<TItem>> listStream;
  final Widget Function(TSum) statsBuilder;
  final Widget Function(BuildContext, TItem) itemBuilder;
  final String emptyText;

  const _RangeBody({
    required this.summaryStream,
    required this.listStream,
    required this.itemBuilder,
    required this.statsBuilder,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          StreamBuilder<TSum>(
            stream: summaryStream,
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) return const _StatsSkeletonRow();
              return statsBuilder(s);
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<TItem>>(
              stream: listStream,
              builder: (context, snap) {
                final list = snap.data ?? <TItem>[];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return Center(child: Text(emptyText));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => itemBuilder(context, list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== UI Components ============================== */

class _Stat {
  final String label; final String value; final IconData icon;
  _Stat(this.label, this.value, this.icon);
}

class _StatsCard extends StatelessWidget {
  final List<_Stat> items;
  const _StatsCard({required this.items});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: items
              .map((e) => Expanded(child: _StatBlock(item: e)))
              .toList(),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final _Stat item;
  const _StatBlock({required this.item});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(item.value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(item.label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _StatsSkeletonRow extends StatelessWidget {
  const _StatsSkeletonRow();
  @override
  Widget build(BuildContext context) {
    Widget skel() => SizedBox(
      width: 90,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Container(height: 20, width: 20, color: Colors.black12),
          const SizedBox(height: 8),
          Container(height: 22, width: 64, color: Colors.black12),
          const SizedBox(height: 4),
          Container(height: 12, width: 54, color: Colors.black12),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [skel(), skel(), skel()],
        ),
      ),
    );
  }
}

/* ------------------------------ Hourly Tile ------------------------------ */

class _HourlyTile extends StatelessWidget {
  final Session s;
  final VoidCallback onTap;
  const _HourlyTile({required this.s, required this.onTap});

  String _arStatus(String st) => st == 'closed' ? 'مغلق' : 'مفتوح';
  String _arMethod(String m) => switch (m) {
    'cash' => 'كاش',
    'app' => 'تطبيق',
    'card' => 'بطاقة',
    'unpaid' => 'غير مدفوع',
    _ => m,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methodColor = switch (s.paymentMethod) {
      'cash'   => Colors.green,
      'app'    => Colors.blue,
      'card'   => Colors.purple,
      'unpaid' => Colors.orange,
      _        => theme.colorScheme.primary,
    };

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                theme.colorScheme.primary.withOpacity(.04),
                theme.colorScheme.secondaryContainer.withOpacity(.10),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // كبسولة الدقائق
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${s.minutes}د',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),

                // الوسط
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم
                      Text(
                        s.memberName?.isNotEmpty == true ? s.memberName! : s.memberId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),

                      // شِيبس بدون تداخل + سطر التاريخ منفصل
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(' ${_arStatus(s.status)} ', s.status == 'closed' ? Colors.teal : Colors.amber),
                          _chip(' ${_arMethod(s.paymentMethod)} ', methodColor),
                          if ((s.paymentProofUrl ?? '').isNotEmpty) _chip(' إشعار الدفع ', Colors.indigo),
                          if (s.drinksTotal > 0) _chip(' مشروبات ${sCurrency(s.drinksTotal)} ', Colors.brown),
                          if (s.discount > 0) _chip(' خصم ${sCurrency(s.discount)} ', Colors.redAccent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: theme.colorScheme.onSurface.withOpacity(.6)),
                          const SizedBox(width: 6),
                          Text(
                            s.checkInAt.toString().substring(0, 16),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // الإجمالي
                Text(
                  sCurrency(s.grandTotal),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(.12),
      border: Border.all(color: c.withOpacity(.35)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: TextStyle(color: c.withOpacity(.95), fontWeight: FontWeight.w700, fontSize: 11.5)),
  );
}

/* ------------------------------ Cycle Tile ------------------------------ */

class _CycleTile extends StatelessWidget {
  final String title;
  final DateTime startDate;
  final int daysUsed;
  final int days;
  final num drinks;
  final num total;
  final String status;
  final String badge;
  final VoidCallback onTap;

  const _CycleTile({
    required this.title,
    required this.startDate,
    required this.daysUsed,
    required this.days,
    required this.drinks,
    required this.total,
    required this.status,
    required this.badge,
    required this.onTap,
  });

  String _arStatus(String st) => st == 'closed' ? 'مغلق' : 'مفتوح';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = status == 'closed' ? Colors.teal : Colors.amber;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                theme.colorScheme.primary.withOpacity(.04),
                theme.colorScheme.secondaryContainer.withOpacity(.10),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بادچ نوع الدورة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge,
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),

                // الوسط
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniChip('الحالة: ${_arStatus(status)}', statusColor),
                          _miniChip('الأيام: $daysUsed / $days', Colors.indigo),
                          if (drinks > 0) _miniChip('مشروبات ${sCurrency(drinks)}', Colors.brown),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: theme.colorScheme.onSurface.withOpacity(.6)),
                          const SizedBox(width: 6),
                          Text(
                            // عرض تاريخ البداية داخل الكرت
                            startDate.toString().substring(0, 10),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // الإجمالي
                Text(
                  sCurrency(total),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(.12),
      border: Border.all(color: c.withOpacity(.35)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: TextStyle(color: c.withOpacity(.95), fontWeight: FontWeight.w700, fontSize: 11.5)),
  );
}
