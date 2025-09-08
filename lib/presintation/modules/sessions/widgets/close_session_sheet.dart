import 'package:flutter/material.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../data/repositories/orders_repo.dart';
import '../../../../data/models/order.dart';

/// تنسيق الشيكل
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class CloseSessionOptions {
  final String paymentMethod; // cash|card|other
  final num discount;
  const CloseSessionOptions({
    required this.paymentMethod,
    required this.discount,
  });
}

class CloseSessionSheet extends StatefulWidget {
  final String sessionId;
  final String memberId;
  const CloseSessionSheet({
    super.key,
    required this.sessionId,
    required this.memberId,
  });

  @override
  State<CloseSessionSheet> createState() => _CloseSessionSheetState();
}

class _CloseSessionSheetState extends State<CloseSessionSheet> {
  final discountCtrl = TextEditingController();
  final fs = FirestoreService();
  final ordersRepo = OrdersRepo();

  String payment = 'cash';
  String? err;

  @override
  void dispose() {
    discountCtrl.dispose();
    super.dispose();
  }

  int _roundTo5Minutes(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    final rem = mins % 5;
    return rem == 0 ? mins : mins + (5 - rem);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // مقبض صغير
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text('إغلاق الجلسة', style: Theme.of(context).textTheme.titleMedium),

                const SizedBox(height: 12),
                _SummaryCard(
                  sessionId: widget.sessionId,
                  fs: fs,
                  ordersRepo: ordersRepo,
                  roundTo5: _roundTo5Minutes,
                ),

                const SizedBox(height: 12),
                Text('طريقة الدفع', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                // استخدمنا Wrap لمنع التداخل على الشاشات الصغيرة
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('كاش'),
                      selected: payment == 'cash',
                      onSelected: (_) => setState(() => payment = 'cash'),
                    ),
                    ChoiceChip(
                      label: const Text('تطبيق'),
                      selected: payment == 'app',
                      onSelected: (_) => setState(() => payment = 'app'),
                    ),
                    ChoiceChip(
                      label: const Text('تسجيل دين'),
                      selected: payment == 'unpaid',
                      onSelected: (_) => setState(() => payment = 'unpaid'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'خصم يدوي (اختياري)',
                    hintText: 'مثال: 2.5',
                    prefixText: '₪ ',
                    errorText: err,
                  ),
                ),

                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () {
                    final dTxt = discountCtrl.text.trim();
                    final d = dTxt.isEmpty ? 0 : num.tryParse(dTxt);
                    if (dTxt.isNotEmpty && (d == null || d < 0)) {
                      setState(() => err = 'قيمة خصم غير صالحة');
                      return;
                    }
                    Navigator.pop<CloseSessionOptions>(
                      context,
                      CloseSessionOptions(paymentMethod: payment, discount: d ?? 0),
                    );
                  },
                  label: const Text('تأكيد الإغلاق'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String sessionId;
  final FirestoreService fs;
  final OrdersRepo ordersRepo;
  final int Function(Duration) roundTo5;

  const _SummaryCard({
    required this.sessionId,
    required this.fs,
    required this.ordersRepo,
    required this.roundTo5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: fs.getDoc('sessions/$sessionId').then((d) => d.data()),
          builder: (context, sessSnap) {
            final s = sessSnap.data;
            final checkIn = s?['checkInAt'] != null
                ? DateTime.tryParse(s!['checkInAt'].toString())
                : null;
            final rate = (s?['hourlyRateAtTime'] ?? 0) as num;

            final minutes = checkIn == null
                ? 0
                : roundTo5(DateTime.now().difference(checkIn));
            final hours = (minutes / 60);

            return StreamBuilder<List<OrderModel>>(
              stream: ordersRepo.watchBySession(sessionId),
              builder: (context, ordSnap) {
                final orders = ordSnap.data ?? const <OrderModel>[];
                final drinksTotal =
                orders.fold<num>(0, (sum, o) => sum + (o.total ?? 0));
                final sessionAmount = hours * rate;
                const previewDiscount = 0;
                final grandTotal =
                    sessionAmount + drinksTotal - previewDiscount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // وقت الجلسة
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'الوقت: ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text('${minutes}m  (${hours.toStringAsFixed(2)}h)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // أجر الساعة
                    Row(
                      children: [
                        const Icon(Icons.price_change_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'الأجر/ساعة: ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(sCurrency(rate)),
                        ),
                      ],
                    ),
                    const Divider(),

                    // الطلبات
                    if (orders.isEmpty)
                      const Text('الطلبات: —')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الطلبات (${orders.length})'),
                          const SizedBox(height: 6),
                          ...orders.take(3).map(
                                (o) => Row(
                              children: [
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${o.itemName} × ${o.qty}  •  ${sCurrency(o.total ?? 0)}',
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (orders.length > 3)
                            Text(
                              '… و ${orders.length - 3} أخرى',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),

                    const SizedBox(height: 8),
                    // المجموعات
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text('الجلسة: ${sCurrency(sessionAmount)}'),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text('المشروبات: ${sCurrency(drinksTotal)}'),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text('الخصم: -${sCurrency(previewDiscount)}'),
                          ),
                          const Divider(),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              'الإجمالي التقديري: ${sCurrency(grandTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
