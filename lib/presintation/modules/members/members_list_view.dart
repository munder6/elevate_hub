import 'dart:ui' show ImageFilter; // للبلور
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/members_repo.dart';
import '../../routes/app_routes.dart';
import '../sessions/daily_only_sheet.dart';
import '../../wallet/member_wallet_sheet.dart';
import '../sessions/daily_session_view.dart';
import '../subscriptions/monthly_cycle_sheet.dart';
import '../subscriptions/weekly_cycle_sheet.dart';
import 'member_form_dialog.dart';

class MembersListView extends StatefulWidget {
  const MembersListView({super.key});

  @override
  State<MembersListView> createState() => _MembersListViewState();
}

class _MembersListViewState extends State<MembersListView> {
  final usersRepo = UsersRepo();
  final membersRepo = MembersRepo();
  late final Stream<AppUser?> _meStream;
  late final Stream<List<Member>> _membersStream;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _meStream = usersRepo.watchMe();
    _membersStream = membersRepo.watchAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Future<void> _goLogin() async {
      Future.microtask(() => Get.offAllNamed(AppRoutes.login));
    }

    String planLabel(String? p) {
      return switch (p) {
        'hour' => 'بالساعة',
        'daily' => 'يومي',
        'week' => 'أسبوعي',
        'month' => 'شهري',
        _ => '—',
      };
    }

