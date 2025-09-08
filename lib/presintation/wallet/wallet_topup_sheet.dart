import 'package:flutter/material.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/wallet_repo.dart';

class WalletTopUpSheet extends StatefulWidget {
  final Member member;
  const WalletTopUpSheet({super.key, required this.member});

  @override
  State<WalletTopUpSheet> createState() => _WalletTopUpSheetState();
}

class _WalletTopUpSheetState extends State<WalletTopUpSheet> {
  final wallet = WalletRepo();
  final ctrl = TextEditingController();
  final noteCtrl = TextEditingController();
  bool loading = false;

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
              Text('شحن — ${widget.member.name}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // المبلغ
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

              const SizedBox(height: 8),

              // ملاحظة اختيارية
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),

              const SizedBox(height: 12),

              // أزرار الإجراءات
              Row(
                children: [
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(context, null),
                    child: const Text('إلغاء'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                      final v = num.tryParse(ctrl.text.trim());
                      if (v == null || v <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text('أدخل مبلغًا موجبًا (₪)')),
                        );
                        return;
                      }
                      setState(() => loading = true);
                      await wallet.topUp(
                        memberId: widget.member.id,
                        amount: v,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                      if (mounted) Navigator.pop(context, v);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('شحن'),
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
