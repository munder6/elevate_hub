import 'package:flutter/material.dart';

class ClosePayResult {
  final bool paid;
  final String? method; // cash | app | other
  const ClosePayResult({required this.paid, this.method});
}

class ClosePayDialog extends StatefulWidget {
  const ClosePayDialog({super.key});

  @override
  State<ClosePayDialog> createState() => _ClosePayDialogState();
}

class _ClosePayDialogState extends State<ClosePayDialog> {
  bool paid = true;
  String method = 'cash';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Close & settle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Are orders paid?'),
            value: paid,
            onChanged: (v) => setState(() => paid = v),
          ),
          if (paid)
            DropdownButtonFormField<String>(
              value: method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'app', child: Text('App')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => method = v ?? 'cash'),
              decoration: const InputDecoration(labelText: 'Payment method'),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, ClosePayResult(paid: paid, method: paid ? method : null)),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
