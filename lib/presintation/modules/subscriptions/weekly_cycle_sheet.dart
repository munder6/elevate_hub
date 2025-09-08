import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/order.dart';
import '../../../data/models/weekly_cycle.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/wallet_repo.dart';
import '../../../data/repositories/weekly_cycles_repo.dart';
import '../../../data/repositories/weekly_days_repo.dart';
import '../../../data/repositories/debts_repo.dart';
import '../../modules/sessions/widgets/add_order_sheet.dart';
import '../../wallet/wallet_topup_sheet.dart';

class WeeklyCycleSheet extends StatefulWidget {
  final Member member;
  const WeeklyCycleSheet({super.key, required this.member});

  @override
  State<WeeklyCycleSheet> createState() => _WeeklyCycleSheetState();
}

class _WeeklyCycleSheetState extends State<WeeklyCycleSheet> {
  final settingsRepo = SettingsRepo();
  final ordersRepo = OrdersRepo();
  final walletRepo = WalletRepo();
  final weeklyRepo = WeeklyCyclesRepo();
  final daysRepo = WeeklyDaysRepo();
  final debtsRepo = DebtsRepo();

  String? activeCycleId;
  num dayCost = 0;
  int daysTotal = 6;
  int daysUsed = 0;
  String? openDayId;
  num weeklyPrice = 0;
  num monthlyPrice = 0;
  num walletBalance = 0;
  num openDebts = 0;

  Timer? _tick;

  Future<void> _refreshStateFromCycle() async {
    final cycles = await weeklyRepo.watchByMember(widget.member.id).first;
    final act = cycles.where((c) => c.status == 'active').toList();
    if (act.isEmpty) {
      setState(() {
        activeCycleId = null;
        dayCost = 0;
        daysUsed = 0;
        openDayId = null;
      });
    } else {
      final c = act.first;
      setState(() {
        activeCycleId = c.id;
        dayCost = c.dayCost;
        daysTotal = c.days;
        daysUsed = c.daysUsed;
        openDayId = c.openDayId;
      });
      await weeklyRepo.ensureAutoClose(c.id);
    }
  }

  Future<void> _refreshWalletAndDebts() async {
    final bal = await walletRepo.getBalanceOnce(widget.member.id);
    final debts = await debtsRepo.watchByMember(widget.member.id, status: 'open').first;
    setState(() {
      walletBalance = bal;
      openDebts = debts.fold<num>(0, (s, d) => s + (d.amount ?? 0));
    });
  }

