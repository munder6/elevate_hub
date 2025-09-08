// lib/presintation/modules/sessions/monthly_cycle_view.dart
import 'dart:async';
import 'package:elevate_hub/presintation/modules/sessions/widgets/cycle_close_sheet.dart';
import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/monthly_cycle.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/debts_repo.dart';
import '../../../data/repositories/monthly_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/settings_repo.dart';
import 'widgets/add_order_sheet.dart';

String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class MonthlyCycleView extends StatefulWidget {
  final Member member;
  const MonthlyCycleView({super.key, required this.member});

  @override
  State<MonthlyCycleView> createState() => _MonthlyCycleViewState();
}

class _MonthlyCycleViewState extends State<MonthlyCycleView> {
  final monthlyRepo = MonthlyRepo();
  final ordersRepo = OrdersRepo();
  final settingsRepo = SettingsRepo();

  String? activeCycleId;
  StreamSubscription<List<MonthlyCycle>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = monthlyRepo.watchActiveByMember(widget.member.id).listen((list) {
      if (!mounted) return;
      setState(() => activeCycleId = list.isNotEmpty ? list.first.id : null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _addOrderFlow(BuildContext context) async {
    if (activeCycleId == null) return;
    final s = await settingsRepo.watchSettings().first;
    final drinks = s?.drinks.where((e) => e.active).toList() ?? [];
    if (drinks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مشروبات مفعّلة في الإعدادات')),
      );
      return;
    }
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddOrderSheet(drinks: drinks),
    );
    if (result != null) {
      await ordersRepo.addOrderForMonthly(
        cycleId: activeCycleId!,
        itemName: result['itemName'] as String,
        unitPriceAtTime: result['unitPriceAtTime'] as num,
        qty: result['qty'] as int,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = activeCycleId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عنوان مع أيقونة — واضح وما في تداخل
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.calendar_month_rounded,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'شهري (26 يوم) — ${widget.member.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (!isActive)
                FilledButton.icon(
                  onPressed: () async {
                    final id = await monthlyRepo.start(widget.member.id);
                    setState(() => activeCycleId = id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم بدء الدورة الشهرية ✅')),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('بدء الشهري'),
                ),

              if (isActive) ...[
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _addOrderFlow(context),
                      icon: const Icon(Icons.local_cafe_rounded),
                      label: const Text('إضافة طلب'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CycleCloseSheet(
                            refType: 'monthly',
                            refId: activeCycleId!,
                            title: 'إغلاق الشهري (26 يوم)',
                          ),
                        );

                        if (picked == null) return;
                        final bool paid = picked['paid'] as bool? ?? false;
                        final String method = picked['method'] as String? ?? 'cash';

                        await monthlyRepo.close(activeCycleId!);

                        if (paid) {
                          await DebtsRepo().settleByRef(
                            refType: 'monthly',
                            refId: activeCycleId!,
                            method: method,
                          );
                        }

                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text('إغلاق الشهري'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // قائمة الطلبات — RTL، كل شيء ظاهر (اسم × كمية + سعر وحدة + إجمالي + التاريخ)
                StreamBuilder<List<OrderModel>>(
                  stream: ordersRepo.watchByMonthly(activeCycleId!),
                  builder: (context, snap) {
                    final orders = snap.data ?? const <OrderModel>[];
                    final drinksTotal =
                    orders.fold<num>(0, (s, o) => s + (o.total ?? 0));

                    if (orders.isEmpty) {
                      return const ListTile(dense: true, title: Text('لا توجد طلبات بعد'));
                    }

                    return Column(
                      children: [
                        ...orders.map(
                              (o) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(.12),
                              child: Icon(Icons.local_cafe_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(
                              '${o.itemName} × ${o.qty}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سعر الوحدة: ${sCurrency(o.unitPriceAtTime ?? 0)}  •  الإجمالي: ${sCurrency(o.total ?? 0)}',
                                  textDirection: TextDirection.rtl,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (o.createdAt != null)
                                  Text(
                                    'التاريخ: ${o.createdAt.toString().substring(0,16)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(.7),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'حذف الطلب',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async => ordersRepo.removeOrder(o),
                            ),
                          ),
                        ),
                        const Divider(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'إجمالي المشروبات: ${sCurrency(drinksTotal)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
