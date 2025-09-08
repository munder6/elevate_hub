import 'package:flutter/material.dart';
import '../../../data/models/session.dart';

String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class SessionDetailsSheet extends StatelessWidget {
  final Session session;
  const SessionDetailsSheet({super.key, required this.session});

  String arStatus(String? s) => switch (s) {
    'open' => 'نشطة',
    'closed' => 'مغلقة',
    _ => '—',
  };

  String arMethod(String? m) => switch (m) {
    'cash' => 'كاش',
    'app' => 'تطبيق',
    'card' => 'بطاقة',
    'unpaid' => 'غير مدفوع',
    _ => '—',
  };

  Color methodColor(BuildContext ctx, String? m) {
    final theme = Theme.of(ctx);
    return switch (m) {
      'cash' => Colors.green,
      'app' => Colors.blue,
      'card' => Colors.purple,
      'unpaid' => Colors.orange,
      _ => theme.colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // عنوان
                Text('تفاصيل الجلسة',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                // بطاقة التفاصيل/المبالغ + التاريخ داخل الكارد
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _row('العضو',
                            s.memberName?.isNotEmpty == true ? s.memberName! : (s.memberId.isNotEmpty ? s.memberId : '—')),
                        _rowChip('الحالة', arStatus(s.status),
                            chipColor: s.status == 'closed' ? Colors.teal : Colors.amber),
                        _rowChip('طريقة الدفع', arMethod(s.paymentMethod),
                            chipColor: methodColor(context, s.paymentMethod)),
                        const Divider(),
                        _row('الدقائق', '${s.minutes}'),
                        _row('أجر/ساعة', sCurrency(s.hourlyRateAtTime), ltr: true),
                        _row('قيمة الجلسة', sCurrency(s.sessionAmount), ltr: true),
                        const Divider(),
                        _row('مشروبات', sCurrency(s.drinksTotal), ltr: true),
                        _row('خصم', sCurrency(s.discount), ltr: true),
                        const Divider(),

                        // التواريخ داخل الكارد (بدون تداخل)
                        _row('الدخول',
                            s.checkInAt != null
                                ? s.checkInAt.toString().substring(0, 16)
                                : '—',
                            ltr: true),
                        _row('الخروج',
                            s.checkOutAt != null
                                ? s.checkOutAt!.toString().substring(0, 16)
                                : '—',
                            ltr: true),

                        const Divider(),
                        _row('الإجمالي', sCurrency(s.grandTotal), strong: true, ltr: true),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ===== إشعار الدفع: صورة (إن وُجد) =====
                if ((s.paymentProofUrl ?? '').isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('إشعار الدفع', style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => _openImage(context, s.paymentProofUrl!),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          s.paymentProofUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تم إرفاق إشعار الدفع'
                              '${s.paymentProofUploadedAt != null ? ' • ${s.paymentProofUploadedAt!.toString().substring(0,16)}' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // لو ما في صورة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('لا يوجد إشعار دفع مرفق.', style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('تم'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Rows (RTL آمنة، بدون قصّ) =====

  Widget _row(String label, String value,
      {bool strong = false, bool ltr = false}) {
    final style = strong
        ? const TextStyle(fontWeight: FontWeight.w800)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          // القيمة تلفّ على أسطر عند الحاجة — لا قصّ
          Flexible(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowChip(String label, String value, {required Color chipColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(.12),
                  border: Border.all(color: chipColor.withOpacity(.35)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: chipColor.withOpacity(.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            minScale: .8,
            maxScale: 4,
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
