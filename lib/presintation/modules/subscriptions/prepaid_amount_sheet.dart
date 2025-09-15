import 'package:flutter/material.dart';
import '../../../data/models/member.dart';

class PrepaidAmountSheet extends StatefulWidget {
  final Member member;
  const PrepaidAmountSheet({super.key, required this.member});

  @override
  State<PrepaidAmountSheet> createState() => _PrepaidAmountSheetState();
}

class _PrepaidAmountSheetState extends State<PrepaidAmountSheet> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text('المبلغ المقدم — ${widget.member.name}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (₪)',
                  prefixText: '₪ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('إلغاء'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      final v = num.tryParse(ctrl.text.trim());
                      if (v == null || v <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('أدخل مبلغًا موجبًا (₪)')),
                        );
                        return;
                      }
                      Navigator.pop(context, v);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('اعتماد'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}