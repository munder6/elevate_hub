import 'package:flutter/material.dart';
import '../../../data/models/asset.dart';

class AssetFormDialog extends StatefulWidget {
  final AssetModel? initial;
  const AssetFormDialog({super.key, this.initial});

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController();
  final category = TextEditingController();
  DateTime? purchaseDate;
  final valueCtrl = TextEditingController(text: '0');
  final notes = TextEditingController();
  bool active = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      name.text = i.name;
      category.text = i.category ?? '';
      purchaseDate = i.purchaseDate;
      valueCtrl.text = i.value.toString();
      notes.text = i.notes ?? '';
      active = i.active;
    }
  }

  @override
  void dispose() {
    name..dispose();
    category..dispose();
    valueCtrl..dispose();
    notes..dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: purchaseDate ?? now,
    );
    if (d != null) setState(() => purchaseDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add asset' : 'Edit asset'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category (optional)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      purchaseDate == null
                          ? 'Purchase date: —'
                          : 'Purchase date: ${purchaseDate!.toIso8601String().substring(0,10)}',
                    ),
                  ),
                  TextButton(onPressed: _pickDate, child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: valueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Value'),
                validator: (v) => num.tryParse(v ?? '') == null ? 'Number' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            final m = AssetModel(
              id: widget.initial?.id ?? '',
              name: name.text.trim(),
              category: category.text.trim().isEmpty ? null : category.text.trim(),
              purchaseDate: purchaseDate,
              value: num.parse(valueCtrl.text.trim()),
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              active: active,
            );
            Navigator.pop<AssetModel>(context, m);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
