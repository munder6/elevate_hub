import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../../data/models/monthly_cycle.dart';
import '../../../../data/models/weekly_cycle.dart';

/// تنسيق الشيكل
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class CycleDetailsSheet extends StatelessWidget {
  final String title;
  final String type; // أسبوعي / شهري
  final DateTime startDate;
  final int days;
  final int daysUsed;
  final num priceAtStart;
  final num dayCost;
  final num drinks;
  final String status;

  const CycleDetailsSheet._({
    super.key,
    required this.title,
    required this.type,
    required this.startDate,
    required this.days,
    required this.daysUsed,
    required this.priceAtStart,
    required this.dayCost,
    required this.drinks,
    required this.status,
  });

  factory CycleDetailsSheet.weekly({required WeeklyCycle cycle}) =>
      CycleDetailsSheet._(
        title: cycle.memberName,
        type: 'أسبوعي',
        startDate: cycle.startDate,
        days: cycle.days,
        daysUsed: cycle.daysUsed,
        priceAtStart: cycle.priceAtStart,
        dayCost: cycle.dayCost,
        drinks: cycle.drinksTotal,
        status: cycle.status,
      );

  factory CycleDetailsSheet.monthly({required MonthlyCycle cycle}) =>
      CycleDetailsSheet._(
        title: cycle.memberName,
        type: 'شهري',
        startDate: cycle.startDate,
        days: cycle.days,
        daysUsed: cycle.daysUsed,
        priceAtStart: cycle.priceAtStart,
        dayCost: cycle.dayCost,
        drinks: cycle.drinksTotal,
        status: cycle.status,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collected = dayCost * daysUsed;
    final total = collected + drinks;

    final isClosed = status == 'closed';
    final statusColor = isClosed ? Colors.teal : Colors.amber;
    final statusLabel = isClosed ? 'مغلقة' : 'مفتوحة';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: theme.colorScheme.surface.withOpacity(.96),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: SingleChildScrollView( // يمنع أي Overflow
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // العنوان
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$title • $type',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // شِبّات الحالة والأيام (بدون runSpacing سالب حتى ما يصير تداخل)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chip('الحالة: $statusLabel', statusColor),
                          _chip('الأيام: $daysUsed / $days', Colors.indigo),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // الكارد — تاريخ البدء داخل الكارد + القيم المالية
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _row(context, 'تاريخ البدء', startDate.toString().substring(0, 10)),
                              const Divider(),
                              _row(context, 'سعر الخطة عند البدء', sCurrency(priceAtStart), strong: true),
                              _row(context, 'تكلفة اليوم', sCurrency(dayCost)),
                              _row(context, 'مشروبات', sCurrency(drinks)),
                              _row(context, 'محصّل حتى الآن', sCurrency(collected)),
                              const Divider(),
                              _row(context, 'الإجمالي', sCurrency(total), big: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withOpacity(.12),
      border: Border.all(color: c.withOpacity(.35)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: c.withOpacity(.95), fontWeight: FontWeight.w700),
    ),
  );

  Widget _row(BuildContext context, String label, String value, {bool strong = false, bool big = false}) {
    final theme = Theme.of(context);
    final style = big
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)
        : strong
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.bodyMedium;

    // الأرقام تعرض باتجاه LTR لتظهر صحيحة مع العملة/الأرقام
    final isNumeric = RegExp(r'^[\s₪0-9\.\-]+$').hasMatch(value);
    final valueWidget = Text(
      value,
      style: style,
      textDirection: isNumeric ? TextDirection.ltr : TextDirection.rtl,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          valueWidget,
        ],
      ),
    );
  }
}
