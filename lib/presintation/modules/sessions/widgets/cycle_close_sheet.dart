import 'package:flutter/material.dart';
import '../../../../data/repositories/debts_repo.dart';
import '../../../../data/repositories/orders_repo.dart';
import '../../../../data/models/order.dart';

/// تنسيق العملة شيكل
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class CycleCloseSheet extends StatelessWidget {
  final String refType; // 'weekly' | 'monthly'
  final String refId;
  final String title;

  const CycleCloseSheet({
    super.key,
    required this.refType,
    required this.refId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final debtsRepo = DebtsRepo();
    final ordersRepo = OrdersRepo();

    // اختر stream الطلبات حسب نوع الدورة
    final Stream<List<OrderModel>> ordersStream =
    refType == 'weekly' ? ordersRepo.watchByWeekly(refId) : ordersRepo.watchByMonthly(refId);

    bool paid = true;
    String method = 'cash';

    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.35,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, ctrl) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),

                      // إجمالي الطلبات
                      StreamBuilder<List<OrderModel>>(
                        stream: ordersStream,
                        builder: (context, snap) {
                          final orders = snap.data ?? const <OrderModel>[];
                          final drinksTotal = orders.fold<num>(0, (s, o) => s + (o.total ?? 0));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('إجمالي الطلبات (مشروبات)'),
                                trailing: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(sCurrency(drinksTotal)),
                                ),
                              ),
                              if (orders.isNotEmpty)
                                SizedBox(
                                  height: 140,
                                  child: ListView.separated(
                                    controller: ctrl,
                                    itemCount: orders.length,
                                    separatorBuilder: (_, __) => const Divider(height: 8),
                                    itemBuilder: (_, i) {
                                      final o = orders[i];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('${o.itemName} × ${o.qty}'),
                                        // نحط التفاصيل تحت بعض لتفادي القص
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Directionality(
                                                textDirection: TextDirection.ltr,
                                                child: Text('سعر الوحدة: ${sCurrency(o.unitPriceAtTime ?? 0)}',
                                                    style: Theme.of(context).textTheme.bodySmall),
                                              ),
                                              Directionality(
                                                textDirection: TextDirection.ltr,
                                                child: Text('الإجمالي: ${sCurrency(o.total ?? 0)}',
                                                    style: Theme.of(context).textTheme.bodySmall),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('لا توجد طلبات في هذه الدورة.'),
                                ),
                              const Divider(height: 16),
                            ],
                          );
                        },
                      ),

                      // إجمالي الديون المفتوحة المرتبطة بهذه الدورة
                      FutureBuilder<num>(
                        future: DebtsRepo().openTotalByRef(refType: refType, refId: refId),
                        builder: (context, snap) {
                          final due = snap.data ?? 0;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('الديون المفتوحة لهذه الدورة'),
                            trailing: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(sCurrency(due)),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('اعتبارها مدفوعة الآن؟'),
                        value: paid,
                        onChanged: (v) => setState(() => paid = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: method,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدًا')),
                          DropdownMenuItem(value: 'card', child: Text('بطاقة/تطبيق')),
                          DropdownMenuItem(value: 'other', child: Text('أخرى')),
                        ],
                        onChanged: paid ? (v) => setState(() => method = v ?? 'cash') : null,
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop<Map<String, dynamic>>(context, {
                                  'paid': paid,
                                  'method': method,
                                });
                              },
                              child: const Text('إغلاق ومتابعة'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
