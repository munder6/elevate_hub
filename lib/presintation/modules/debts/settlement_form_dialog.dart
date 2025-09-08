import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettlementFormDialog extends StatefulWidget {
  final num maxAmount; // قيمة الدين/الحد الأقصى للدفع
  const SettlementFormDialog({super.key, required this.maxAmount});

  @override
  State<SettlementFormDialog> createState() => _SettlementFormDialogState();
}

class _SettlementFormDialogState extends State<SettlementFormDialog> {
  final _form = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();

  String _sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة دفعة'),
        content: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // معلومة عن الحد الأقصى
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'إجمالي الدين: ${_sCurrency(widget.maxAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: amountCtrl,
                textDirection: TextDirection.ltr, // أرقام من اليسار لليمين
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'قيمة الدفعة',
                  hintText: 'مثال: 25.50',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final raw = (v ?? '').trim();
                  if (raw.isEmpty) return 'أدخل قيمة';
                  final n = num.tryParse(raw);
                  if (n == null) return 'أدخل رقمًا صالحًا';
                  if (n <= 0) return 'المبلغ يجب أن يكون أكبر من 0';
                  if (n > widget.maxAmount) {
                    return 'يتجاوز الحد (${_sCurrency(widget.maxAmount)})';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!(_form.currentState?.validate() ?? false)) return;
              final n = num.parse(amountCtrl.text.trim());
              Navigator.pop<num>(context, n);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
