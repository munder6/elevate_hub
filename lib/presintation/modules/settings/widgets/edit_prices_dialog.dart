import 'package:flutter/material.dart';

class EditPricesDialog extends StatefulWidget {
  final num hourly;
  final num weekly;
  final num monthly;
  const EditPricesDialog({
    super.key,
    required this.hourly,
    required this.weekly,
    required this.monthly,
  });

  @override
  State<EditPricesDialog> createState() => _EditPricesDialogState();
}

class _EditPricesDialogState extends State<EditPricesDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController hourly;
  late TextEditingController weekly;
  late TextEditingController monthly;

  @override
  void initState() {
    super.initState();
    hourly = TextEditingController(text: widget.hourly.toString());
    weekly = TextEditingController(text: widget.weekly.toString());
    monthly = TextEditingController(text: widget.monthly.toString());
  }

  @override
  void dispose() {
    hourly.dispose();
    weekly.dispose();
    monthly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Prices'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: hourly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hourly'),
              validator: (v) => (num.tryParse(v ?? '') == null) ? 'Number' : null,
            ),
            TextFormField(
              controller: weekly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weekly'),
              validator: (v) => (num.tryParse(v ?? '') == null) ? 'Number' : null,
            ),
            TextFormField(
              controller: monthly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly'),
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
            Navigator.pop<Map<String, num>>(context, {
              'hourly': num.parse(hourly.text),
              'weekly': num.parse(weekly.text),
              'monthly': num.parse(monthly.text),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