  Future<void> _loadPrices() async {
    final s = await settingsRepo.watchSettings().first;
    setState(() {
      weeklyPrice  = s?.weekly  ?? 0;
      monthlyPrice = s?.monthly ?? 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPrices();
    _refreshStateFromCycle();
    _refreshWalletAndDebts();

    _tick = Timer.periodic(const Duration(minutes: 1), (_) async {
      final id = activeCycleId;
      if (id != null) {
        await weeklyRepo.ensureAutoClose(id);
        await _refreshStateFromCycle();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }









  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 4, decoration: BoxDecoration(
              color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 12),
            Text('Weekly — ${member.name}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // 1) رصيد المحفظة (Live) + الديون المفتوحة (Live)
            StreamBuilder<num>(
              stream: walletRepo.watchBalance(member.id),
              builder: (context, balSnap) {
                final walletBalance = (balSnap.data ?? 0);
                return StreamBuilder<num>(
                  stream: debtsRepo.watchOpenTotalForMember(member.id),
                  builder: (context, debtSnap) {
                    final openDebts = (debtSnap.data ?? 0);

                    return Row(
                      children: [
                        Expanded(child: _chip('Wallet', walletBalance.toStringAsFixed(2))),
                        const SizedBox(width: 6),
                        Expanded(child: _chip('Open debts', openDebts.toStringAsFixed(2))),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 6),

            // 2) الدورة النشطة (Live)
            StreamBuilder<WeeklyCycle?>(
              stream: weeklyRepo.watchActiveCycleForMember(member.id),
              builder: (context, cycSnap) {
                if (cycSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  );
                }
                final cycle = cycSnap.data;
                if (cycle == null) {
                  // ما في دورة نشطة
                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      _chip('Day cost', '—'),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () async {
                          // لو الرصيد صفر، افتح تعبئة
                          final currentBal = await walletRepo.getBalanceOnce(member.id);
                          if (currentBal <= 0) {
                            final v = await showModalBottomSheet<num?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => WalletTopUpSheet(member: member),
                            );
                            if (v == null) return;
                          }
                          await weeklyRepo.startCycle(memberId: member.id, memberName: member.name);
                          // ما نعمل setState؛ الستريم فوق لحاله يحدّث
                        },
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Start weekly'),
                      ),
                    ],
                  );
                }

                final remaining = (cycle.days - cycle.daysUsed).clamp(0, cycle.days);
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _chip('Day cost', cycle.dayCost.toStringAsFixed(2))),
                        const SizedBox(width: 6),
                        Expanded(child: _chip('Days', '${cycle.daysUsed} / ${cycle.days} • Left: $remaining')),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: (cycle.openDayId == null && remaining > 0)
                              ? () async {
                            // تأكد الرصيد يكفي ليوم واحد
                            final bal = await walletRepo.getBalanceOnce(member.id);
                            if (bal < cycle.dayCost) {
                              final v = await showModalBottomSheet<num?>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => WalletTopUpSheet(member: member),
                              );
                              if (v == null) return;
                              final bal2 = await walletRepo.getBalanceOnce(member.id);
                              if (bal2 < cycle.dayCost) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Balance still insufficient for one day')),
                                );
                                return;
                              }
                            }
                            await weeklyRepo.startDay(cycle.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Day started. (auto-close after 8h)')),
                            );
                          }
                              : null,
                          icon: const Icon(Icons.timer_outlined),
                          label: const Text('Start Day'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: (cycle.openDayId != null)
                              ? () async {
                            await weeklyRepo.closeOpenDay(cycle.id);
                            // لا setState — الستريم سيحدّث (openDayId=null, daysUsed++)
                          }
                              : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('End Day'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final r = await weeklyRepo.closeCycle(cycle.id);
                            if (!mounted) return;
                            await showModalBottomSheet(
                              context: context,
                              builder: (_) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16,16,16,24),
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    Container(width: 48, height: 4, decoration: BoxDecoration(
                                      color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2),
                                    )),
                                    const SizedBox(height: 12),
                                    Text('Weekly Summary', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 8),
                                    _row('Price at start', r.priceAtStart.toStringAsFixed(2)),
                                    _row('Days used', '${r.daysUsed} / ${cycle.days}'),
                                    _row('Drinks total', r.drinksTotal.toStringAsFixed(2)),
                                    const SizedBox(height: 12),
                                    Align(alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: ()=>Navigator.pop(context),
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Done'),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                          child: const Text('Close weekly'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // الطلبات الخاصة بالدورة
                    StreamBuilder<List<OrderModel>>(
                      stream: ordersRepo.watchByWeekly(cycle.id),
                      builder: (_, snap) {
                        final list = snap.data ?? const <OrderModel>[];
                        final total = list.fold<num>(0, (s, o) => s + (o.total ?? 0));
                        return Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Orders', style: Theme.of(context).textTheme.titleSmall),
                            ),
                            const SizedBox(height: 6),
                            if (list.isEmpty)
                              const ListTile(dense: true, title: Text('No orders yet'))
                            else
                              ...list.take(5).map((o) => ListTile(
                                dense: true,
                                title: Text('${o.itemName} × ${o.qty}'),
                                subtitle: Text('Total: ${o.total ?? 0}'),
                              )),
                            if (list.length > 5)
                              Text('... and ${list.length - 5} more'),
                            const Divider(),
                            Align(alignment: Alignment.centerRight,
                                child: Text('Drinks total: ${total.toStringAsFixed(2)}')),
                            const SizedBox(height: 6),
                            Align(alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final s = await settingsRepo.watchSettings().first;
                                  final drinks = s?.drinks.where((e) => e.active).toList() ?? [];
                                  if (drinks.isEmpty) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active drinks')));
                                    return;
                                  }
                                  final res = await showModalBottomSheet<Map<String, dynamic>>(
                                    context: context, isScrollControlled: true,
                                    builder: (_) => AddOrderSheet(drinks: drinks),
                                  );
                                  if (res != null) {
                                    await ordersRepo.addOrderForWeekly(
                                      cycleId: cycle.id,
                                      itemName: res['itemName'] as String,
                                      unitPriceAtTime: res['unitPriceAtTime'] as num,
                                      qty: res['qty'] as int,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.local_cafe_rounded),
                                label: const Text('Add order'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _chip(String t, String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Text(t),
        const Spacer(),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600), textDirection: TextDirection.ltr),
      ],
    ),
  );

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(k)),
      Text(v),
    ]),
  );
}
