import 'package:flutter/material.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../data/repositories/sessions_repo.dart';
import '../../../../data/repositories/orders_repo.dart';
import '../../../../data/repositories/balance_repo.dart';
import '../../../../data/models/order.dart';
import '../../../../data/models/subscription_category.dart';
/// تنسيق العملة (شيكل)
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

/// تعريب طريقة الدفع
String arPaymentMethod(String pm) {
  switch (pm) {
    case 'cash':
      return 'كاش';
    case 'app':
      return 'تطبيق';
    case 'unpaid':
      return 'تسجيل دين';
    default:
      return '—';
  }
}

class SessionReceiptSheet extends StatelessWidget {
  final String sessionId;
  final SessionCloseResult? closeResult;
  SessionReceiptSheet({
    super.key,
    required this.sessionId,
    this.closeResult,
  });

  final fs = FirestoreService();
  final ordersRepo = OrdersRepo();
  final balanceRepo = BalanceRepo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _grab(),
                Text('إيصال الجلسة', style: theme.textTheme.titleMedium),

                const SizedBox(height: 12),

                // رأس الإيصال: من نتيجة الإغلاق إن توفرت، وإلا من الداتابيس
                if (closeResult != null)
                  _HeaderCard(children: _headerRowsFromResult(closeResult!))
                else
                  FutureBuilder<Map<String, dynamic>?>(
                    future: fs.getDoc('sessions/$sessionId').then((d) => d.data()),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final s = snap.data!;
                      final minutes = (s['minutes'] ?? 0) as num;
                      final rate = (s['hourlyRateAtTime'] ?? 0) as num;
                      final drinks = (s['drinksTotal'] ?? 0) as num;
                      final discount = (s['discount'] ?? 0) as num;
                      final sessionAmount = (s['sessionAmount'] ?? 0) as num;
                      final grandTotal = (s['grandTotal'] ?? 0) as num;
                      final pm = (s['paymentMethod'] ?? 'cash').toString();
                      final category = subscriptionCategoryFromRaw(
                          s['category']?.toString());
                      final dailyPrice =
                      (s['dailyPriceSnapshot'] ?? sessionAmount) as num;
                      return _HeaderCard(
                        children: _headerRows(
                          minutes: minutes,
                          rate: rate,
                          sessionAmount: sessionAmount,
                          drinks: drinks,
                          discount: discount,
                          grandTotal: grandTotal,
                          paymentMethod: pm,
                          balanceDeducted: null,
                          category: category,
                          dailyPrice: dailyPrice,
                          debt: null,
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),

                // تفصيل الطلبات داخل الجلسة
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('الطلبات', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 6),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: StreamBuilder<List<OrderModel>>(
                      stream: ordersRepo.watchBySession(sessionId),
                      builder: (context, snap) {
                        final orders = snap.data ?? const <OrderModel>[];
                        if (orders.isEmpty) {
                          return const ListTile(
                            dense: true,
                            title: Text('لا توجد طلبات'),
                          );
                        }
                        final drinksTotal =
                        orders.fold<num>(0, (sum, o) => sum + (o.total ?? 0));

                        return Column(
                          children: [
                            ...orders.map(
                                  (o) => ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                  theme.colorScheme.primary.withOpacity(.12),
                                  child: Icon(Icons.local_cafe_rounded,
                                      size: 18, color: theme.colorScheme.primary),
                                ),
                                title: Text(
                                  '${o.itemName} × ${o.qty}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // سطر الأسعار
                                    Text(
                                      'سعر الوحدة: ${sCurrency(o.unitPriceAtTime ?? 0)}  •  الإجمالي: ${sCurrency(o.total ?? 0)}',
                                      textDirection: TextDirection.rtl,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    // سطر العضو (إن وُجد)
                                    if ((o.memberName ?? '').isNotEmpty)
                                      Text(
                                        'العضو: ${o.memberName}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.75)),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  sCurrency(o.total ?? 0),
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'إجمالي المشروبات: ${sCurrency(drinksTotal)}',
                                textDirection: TextDirection.rtl,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تم'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ------------------------ رأس الإيصال (Helpers) ------------------------ */

  List<Widget> _headerRowsFromResult(SessionCloseResult r) {
    final deducted = r.balanceCharge?.deducted;
    final debt = r.balanceCharge?.debtCreated;

    return _headerRows(
      minutes: r.minutes,
      rate: r.rate,
      sessionAmount: r.sessionAmount,
      drinks: r.drinks,
      discount: r.discount,
      grandTotal: r.grandTotal,
      paymentMethod: r.paymentMethod,
      balanceDeducted: deducted,
      category: r.category,
      dailyPrice: r.sessionAmount,
      debt: debt,
    );
  }

  List<Widget> _headerRows({
    required num minutes,
    required num rate,
    required num sessionAmount,
    required num drinks,
    required num discount,
    required num grandTotal,
    required String paymentMethod,
    num? balanceDeducted,
    SubscriptionCategory? category,
    num? dailyPrice,
    num? debt,
  }) {
    if (category == SubscriptionCategory.daily) {
      final base = dailyPrice ?? sessionAmount;
      return _dailyRows(
        base: base,
        drinks: drinks,
        discount: discount,
        grandTotal: grandTotal,
        paymentMethod: paymentMethod,
        balanceDeducted: balanceDeducted,
        debt: debt,
      );
    }
    final hours = (minutes / 60);

    return [
      _row('الوقت', '${minutes.toStringAsFixed(0)} دقيقة  (${hours.toStringAsFixed(2)} س)'),
      _row('الأجر/ساعة', sCurrency(rate)),
      _row('قيمة الجلسة', sCurrency(sessionAmount)),
      _row('مشروبات', sCurrency(drinks)),
      _row('خصم', '- ${sCurrency(discount)}'),
      const Divider(),
      _row('الإجمالي', sCurrency(grandTotal), isStrong: true),
      const SizedBox(height: 8),
      _row('طريقة الدفع', arPaymentMethod(paymentMethod)),

      if (balanceDeducted != null) ...[
        _row('من الرصيد', '- ${sCurrency(balanceDeducted)}'),
        if (debt != null && debt > 0)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'الرصيد غير كافٍ — تم إنشاء دين بقيمة ${sCurrency(debt)}',
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
      ],
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _dailyRows({
    required num base,
    required num drinks,
    required num discount,
    required num grandTotal,
    required String paymentMethod,
    num? balanceDeducted,
    num? debt,
  }) {
    return [
      _row('سعر اليوم', sCurrency(base)),
      _row('المشروبات/الخدمات', sCurrency(drinks)),
      _row('الخصم', '- ${sCurrency(discount)}'),
      const Divider(),
      _row('الإجمالي', sCurrency(grandTotal), isStrong: true),
      const SizedBox(height: 8),
      _row('طريقة الدفع', arPaymentMethod(paymentMethod)),
      if (balanceDeducted != null) ...[
        _row('من الرصيد', '- ${sCurrency(balanceDeducted)}'),
        if (debt != null && debt > 0)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'الرصيد غير كافٍ — تم إنشاء دين بقيمة ${sCurrency(debt)}',
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
      ],
      const SizedBox(height: 8),
    ];
  }


  Widget _row(String k, String v, {bool isStrong = false}) {
    final style = isStrong
        ? const TextStyle(fontWeight: FontWeight.w700)
        : const TextStyle();

    // إجبار الأرقام/العملة على LTR عند الحاجة
    final isNumeric = RegExp(r'[0-9]').hasMatch(v);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.left,
              textDirection: isNumeric ? TextDirection.ltr : TextDirection.rtl,
              style: style,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grab() => Container(
    width: 50,
    height: 4,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0x33000000),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/* -------------------------- مكوّن بطاقة رأس الإيصال -------------------------- */

class _HeaderCard extends StatelessWidget {
  final List<Widget> children;
  const _HeaderCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: children),
      ),
    );
  }
}
