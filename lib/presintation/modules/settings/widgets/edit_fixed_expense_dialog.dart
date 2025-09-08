import 'package:flutter/material.dart';
import '../../../../data/models/app_settings.dart';

class EditFixedExpenseDialog extends StatefulWidget {
  final FixedExpenseItem? initial;
  const EditFixedExpenseDialog({super.key, this.initial});

  @override
  State<EditFixedExpenseDialog> createState() => _EditFixedExpenseDialogState();
}

class _EditFixedExpenseDialogState extends State<EditFixedExpenseDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController amount;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?.name ?? '');
    amount = TextEditingController(text: (widget.initial?.amount ?? 0).toString());
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Fixed Expense' : 'Edit Fixed Expense'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (v) => (num.tryParse(v ?? '') == null) ? 'Number' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop<FixedExpenseItem>(
              context,
              FixedExpenseItem(name: name.text.trim(), amount: num.parse(amount.text)),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
