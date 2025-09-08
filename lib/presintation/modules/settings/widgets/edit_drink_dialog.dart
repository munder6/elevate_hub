import 'package:flutter/material.dart';
import '../../../../data/models/app_settings.dart';

class EditDrinkDialog extends StatefulWidget {
  final DrinkItem? initial;
  const EditDrinkDialog({super.key, this.initial});

  @override
  State<EditDrinkDialog> createState() => _EditDrinkDialogState();
}

class _EditDrinkDialogState extends State<EditDrinkDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController price;
  bool active = true;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?.name ?? '');
    price = TextEditingController(text: (widget.initial?.price ?? 0).toString());
    active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Drink' : 'Edit Drink'),
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
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
              validator: (v) => (num.tryParse(v ?? '') == null) ? 'Number' : null,
            ),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Active'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop<DrinkItem>(
              context,
              DrinkItem(name: name.text.trim(), price: num.parse(price.text), active: active),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
