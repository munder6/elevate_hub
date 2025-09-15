import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/repositories/members_repo.dart';
import '../../../data/repositories/wallet_repo.dart';
import '../../../data/services/firestore_service.dart';
import 'top_up_dialog.dart';

class MemberDetailView extends StatelessWidget {
  final String memberId;
  MemberDetailView({super.key, required this.memberId});

  final membersRepo = MembersRepo();
  final wallet = WalletRepo();
  final fs = FirestoreService();

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
                  stream: wallet.watchBalance(memberId),
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
                      await wallet.topUp(memberId: memberId, amount: amount);
                      if (context.mounted) {
                        final a = amount.toStringAsFixed(2);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text('تم شحن ₪$a'),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_card_outlined),
                ),
              ],
            ),
            body: StreamBuilder(
              stream: fs
                  .col('wallet_tx')
                  .where('memberId', isEqualTo: memberId)
                  .orderBy('at', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, txSnap) {
                final list = txSnap.data ?? const [];
                if (!txSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = txSnap.data!.docs;
                if (docs.isEmpty) {
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final m = docs[i].data();
                    final type = (m['type'] ?? '') as String;
                    final amount = (m['amount'] ?? 0) as num;
                    final note = m['note'] as String?;
                    final refType = m['refType'] as String?;
                    final refId = m['refId'] as String?;
                    final at = (m['at'] ?? '') as String;

                    final isTopUp = type == 'topup';
                    final sign = isTopUp ? '+' : '-';
                    final color = isTopUp ? Colors.green : Colors.red;
                    final ref = (refType != null &&
                        refId != null &&
                        refType.isNotEmpty &&
                        refId.isNotEmpty)
                        ? ' ($refType:$refId)'
                        : '';
                    final amountStr = amount.abs().toStringAsFixed(2);
                    return ListTile(
                      leading: Icon(
                        isTopUp
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: color,
                      ),
                      title: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text('$sign₪$amountStr'),
                      ),
                      subtitle: Text('${note ?? '-'}$ref'),
                      trailing: Directionality(
                        textDirection: TextDirection.ltr, // التاريخ بصيغة يسار-يمين
                        child: Text(
                          at.toString().substring(0, 16),
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
