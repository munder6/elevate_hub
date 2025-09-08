import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/repositories/members_repo.dart';
import '../../../data/repositories/balance_repo.dart';
import 'top_up_dialog.dart';

class MemberDetailView extends StatelessWidget {
  final String memberId;
  MemberDetailView({super.key, required this.memberId});

  final membersRepo = MembersRepo();
  final balanceRepo = BalanceRepo();

  @override
  Widget build(BuildContext context) {
    return Directionality( // ✅ RTL لكل الصفحة
      textDirection: TextDirection.rtl,
      child: StreamBuilder<Member?>(
        stream: membersRepo.watchOne(memberId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('العضو')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final m = snap.data!;
          return Scaffold(
            appBar: AppBar(
              title: Text(m.name),
              actions: [
                StreamBuilder<num>(
                  stream: balanceRepo.watchBalance(memberId),
                  builder: (_, bSnap) {
                    final bal = (bSnap.data ?? m.balance).toStringAsFixed(2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 18),
                            const SizedBox(width: 6),
                            Row(
                              children: [
                                const Text('الرصيد:'),
                                const SizedBox(width: 4),
                                // إبقاء الأرقام بصيغة LTR لعرض العملة والرقم بشكل صحيح
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text('₪$bal'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'شحن الرصيد',
                  onPressed: () async {
                    final amount = await showDialog<num?>(
                      context: context,
                      builder: (_) => const TopUpDialog(),
                    );
                    if (amount != null && amount > 0) {
                      await balanceRepo.addCreditTopUp(memberId: memberId, amount: amount);
                      if (context.mounted) {
                        final a = amount.toStringAsFixed(2);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text('تم شحن ₪$a'),
                          )),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_card_outlined),
                ),
              ],
            ),
            body: StreamBuilder(
              stream: balanceRepo.watchTxByMember(memberId),
              builder: (context, txSnap) {
                final list = txSnap.data ?? const [];
                if (list.isEmpty) {
                  return const Center(child: Text('لا توجد حركات رصيد بعد'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final sign = t.type == 'credit'
                        ? '+'
                        : t.type == 'debit'
                        ? '-'
                        : '±';
                    final color = t.type == 'credit'
                        ? Colors.green
                        : t.type == 'debit'
                        ? Colors.red
                        : Colors.blueGrey;
                    final ref = (t.refType != null && t.refId != null)
                        ? ' (${t.refType}:${t.refId})'
                        : '';
                    final amountStr = t.amount is num
                        ? (t.amount as num).toStringAsFixed(2)
                        : t.amount.toString();
                    return ListTile(
                      leading: Icon(
                        t.type == 'credit'
                            ? Icons.arrow_downward_rounded
                            : t.type == 'debit'
                            ? Icons.arrow_upward_rounded
                            : Icons.tune_rounded,
                        color: color,
                      ),
                      title: Directionality(
                        textDirection: TextDirection.ltr, // لعرض الرمز والرقم بالترتيب
                        child: Text('$sign₪$amountStr'),
                      ),
                      subtitle: Text('${t.reason ?? '-'}$ref'),
                      trailing: Directionality(
                        textDirection: TextDirection.ltr, // التاريخ بصيغة يسار-يمين
                        child: Text(
                          t.createdAt.toString().substring(0, 16),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
