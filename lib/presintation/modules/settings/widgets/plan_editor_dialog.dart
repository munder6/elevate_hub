import 'package:flutter/material.dart';

import '../../../../data/models/plan.dart';
import '../../../../data/models/subscription_category.dart';

class PlanEditorDialog extends StatefulWidget {
  final Plan? initial;
  const PlanEditorDialog({super.key, this.initial});

  @override
  State<PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<PlanEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController titleCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController bandwidthCtrl;
  late TextEditingController daysCtrl;
  late SubscriptionCategory category;
  bool active = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    titleCtrl = TextEditingController(text: initial?.title ?? '');
    priceCtrl = TextEditingController(text: (initial?.price ?? 0).toString());
    bandwidthCtrl =
        TextEditingController(text: (initial?.bandwidthMbps ?? 0).toString());
    daysCtrl = TextEditingController(text: (initial?.daysCount ?? 0).toString());
    category = initial?.category ?? SubscriptionCategory.hours;
    active = initial?.active ?? true;
    _enforceDaysForCategory();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    priceCtrl.dispose();
    bandwidthCtrl.dispose();
    daysCtrl.dispose();
    super.dispose();
  }

  void _enforceDaysForCategory() {
    switch (category) {
      case SubscriptionCategory.hours:
        daysCtrl.text = '0';
        break;
      case SubscriptionCategory.daily:
        daysCtrl.text = '1';
        break;
      case SubscriptionCategory.weekly:
      case SubscriptionCategory.monthly:
        if (int.tryParse(daysCtrl.text) == null ||
            int.tryParse(daysCtrl.text)! <= 0) {
          daysCtrl.text = category == SubscriptionCategory.weekly ? '6' : '26';
        }
        break;
    }
  }

  String? _validateNumber(String? value, {bool positive = true}) {
    if (value == null || value.trim().isEmpty) {
      return 'إلزامي';
    }
    final num? parsed = num.tryParse(value);
    if (parsed == null) {
      return 'قيمة رقمية';
    }
    if (positive && parsed <= 0) {
      return 'يجب أن تكون موجبة';
    }
    return null;
  }

  String? _validateDays(String? value) {
    final parsed = int.tryParse(value ?? '');
    switch (category) {
      case SubscriptionCategory.hours:
        if (parsed != 0) return 'قيمة الأيام يجب أن تكون 0';
        break;
      case SubscriptionCategory.daily:
        if (parsed != 1) return 'قيمة الأيام يجب أن تكون 1';
        break;
      case SubscriptionCategory.weekly:
      case SubscriptionCategory.monthly:
        if (parsed == null || parsed <= 0) {
          return 'أدخل عدد أيام أكبر من 0';
        }
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة خطة' : 'تعديل خطة'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الخطة'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'إلزامي' : null,
                ),
                DropdownButtonFormField<SubscriptionCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'الفئة'),
                  items: [
                    for (final c in allSubscriptionCategories)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ),
                  ],
                  onChanged: (c) {
                    if (c == null) return;
                    setState(() {
                      category = c;
                      _enforceDaysForCategory();
                    });
                  },
                ),
                TextFormField(
                  controller: bandwidthCtrl,
                  decoration: const InputDecoration(labelText: 'السرعة (Mbps)'),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  validator: (v) => _validateNumber(v),
                ),
                TextFormField(
                  controller: daysCtrl,
                  enabled: category == SubscriptionCategory.weekly ||
                      category == SubscriptionCategory.monthly,
                  decoration: const InputDecoration(labelText: 'عدد الأيام'),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  validator: _validateDays,
                ),
                TextFormField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'السعر (₪)'),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  validator: (v) => _validateNumber(v),
                ),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                  title: const Text('مُفعل'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              final bandwidth = int.tryParse(bandwidthCtrl.text.trim()) ?? 0;
              final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
              final price = num.parse(priceCtrl.text.trim());
              final plan = Plan(
                id: widget.initial?.id ?? '',
                title: titleCtrl.text.trim(),
                category: category,
                bandwidthMbps: bandwidth,
                daysCount: days,
                price: price,
                active: active,
                createdAt: widget.initial?.createdAt,
                updatedAt: widget.initial?.updatedAt,
              );
              Navigator.pop(context, plan);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}