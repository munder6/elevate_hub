// lib/presintation/modules/orders/orders_list_view.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/members_repo.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../routes/app_routes.dart';
import 'widgets/quick_add_order_sheet.dart';
import 'add_standalone_order_sheet.dart'; // <-- تأكد من وجود الملف اللي أرسلته لك

class OrdersListView extends StatelessWidget {
  const OrdersListView({super.key});

  @override
  Widget build(BuildContext context) {
    final usersRepo = UsersRepo();
    final ordersRepo = OrdersRepo();
    final membersRepo = MembersRepo();
    final theme = Theme.of(context);

    // بدل ما نعرض IDs، بنعرض النوع + اسم الشخص
    String parentLabel(OrderModel o) {
      if ((o.standalone ?? false) == true) {
        final who = (o.customerName?.trim().isNotEmpty == true)
            ? o.customerName!.trim()
            : 'Walk-in';
        return 'مستقل • $who';
      }
      final who = (o.memberName?.trim().isNotEmpty == true)
          ? o.memberName!.trim()
          : (o.memberId ?? '—');

      if (o.sessionId != null) return 'يومي • $who';
      if (o.weeklyCycleId != null) return 'أسبوعي • $who';
      if (o.monthlyCycleId != null) return 'شهري • $who';
      return who;
    }

    Future<void> _openAddForMember(BuildContext context) async {
      final members = await membersRepo.watchAll().first;
      final settings = await SettingsRepo().watchSettings().first;

      if (members.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد أعضاء')),
        );
        return;
      }
      final activeDrinks = (settings?.drinks ?? []).where((d) => d.active).toList();
      if (activeDrinks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد مشروبات مفعّلة في الإعدادات')),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => QuickAddOrderSheet(
          members: members,
          drinks: activeDrinks,
        ),
      );
    }

    Future<void> _openAddStandalone(BuildContext context) async {
      final settings = await SettingsRepo().watchSettings().first;
      final drinks = (settings?.drinks ?? []);
      if (drinks.where((d) => d.active).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد مشروبات مفعّلة في الإعدادات')),
        );
        return;
      }

      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddStandaloneOrderSheet(
          drinks: drinks, // الشيت بيصفي active لوحده
        ),
      );

      if (result != null) {
        await OrdersRepo().addStandaloneOrder(
          customerName: result['customerName'] as String,
          itemName: result['itemName'] as String,
          unitPriceAtTime: result['unitPriceAtTime'] as num,
          qty: result['qty'] as int,
          note: result['note'] as String?,
        );
      }
    }

    Future<void> _chooseAddType(BuildContext context) async {
      // شيت بسيط يعطي خيارين: عضو أو مستقل
      await showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('طلب لعضو (يومي/أسبوعي/شهري)'),
                onTap: () {
                  Navigator.pop(context);
                  _openAddForMember(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('طلب مستقل (Walk-in)'),
                onTap: () {
                  Navigator.pop(context);
                  _openAddStandalone(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: StreamBuilder<AppUser?>(
          stream: usersRepo.watchMe(),
          builder: (context, meSnap) {
            if (meSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final me = meSnap.data;
            if (me == null) {
              Future.microtask(() => Get.offAllNamed(AppRoutes.login));
              return const SizedBox.shrink();
            }
            if (!(me.perms.orders == true || me.perms.isAdmin)) {
              Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
              return const SizedBox.shrink();
            }

            return StreamBuilder<List<OrderModel>>(
              stream: ordersRepo.watchLatest(limit: 100),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snap.data!;
                return CustomScrollView(
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
                          Icon(Icons.local_cafe_rounded,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          const Text('الطلبات'),
                        ],
                      ),
                    ),

                    if (orders.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 56, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Text('لا توجد طلبات بعد',
                                  style: theme.textTheme.titleMedium),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                        sliver: SliverList.separated(
                          itemCount: orders.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final o = orders[i];
                            return _OrderTileCard(
                              order: o,
                              parent: parentLabel(o),
                              onDelete: () => ordersRepo.removeOrder(o),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),

        // زر الإضافة: يفتح شيت اختيار النوع (عضو/مستقل)
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('إضافة'),
          onPressed: () => _chooseAddType(context),
        ),
      ),
    );
  }
}

/// كرت عرض طلب: ديناميكي الارتفاع، بدون قص للنصوص
class _OrderTileCard extends StatelessWidget {
  final OrderModel order;
  final String parent;
  final VoidCallback onDelete;

  const _OrderTileCard({
    required this.order,
    required this.parent,
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

    final num computedTotal =
    (order.total ?? (order.unitPriceAtTime! * order.qty!));
    final isPos = computedTotal >= 0;
    final Color totalBg =
    (isPos ? theme.colorScheme.primary : theme.colorScheme.error)
        .withOpacity(.12);
    final Color totalFg =
    isPos ? theme.colorScheme.primary : theme.colorScheme.error;

    // السطر "النوع • الاسم"
    final whoLine = parent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {}, // عرض فقط
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // أيقونة
                Container(
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.local_cafe_rounded,
                      size: 24, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),

                // الوسط: عنوان + تفاصيل + كبسولات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان: اسم المنتج × الكمية (بدون قص)
                      Text(
                        '${order.itemName} × ${order.qty}',
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: title,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // السطر: النوع والاسم
                      _detailLine(context, 'النوع/الزبون', whoLine),

                      // السطر: أُضيف بواسطة
                      if ((order.createdByName ?? '').isNotEmpty)
                        _detailLine(
                            context, 'أضيف بواسطة', order.createdByName!),

                      const SizedBox(height: 10),

                      // كبسولات معلومات مختصرة
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniPill(
                            context,
                            icon: Icons.payments_rounded,
                            label:
                            'سعر الوحدة: ₪${(order.unitPriceAtTime ?? 0).toStringAsFixed(2)}',
                          ),
                          _miniPill(
                            context,
                            icon: Icons.format_list_numbered_rounded,
                            label: 'الكمية: ${order.qty}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // يمين: الإجمالي + حذف
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: totalBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: totalFg.withOpacity(.35)),
                      ),
                      child: Text(
                        '₪ ${computedTotal.toStringAsFixed(2)}',
                        softWrap: false,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: totalFg,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _iconBtn(
                      context,
                      tooltip: 'حذف',
                      icon: Icons.delete_outline,
                      onTap: onDelete,
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

  // عنصر سطر تفصيلي: "المفتاح: القيمة"
  Widget _detailLine(BuildContext context, String key, String value,
      {bool ltr = false}) {
    final styleKey = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(.70),
      height: 1.25,
      fontWeight: FontWeight.w600,
    );
    final styleVal = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(.90),
      height: 1.25,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 2),
      child: RichText(
        textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
        text: TextSpan(
          children: [
            TextSpan(text: '$key: ', style: styleKey),
            TextSpan(text: value, style: styleVal),
          ],
        ),
      ),
    );
  }

  // زر أيقونة صغير ثابت
  Widget _iconBtn(BuildContext context,
      {required String tooltip,
        required IconData icon,
        required VoidCallback onTap}) {
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
              size: 18, color: theme.colorScheme.onSurface.withOpacity(.8)),
        ),
      ),
    );
  }

  // كبسولة معلومات خفيفة
  Widget _miniPill(BuildContext context,
      {required IconData icon, required String label}) {
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
          Text(
            label,
            softWrap: true,
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
}
