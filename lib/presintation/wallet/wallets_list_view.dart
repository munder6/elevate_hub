import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/members_repo.dart';
import '../../../data/repositories/wallet_repo.dart';
import '../../../data/models/member.dart';
import 'member_wallet_sheet.dart';

class WalletsListView extends StatefulWidget {
  const WalletsListView({super.key});

  @override
  State<WalletsListView> createState() => _WalletsListViewState();
}

class _WalletsListViewState extends State<WalletsListView> {
  final membersRepo = MembersRepo();
  final walletRepo = WalletRepo();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ===== AppBar شفاف + Blur =====
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              toolbarHeight: kToolbarHeight,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: theme.colorScheme.surface.withOpacity(0.55),
                  ),
                ),
              ),
              title: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.account_balance_wallet_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  const Text('المحافظ'),
                ],
              ),
            ),

            // ===== حقل البحث =====
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عضو…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(.55),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(.45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(.65),
                        width: 1.2,
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Divider(height: 0)),

            // ===== قائمة المحافظ =====
            SliverFillRemaining(
              child: StreamBuilder<List<Member>>(
                stream: membersRepo.watchAll(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var list = snap.data!;
                  if (_query.isNotEmpty) {
                    list = list
                        .where((m) =>
                    m.name.toLowerCase().contains(_query) ||
                        (m.phone ?? '').toLowerCase().contains(_query))
                        .toList();
                  }
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 56, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('لا يوجد أعضاء',
                              style: theme.textTheme.titleMedium),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final m = list[i];
                      return _WalletTileCard(
                        member: m,
                        balanceStream: walletRepo.watchBalance(m.id),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => MemberWalletSheet(member: m),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// كرت محفظة بنفس ستايل الداشبورد/الأعضاء
class _WalletTileCard extends StatelessWidget {
  final Member member;
  final Stream<num> balanceStream;
  final VoidCallback onTap;

  const _WalletTileCard({
    required this.member,
    required this.balanceStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color c1 = theme.colorScheme.primary.withOpacity(.06);
    final Color c2 = theme.colorScheme.secondaryContainer.withOpacity(.14);
    final Color border = theme.colorScheme.outlineVariant.withOpacity(.45);
    final Color title = theme.colorScheme.onSurface.withOpacity(.92);
    final Color iconBg = theme.colorScheme.primary.withOpacity(.12);
    final Color chevron = theme.colorScheme.onSurface.withOpacity(.55);

    // عرض ثابت للجزء الأيسر (الرصيد + السهم) لمنع تزاحم
    const double trailingWidth = 160;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // أيقونة
                Container(
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.person_rounded,
                      size: 24, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),

                // الاسم + الهاتف (chip)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: title,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (member.phone != null &&
                          member.phone!.trim().isNotEmpty)
                        _miniPill(
                          context,
                          icon: Icons.call_rounded,
                          label: member.phone!,
                          maxLabelWidth: 260,
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // الرصيد + السهم، بعرض ثابت
                SizedBox(
                  width: trailingWidth,
                  child: StreamBuilder<num>(
                    stream: balanceStream,
                    builder: (_, bs) {
                      final bal = bs.data ?? 0;
                      final isPos = bal >= 0;
                      final Color pillBg = (isPos
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error)
                          .withOpacity(.12);
                      final Color pillFg =
                      isPos ? theme.colorScheme.primary : theme.colorScheme.error;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // كبسولة الرصيد
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: pillFg.withOpacity(.35),
                              ),
                            ),
                            child: Text(
                              '₪ ${bal.toStringAsFixed(2)}',
                              textDirection: TextDirection.ltr,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: pillFg,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // في RTL نخليه سهم لليسار كـ "استعراض"
                          Icon(Icons.arrow_back_rounded,
                              size: 22, color: chevron),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Pill رفيعة للنصوص الثانوية (الهاتف)
  Widget _miniPill(BuildContext context,
      {required IconData icon, required String label, double? maxLabelWidth}) {
    final theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onSurface.withOpacity(.85);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceVariant.withOpacity(.55),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxLabelWidth ?? 260,
            ),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
