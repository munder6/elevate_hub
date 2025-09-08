import 'package:flutter/material.dart';

class StockMovementForm extends StatefulWidget {
  final String invId;
  const StockMovementForm({super.key, required this.invId});

  @override
  State<StockMovementForm> createState() => _StockMovementFormState();
}

class _StockMovementFormState extends State<StockMovementForm> {
  final _form = GlobalKey<FormState>();
  String type = 'in';
  final qty = TextEditingController(text: '1');
  final reason = TextEditingController();
  @override
  void dispose() { qty.dispose(); reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New stock movement'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'in', child: Text('IN (increase)')),
                DropdownMenuItem(value: 'out', child: Text('OUT (decrease)')),
                DropdownMenuItem(value: 'adjust', child: Text('ADJUST (set exact)')),
              ],
              onChanged: (v)=> setState(()=> type = v ?? 'in'),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: qty,
              decoration: InputDecoration(labelText: type=='adjust' ? 'New stock value' : 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (v)=> (num.tryParse(v ?? '') == null) ? 'Number' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: (){
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.pop<Map<String,dynamic>>(context, {
              'type': type,
              'qty': num.parse(qty.text),
              'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
