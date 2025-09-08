import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/debt.dart';
import '../../../data/repositories/members_repo.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/debts_repo.dart';
import '../../routes/app_routes.dart';
import 'debt_payment_dialog.dart';

class DebtsListView extends StatefulWidget {
  final String? memberId; // اختياري: لتصفية ديون عضو محدد
  const DebtsListView({super.key, this.memberId});

  @override
  State<DebtsListView> createState() => _DebtsListViewState();
}

class _DebtsListViewState extends State<DebtsListView> {
  final usersRepo = UsersRepo();
  final repo = DebtsRepo();

  String _sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

  Future<void> _createDebt(BuildContext context) async {
    final amount = await showDialog<num>(
      context: context,
      builder: (_) => const DebtPaymentDialog(maxAmount: 999999),
    );
    if (amount != null && amount > 0 && widget.memberId != null) {
      final mRepo = MembersRepo();
      final name = await mRepo.getMemberName(widget.memberId!);
      await repo.createDebt(
        memberId: widget.memberId!,
        memberName: name ?? '',
        amount: amount,
        reason: 'دين يدوي',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          floatingActionButton: widget.memberId == null
              ? null
              : FloatingActionButton.extended(
            onPressed: () => _createDebt(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة دين'),
          ),
          body: StreamBuilder<AppUser?>(
            stream: usersRepo.watchMe(),
            builder: (context, meSnap) {
              if (!meSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final me = meSnap.data!;
              if (!(me.perms.debts || me.perms.isAdmin)) {
                Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
                return const SizedBox.shrink();
              }

              return NestedScrollView(
                headerSliverBuilder: (context, innerScrolled) => [
                  // AppBar شفاف + Blur + تبويبات
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
                        Icon(Icons.request_page_rounded,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        const Text('الديون'),
                      ],
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(.35),
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(.35),
                            ),
                          ),
                        ),
                        child: const TabBar(
                          isScrollable: true,
                          labelPadding:
                          EdgeInsets.symmetric(horizontal: 14),
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: [
                            Tab(text: 'مفتوحة'),
                            Tab(text: 'مُسدّدة'),
                            Tab(text: 'الكل'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _DebtsTab(
                      repo: repo,
                      status: 'open',
                      memberId: widget.memberId,
                      sCurrency: _sCurrency,
                    ),
                    _DebtsTab(
                      repo: repo,
                      status: 'settled',
                      memberId: widget.memberId,
                      sCurrency: _sCurrency,
                    ),
                    _DebtsTab(
                      repo: repo,
                      status: null,
                      memberId: widget.memberId,
                      sCurrency: _sCurrency,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ============================ تبويب واحد ============================ */

class _DebtsTab extends StatelessWidget {
  final DebtsRepo repo;
  final String? status; // 'open' | 'settled' | null
  final String? memberId;
  final String Function(num) sCurrency;

  const _DebtsTab({
    required this.repo,
    required this.status,
    required this.memberId,
    required this.sCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = memberId == null
        ? repo.watchAll(status: status)
        : repo.watchByMember(memberId!, status: status);

    return StreamBuilder<List<Debt>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final debts = snap.data!;
        if (debts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                const Text('لا توجد ديون'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: debts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = debts[i];
            final payments = d.payments ?? const [];
            final paid = payments.fold<num>(
                0, (s, p) => s + ((p['amount'] as num?) ?? 0));
            final due = (d.amount ?? 0) - paid;

            return _DebtTileCard(
              debt: d,
              paid: paid,
              due: due,
              sCurrency: sCurrency,
              onAddPayment: (due > 0 && (d.status ?? 'open') == 'open')
                  ? () async {
                final v = await showDialog<num>(
                  context: context,
                  builder: (_) => DebtPaymentDialog(
                    maxAmount: due > 0 ? due : 0,
                  ),
                );
                if (v != null && v > 0) {
                  await repo.addPayment(debtId: d.id!, amount: v);
                }
              }
                  : null,
              onSettle: (d.status ?? 'open') == 'open'
                  ? () async => repo.settleAll(d.id!)
                  : null,
              onDelete: () async => repo.delete(d.id!),
            );
          },
        );
      },
    );
  }
}

/* ============================ بطاقة الدين ============================ */

class _DebtTileCard extends StatelessWidget {
  final Debt debt;
  final num paid;
  final num due;
  final String Function(num) sCurrency;
  final VoidCallback? onAddPayment;
  final VoidCallback? onSettle;
  final VoidCallback onDelete;

  const _DebtTileCard({
    required this.debt,
    required this.paid,
    required this.due,
    required this.sCurrency,
    required this.onAddPayment,
    required this.onSettle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color c1 = theme.colorScheme.primary.withOpacity(.06);
    final Color c2 = theme.colorScheme.secondaryContainer.withOpacity(.14);
    final Color border = theme.colorScheme.outlineVariant.withOpacity(.45);
    final Color title = theme.colorScheme.onSurface.withOpacity(.92);
    final Color iconBg = theme.colorScheme.primary.withOpacity(.12);

    final status = (debt.status ?? 'open').toLowerCase();
    final bool isOpen = status == 'open';

    final Color statusColor = isOpen ? theme.colorScheme.primary : Colors.teal;
    final Color statusBg = statusColor.withOpacity(.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // السطر العلوي
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.account_balance_wallet_outlined,
                          size: 24, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),

                    // الاسم + تفاصيل مالية (كل واحدة بسطر)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.memberName?.isNotEmpty == true
                                ? debt.memberName!
                                : '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: title,
                              letterSpacing: .2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _kv(context, 'المبلغ', sCurrency(debt.amount ?? 0)),
                          _kv(context, 'المدفوع', sCurrency(paid)),
                          _kv(context, 'المتبقي', sCurrency(due)),
                          if ((debt.reason ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _pill(
                                context,
                                icon: Icons.info_outline_rounded,
                                label: debt.reason!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // شِيب حالة
                Align(
                  alignment: Alignment.centerRight,
                  child: _pill(
                    context,
                    icon: isOpen
                        ? Icons.schedule_rounded
                        : Icons.verified_rounded,
                    label: isOpen ? 'مفتوحة' : 'مُسدّدة',
                    fg: statusColor,
                    bg: statusBg,
                  ),
                ),

                const SizedBox(height: 10),

                // أزرار الإجراءات (تلتف تلقائيًا — ما في Overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (onAddPayment != null)
                      _actionBtn(
                        context,
                        icon: Icons.payments_outlined,
                        label: 'إضافة دفعة',
                        onTap: onAddPayment!,
                      ),
                    if (onSettle != null)
                      _actionBtn(
                        context,
                        icon: Icons.done_all_outlined,
                        label: 'تسديد الكل',
                        onTap: onSettle!,
                      ),
                    _actionBtn(
                      context,
                      icon: Icons.delete_outline,
                      label: 'حذف',
                      onTap: onDelete,
                      danger: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // زوج (مفتاح - قيمة) بدون تداخل
  Widget _kv(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(k, style: theme.textTheme.bodyMedium)),
        Text(
          v,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  // كبسولة معلومات عامة
  Widget _pill(BuildContext context,
      {required IconData icon, required String label, Color? fg, Color? bg}) {
    final theme = Theme.of(context);
    final Color textColor = fg ?? theme.colorScheme.onSurface.withOpacity(.85);
    final Color backColor = bg ?? theme.colorScheme.surfaceVariant.withOpacity(.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: backColor,
        border: Border.all(
          color: (fg ?? theme.colorScheme.outlineVariant).withOpacity(.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  // زر إجراء صغير متّسق
  Widget _actionBtn(BuildContext context,
      {required IconData icon,
        required String label,
        required VoidCallback onTap,
        bool danger = false}) {
    final theme = Theme.of(context);
    final Color fg = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withOpacity(.85);
    final Color bg = danger
        ? theme.colorScheme.error.withOpacity(.10)
        : theme.colorScheme.surfaceVariant.withOpacity(.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (danger
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant)
                .withOpacity(.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
