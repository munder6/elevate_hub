import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/order.dart';
import '../../../data/models/monthly_cycle.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/wallet_repo.dart';
import '../../../data/repositories/monthly_cycles_repo.dart';
import '../../../data/repositories/debts_repo.dart';
import '../../modules/sessions/widgets/add_order_sheet.dart';
import '../../wallet/wallet_topup_sheet.dart';

class MonthlyCycleSheet extends StatelessWidget {
  final Member member;
  const MonthlyCycleSheet({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final walletRepo = WalletRepo();
    final debtsRepo = DebtsRepo();
    final monthlyRepo = MonthlyCyclesRepo();
    final ordersRepo = OrdersRepo();
    final settingsRepo = SettingsRepo();

    Future<void> _startCycleIfNeeded() async {
      // اسأل عن المبلغ المقدَّم (اختياري)
      final prepaid = await showModalBottomSheet<num?>(
        context: context,
        isScrollControlled: true,
        builder: (_) => WalletTopUpSheet(member: member),
      );

      // لو المستخدم سكّر الشيت بدون إدخال قيمة، اعتبرها 0
      final prepaidAmount = (prepaid ?? 0);

      // هذه الدالة:
      // - تنشئ دورة شهرية
      // - تعتمد المقدم كـ top-up على المحفظة ومربوط بالدورة
      // - تخصم السعر الشهري كاملًا (وتنشئ دين تلقائيًا لو الرصيد صار سالب)
      await monthlyRepo.startWithPrepaidAndAutoCharge(
        memberId: member.id,
        memberName: member.name,
        prepaidAmount: prepaidAmount,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم بدء الاشتراك الشهري وتطبيق المبلغ المقدم والخصم.')),
      );
    }



    Future<void> _startDay(MonthlyCycle cycle) async {
      await monthlyRepo.startDay(cycle.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day started. (auto-close after 8h)')),
      );
    }

    Future<void> _endDay(MonthlyCycle cycle) async {
      await monthlyRepo.closeOpenDay(cycle.id);
    }

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
            Text('Monthly — ${member.name}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Wallet + Debts (Live)
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
                        Expanded(child: _chip(context, 'Wallet', walletBalance.toStringAsFixed(2))),
                        const SizedBox(width: 6),
                        Expanded(child: _chip(context, 'Open debts', openDebts.toStringAsFixed(2))),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 6),

            // Active Cycle (Live)
            StreamBuilder<MonthlyCycle?>(
              stream: monthlyRepo.watchActiveCycleForMember(member.id),
              builder: (context, cycSnap) {
                if (cycSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  );
                }
                final cycle = cycSnap.data;
                if (cycle == null) {
                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      _chip(context, 'Day cost', '—'),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _startCycleIfNeeded,
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Start monthly'),
                      ),
                    ],
                  );
                }

                final remaining = (cycle.days - cycle.daysUsed).clamp(0, cycle.days);

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _chip(context, 'Day cost', cycle.dayCost.toStringAsFixed(2))),
                        const SizedBox(width: 6),
                        Expanded(child: _chip(context, 'Days', '${cycle.daysUsed} / ${cycle.days} • Left: $remaining')),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: (cycle.openDayId == null && remaining > 0)
                              ? () => _startDay(cycle)
                              : null,
                          icon: const Icon(Icons.timer_outlined),
                          label: const Text('Start Day'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: (cycle.openDayId != null)
                              ? () => _endDay(cycle)
                              : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('End Day'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final r = await monthlyRepo.closeCycle(cycle.id);
                            if (!context.mounted) return;
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
                                    Text('Monthly Summary', style: Theme.of(context).textTheme.titleMedium),
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
                          child: const Text('Close monthly'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Orders
                    StreamBuilder<List<OrderModel>>(
                      stream: ordersRepo.watchByMonthly(cycle.id),
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
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active drinks')));
                                    return;
                                  }
                                  final res = await showModalBottomSheet<Map<String, dynamic>>(
                                    context: context, isScrollControlled: true,
                                    builder: (_) => AddOrderSheet(drinks: drinks),
                                  );
                                  if (res != null) {
                                    await ordersRepo.addOrderForMonthly(
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

  Widget _chip(BuildContext context, String t, String v) => Container(
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