    Future<void> _onTapMember(BuildContext context, Member m) async {
      switch (m.preferredPlan) {
        case 'hour':
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => DailySessionView(member: m),
          );
          break;
        case 'daily':
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => DailyOnlySheet(member: m),
          );
          break;
        case 'week':
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => WeeklyCycleSheet(member: m),
          );
          break;
        case 'month':
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => MonthlyCycleSheet(member: m),
          );
          break;
        default:
          await showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('بدء جلسة بالساعة'),
                    onTap: () async {
                      Navigator.pop(context);
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DailySessionView(member: m),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: const Text('بدء اشتراك يومي'),
                    onTap: () async {
                      Navigator.pop(context);
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DailyOnlySheet(member: m),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_view_week),
                    title: const Text('فتح لوحة الأسبوع'),
                    onTap: () async {
                      Navigator.pop(context);
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => WeeklyCycleSheet(member: m),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('فتح لوحة الشهر'),
                    onTap: () async {
                      Navigator.pop(context);
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => MonthlyCycleSheet(member: m),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
          break;
      }
    }

    Future<void> _openWallet(BuildContext context, Member m) async {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => MemberWalletSheet(member: m),
      );
    }

    Future<void> _editMember(BuildContext context, Member m) async {
      final edited = await showDialog<Member>(
        context: context,
        builder: (_) => MemberFormDialog(initial: m),
      );
      if (edited != null) {
        await membersRepo.update(edited.copyWith(id: m.id));
      }
    }

    Future<void> _deleteMember(BuildContext context, Member m) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف العضو'),
            content: Text(
                'سيتم حذف ${m.name} وجميع بياناته بما في ذلك المحفظة والديون. هل أنت متأكد؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ),
      );
      if (ok == true) {
        await membersRepo.delete(m.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حذف ${m.name}')),
          );
        }
      }
    }


    Future<void> _addMember(BuildContext context) async {
      final m = await showDialog<Member>(
        context: context,
        builder: (_) => const MemberFormDialog(),
      );
      if (m != null) await membersRepo.add(m);
    }

    return Directionality( // ✅ اجعل الصفحة من اليمين لليسار
      textDirection: TextDirection.rtl,
      child: Scaffold(
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            onPressed: () => _addMember(ctx),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('إضافة'),
          ),
        ),
        body: StreamBuilder<AppUser?>(
          stream: _meStream,
          builder: (context, meSnap) {
            if (meSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final me = meSnap.data;
            if (me == null) {
              _goLogin();
              return const SizedBox.shrink();
            }
            if (me.perms.sessions != true) {
              Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
              return const SizedBox.shrink();
            }

            return StreamBuilder<List<Member>>(
              stream: _membersStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var members = snap.data!;
                if (_query.isNotEmpty) {
                  members = members
                      .where((m) =>
                  m.name.toLowerCase().contains(_query) ||
                      (m.phone ?? '').toLowerCase().contains(_query))
                      .toList();
                }

                return CustomScrollView(
                  slivers: [
                    // AppBar شفاف + Blur
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
                          Icon(Icons.group_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          const Text('الأعضاء'),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن عضو…',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor:
                            theme.colorScheme.surfaceVariant.withOpacity(.55),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withOpacity(.45),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color:
                                theme.colorScheme.primary.withOpacity(.65),
                                width: 1.2,
                              ),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 0)),

                    if (members.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_2_rounded,
                                  size: 56, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Text('لا يوجد أعضاء بعد',
                                  style: theme.textTheme.titleMedium),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 92),
                        sliver: SliverList.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final m = members[i];
                            return _MemberTileCard(
                              member: m,
                              planText: planLabel(m.preferredPlan),
                              onTap: () => _onTapMember(context, m),
                              onOpenWallet: () => _openWallet(context, m),
                              onEdit: () => _editMember(context, m),
                              onDelete: () => _deleteMember(context, m),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// كرت أفقي ديناميكي الارتفاع (ما في overflow) + توزيع ثابت للأزرار
class _MemberTileCard extends StatefulWidget {
  final Member member;
  final String planText;
  final VoidCallback onTap;
  final VoidCallback onOpenWallet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberTileCard({
    required this.member,
    required this.planText,
    required this.onTap,
    required this.onOpenWallet,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MemberTileCard> createState() => _MemberTileCardState();
}

class _MemberTileCardState extends State<_MemberTileCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color c1 = theme.colorScheme.primary.withOpacity(.06);
    final Color c2 = theme.colorScheme.secondaryContainer.withOpacity(.14);
    final Color border = theme.colorScheme.outlineVariant.withOpacity(.45);
    final Color title = theme.colorScheme.onSurface.withOpacity(.92);
    final Color iconBg = theme.colorScheme.primary.withOpacity(.12);
    final Color chevron = theme.colorScheme.onSurface.withOpacity(.55);

    // عرض ثابت للأزرار يمين حتى ما تزاحم المحتوى
    const double trailingWidth = 170;

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _pressed ? .98 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() => _pressed = true);
            await Future.delayed(const Duration(milliseconds: 85));
            setState(() => _pressed = false);
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(18),
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
                  // أيقونة كبسولة
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

                  // الوسط: اسم + شيبس
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: title,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (widget.member.phone != null &&
                                widget.member.phone!.trim().isNotEmpty)
                              _miniPill(
                                context,
                                icon: Icons.call_rounded,
                                label: widget.member.phone!,
                                textDirection: TextDirection.ltr, // الأرقام من اليسار لليمين
                                maxLabelWidth: 220,
                              ),
                            _miniPill(
                              context,
                              icon: Icons.event_repeat_rounded,
                              label: 'الخطة: ${widget.planText}',
                            ),
                            _miniPill(
                              context,
                              icon: widget.member.isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.remove_circle_outline,
                              label: widget.member.isActive ? 'مفعل' : 'غير مفعل',
                              fg: widget.member.isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(.65),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // يمين: أزرار بعرض ثابت
                  SizedBox(
                    width: trailingWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _iconBtn(
                          context,
                          tooltip: 'المحفظة',
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: widget.onOpenWallet,
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          context,
                          tooltip: 'تعديل',
                          icon: Icons.edit,
                          onTap: widget.onEdit,
                        ),
                        const SizedBox(width: 6),
                        _iconBtn(
                          context,
                          tooltip: 'حذف',
                          icon: Icons.delete_outline,
                          onTap: widget.onDelete,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            size: 22, color: chevron),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // زر أيقونة صغير ثابت القياس
  Widget _iconBtn(BuildContext context,
      {required String tooltip,
        required IconData icon,
        required VoidCallback onTap,
        Color? color}) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(.5),
            ),
          ),
          child: Icon(icon,
              size: 18,
              color: color ?? theme.colorScheme.onSurface.withOpacity(.8)),
        ),
      ),
    );
  }

  // Pill رفيعة
  Widget _miniPill(
      BuildContext context, {
        required IconData icon,
        required String label,
        Color? fg,
        double? maxLabelWidth,
        TextDirection? textDirection, // ✅ للتحكم باتجاه النص داخل الحبة
      }) {
    final theme = Theme.of(context);
    final Color textColor = fg ?? theme.colorScheme.onSurface.withOpacity(.85);

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
          Icon(icon, size: 14.5, color: textColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxLabelWidth ?? 260,
            ),
            child: Text(
              label,
              textDirection: textDirection,
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
