import 'package:flutter/material.dart';

class TopUpDialog extends StatefulWidget {
  const TopUpDialog({super.key});
  @override
  State<TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<TopUpDialog> {
  final c = TextEditingController();
  String? err;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // ✅ من اليمين لليسار
      child: AlertDialog(
        title: const Text('شحن الرصيد'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr, // الأرقام تُكتب من اليسار لليمين
          decoration: InputDecoration(
            labelText: 'المبلغ',
            hintText: 'مثال: 50.0',
            prefixText: '₪ ',
            errorText: err,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = num.tryParse(c.text.trim());
              if (v == null || v <= 0) {
                setState(() => err = 'أدخل رقمًا موجبًا');
                return;
              }
              Navigator.pop<num>(context, v);
            },
            child: const Text('شحن'),
          ),
        ],
      ),
    );
  }
}
