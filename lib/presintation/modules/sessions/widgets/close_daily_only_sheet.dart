import 'package:flutter/material.dart';

class CloseDailyOnlySheet extends StatefulWidget {
  final num basePrice;
  final num drinksTotal;
  final num initialDiscount;
  const CloseDailyOnlySheet({
    super.key,
    required this.basePrice,
    required this.drinksTotal,
    this.initialDiscount = 0,
  });

  @override
  State<CloseDailyOnlySheet> createState() => _CloseDailyOnlySheetState();
}

class _CloseDailyOnlySheetState extends State<CloseDailyOnlySheet> {
  String _paymentMethod = 'cash';
  late final TextEditingController _discountCtrl;

  static const _methods = <_MethodOption>[
    _MethodOption('cash', 'كاش'),
    _MethodOption('app', 'تطبيق'),
    _MethodOption('unpaid', 'غير مدفوع'),
    _MethodOption('card', 'بطاقة'),
    _MethodOption('other', 'أخرى'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDiscount;
    _discountCtrl = TextEditingController(
      text: initial > 0 ? initial.toString() : '',
    );
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  num get _discount {
    final raw = _discountCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return 0;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed.isNaN) return 0;
    return parsed < 0 ? 0 : parsed;
  }

  num get _grandTotal {
    final total = widget.basePrice + widget.drinksTotal - _discount;
    return total < 0 ? 0 : total;
  }

  void _submit() {
    Navigator.pop(context, {
      'paymentMethod': _paymentMethod,
      'discount': _discount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('إغلاق الاشتراك اليومي', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Text('طريقة الدفع', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _methods
                    .map(
                      (m) => ChoiceChip(
                    label: Text(m.label),
                    selected: _paymentMethod == m.value,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _paymentMethod = m.value);
                    },
                  ),
                )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text('الخصم', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  prefixText: '₪ ',
                  border: OutlineInputBorder(),
                  hintText: '0',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ملخص الفاتورة',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _summaryRow('سعر اليوم', _currency(widget.basePrice)),
                      _summaryRow('المشروبات/الخدمات', _currency(widget.drinksTotal)),
                      _summaryRow('الخصم', '- ${_currency(_discount)}'),
                      const Divider(),
                      _summaryRow('الإجمالي', _currency(_grandTotal), isStrong: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تأكيد الإغلاق'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style:
            isStrong ? const TextStyle(fontWeight: FontWeight.w800) : null,
          ),
        ],
      ),
    );
  }

  String _currency(num value) => '₪${value.toStringAsFixed(2)}';
}

class _MethodOption {
  final String value;
  final String label;
  const _MethodOption(this.value, this.label);
}