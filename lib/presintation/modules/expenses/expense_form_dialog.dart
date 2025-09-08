import 'package:flutter/material.dart';

class ExpenseFormDialog extends StatefulWidget {
  final bool fixedMonthly;
  const ExpenseFormDialog({super.key, this.fixedMonthly = false});

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _form = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  DateTime? month; // للثابتة

  @override
  void dispose() {
    amountCtrl.dispose();
    categoryCtrl.dispose();
    reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: month ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(() => month = DateTime(d.year, d.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.fixedMonthly ? 'Add fixed monthly expense' : 'Add expense'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (v) => (num.tryParse(v ?? '') == null) ? 'Number' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason (optional)'),
              ),
              if (widget.fixedMonthly) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(month == null
                          ? 'Month: (current)'
                          : 'Month: ${month!.year}-${month!.month.toString().padLeft(2, '0')}'),
                    ),
                    TextButton(onPressed: _pickMonth, child: const Text('Pick month')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop<Map<String, dynamic>>(context, {
              'amount': num.parse(amountCtrl.text),
              'category': categoryCtrl.text.trim(),
              'reason': reasonCtrl.text.trim(),
              'month': month,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
