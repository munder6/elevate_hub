import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebtPaymentDialog extends StatefulWidget {
  final num maxAmount;
  const DebtPaymentDialog({super.key, required this.maxAmount});

  @override
  State<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final ctrl = TextEditingController();
  String? err;

  num get _value {
    final t = ctrl.text.trim().replaceAll(',', '.');
    return num.tryParse(t) ?? 0;
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _setQuick(num v) {
    ctrl.text = v.toStringAsFixed(2);
    _validate();
  }

  void _validate() {
    final v = _value;
    setState(() {
      if (v <= 0) {
        err = 'أدخل مبلغاً أكبر من 0';
      } else if (v > widget.maxAmount) {
        err = 'القيمة تتجاوز المستحق (${widget.maxAmount.toStringAsFixed(2)})';
      } else {
        err = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.maxAmount;
    final remain = (max - _value).clamp(0, max).toStringAsFixed(2);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة دفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              onChanged: (_) => _validate(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'المبلغ (حتى ₪ ${max.toStringAsFixed(2)})',
                prefixIcon: const Icon(Icons.payments_outlined),
                prefixText: '₪ ',
                errorText: err,
                helperText: err == null ? 'المتبقي بعد الدفع: ₪ $remain' : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setQuick((max * .25)),
                    child: const Text('25%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setQuick((max * .5)),
                    child: const Text('50%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setQuick(max),
                    child: const Text('الكل'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              _validate();
              if (err != null) return;
              Navigator.pop<num>(context, _value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
