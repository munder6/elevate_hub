import 'package:flutter/material.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/wallet_repo.dart';
import '../../../data/services/firestore_service.dart';
import 'wallet_topup_sheet.dart';

class MemberWalletSheet extends StatelessWidget {
  final Member member;
  MemberWalletSheet({super.key, required this.member});

  final wallet = WalletRepo();
  final fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
              Text('المحفظة — ${member.name}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),

              // الرصيد
              StreamBuilder<num>(
                stream: wallet.watchBalance(member.id),
                builder: (_, snap) {
                  final bal = snap.data ?? 0;
                  final color = bal >= 0 ? Colors.green : theme.colorScheme.error;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, color: color),
                        const SizedBox(width: 12),
                        const Text('الرصيد:'),
                        const Spacer(),
                        Text(
                          '₪ ${bal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // أزرار الشحن والخصم
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final amount = await showModalBottomSheet<num?>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => WalletTopUpSheet(member: member),
                      );
                      if (amount != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم شحن ₪ ${amount.toStringAsFixed(2)}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('شحن'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      // خصم يدوي (مرة واحدة)
                      final ctrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: AlertDialog(
                            title: const Text('خصم يدوي'),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'المبلغ المراد خصمه (₪)',
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('خصم'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (ok == true) {
                        final v = num.tryParse(ctrl.text.trim()) ?? 0;
                        if (v > 0) {
                          final refId = fs.col('wallet_tx').doc().id;
                          final result = await wallet.chargeAmountAllowNegative(
                            memberId: member.id,
                            cost: v,
                            reason: 'Manual deduction',
                            refType: 'manual',
                            refId: refId,
                          );
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text(
                                 'الرصيد الجديد: ₪ ${result.postBalance.toStringAsFixed(2)}، الدين: ₪ ${result.debtCreated.toStringAsFixed(2)}',
                               ),
                               ),
                               );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.remove),
                    label: const Text('خصم'),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text('السجل', style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 6),

              // سجل الحركات من wallet_tx
              SizedBox(
                height: 260,
                child: StreamBuilder(
                  stream: fs
                      .col('wallet_tx')
                      .where('memberId', isEqualTo: member.id)
                      .orderBy('at', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('لا توجد أي حركات بعد'));
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final m = docs[i].data();
                        final type = (m['type'] ?? '') as String; // topup | charge
                        final amount = (m['amount'] ?? 0) as num;
                        final at = (m['at'] ?? '') as String;
                        final note = (m['note'] ?? '') as String?;
                        final refType = (m['refType'] ?? '') as String?;
                        final refId = (m['refId'] ?? '') as String?;

                        final isTopUp = type == 'topup';
                        final color = isTopUp ? Colors.green : Theme.of(context).colorScheme.error;

                        final abs = amount.abs().toStringAsFixed(2);
                        final trailing = isTopUp ? '+₪ $abs' : '-₪ $abs';

                        final subtitle = [
                          if (note != null && note.isNotEmpty) 'ملاحظة: $note',
                          if ((refType ?? '').isNotEmpty && (refId ?? '').isNotEmpty) 'مرجع: $refType:$refId',
                          at.toString(),
                        ].where((e) => e.isNotEmpty).join('  •  ');

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isTopUp ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: color,
                          ),
                          title: Text(isTopUp ? 'شحن' : 'خصم'),
                          subtitle: Text(subtitle),
                          trailing: Text(
                            trailing,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
