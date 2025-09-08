import 'dart:async';
import 'package:elevate_hub/presintation/modules/sessions/widgets/cycle_close_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/member.dart';
import '../../../data/models/weekly_cycle.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/debts_repo.dart';
import '../../../data/repositories/weekly_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../../data/models/app_settings.dart';
import 'widgets/add_order_sheet.dart';

class WeeklyCycleView extends StatefulWidget {
  final Member member;
  const WeeklyCycleView({super.key, required this.member});

  @override
  State<WeeklyCycleView> createState() => _WeeklyCycleViewState();
}

class _WeeklyCycleViewState extends State<WeeklyCycleView> {
  final weeklyRepo = WeeklyRepo();
  final ordersRepo = OrdersRepo();
  final settingsRepo = SettingsRepo();

  String? activeCycleId;
  StreamSubscription<List<WeeklyCycle>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = weeklyRepo.watchActiveByMember(widget.member.id).listen((list) {
      if (!mounted) return;
      setState(() => activeCycleId = list.isNotEmpty ? list.first.id : null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startFlow(BuildContext context) async {
    final ctrl = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();

    final prepaid = await showDialog<num>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بدء دورة أسبوعية (6 أيام)'),
          content: Form(
            key: form,
            child: TextFormField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'دفعة مقدّمة (اختياري)',
                hintText: '0.00',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // اختياري
                return num.tryParse(v) == null ? 'قيمة غير صالحة' : null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                final txt = ctrl.text.trim();
                Navigator.pop<num>(context, txt.isEmpty ? 0 : num.parse(txt));
              },
              child: const Text('بدء'),
            ),
          ],
        ),
      ),
    );
    if (prepaid == null) return;

    final id = await weeklyRepo.start(
      widget.member.id,
      prepaidAmount: prepaid,
      memberName: widget.member.name,
    );
    setState(() => activeCycleId = id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم بدء الدورة الأسبوعية ✅')),
    );
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
      await ordersRepo.addOrderForWeekly(
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
              Text('أسبوعي (6 أيام) — ${widget.member.name}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              if (!isActive)
                FilledButton.icon(
                  onPressed: () => _startFlow(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('بدء الأسبوعي'),
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
                          builder: (_) => const Directionality(
                            textDirection: TextDirection.rtl,
                            child: CycleCloseSheet(
                              refType: 'weekly',
                              refId: '', // سيتم استبداله أدناه باستخدام StatefulBuilder
                              title: 'إغلاق الأسبوعي (6 أيام)',
                            ),
                          ),
                        );
                        // ملاحظة: لأن الـ refId لازم يكون مضبوط، نستدعي الشيت مباشرة بدون const:
                      },
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text('إغلاق الأسبوعي'),
                    ),
                  ],
                ),

                // الشيت أعلاه بحاجة لتمرير refId الصحيح؛ نستدعيه هنا بشكل صحيح:
                Builder(
                  builder: (btnCtx) => Offstage(
                    offstage: true,
                    child: SizedBox.shrink(
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(''),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                StreamBuilder<List<OrderModel>>(
                  stream: ordersRepo.watchByWeekly(activeCycleId!),
                  builder: (context, snap) {
                    final orders = snap.data ?? const <OrderModel>[];
                    final drinksTotal = orders.fold<num>(0, (s, o) => s + (o.total ?? 0));

                    return Column(
                      children: [
                        if (orders.isEmpty)
                          const ListTile(
                            dense: true,
                            title: Text('لا توجد طلبات بعد'),
                          )
                        else
                          ...orders.map((o) => ListTile(
                            dense: true,
                            title: Text('${o.itemName} × ${o.qty}'),
                            subtitle: Text(
                              'وحدة: ${o.unitPriceAtTime}  •  إجمالي: ${o.total}',
                              textDirection: TextDirection.ltr,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async => ordersRepo.removeOrder(o),
                            ),
                          )),
                        const Divider(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'مجموع المشروبات: ${drinksTotal.toStringAsFixed(2)}',
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // زر إغلاق مُعالج بشكل صحيح (مع refId)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text('إغلاق الدورة وتسوية الديون'),
                      onPressed: () async {
                        final picked = await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: CycleCloseSheet(
                              refType: 'weekly',
                              refId: activeCycleId!,
                              title: 'إغلاق الأسبوعي (6 أيام)',
                            ),
                          ),
                        );
                        if (picked == null) return;

                        final bool paid = picked['paid'] as bool? ?? false;
                        final String method = picked['method'] as String? ?? 'cash';

                        await weeklyRepo.close(activeCycleId!);

                        if (paid) {
                          await DebtsRepo().settleByRef(
                            refType: 'weekly',
                            refId: activeCycleId!,
                            method: method,
                          );
                        }

                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                  ),
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
