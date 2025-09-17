import 'dart:async';
import 'package:elevate_hub/presintation/modules/sessions/widgets/close_daily_sheet.dart';
import 'package:elevate_hub/presintation/modules/sessions/widgets/session_receipt_sheet.dart';
import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/session.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/sessions_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../../data/repositories/plans_repo.dart';
import '../../../data/models/subscription_category.dart';
import '../../../data/models/plan.dart';
import 'widgets/add_order_sheet.dart';

String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class DailySessionView extends StatefulWidget {
  final Member member;
  const DailySessionView({super.key, required this.member});

  @override
  State<DailySessionView> createState() => _DailySessionViewState();
}

class _DailySessionViewState extends State<DailySessionView> {
  final sessionsRepo = SessionsRepo();
  final ordersRepo = OrdersRepo();
  final settingsRepo = SettingsRepo();
  final plansRepo = PlansRepo();

  String? openSessionId;
  Session? openSession;
  StreamSubscription<List<Session>>? _openSub;

  @override
  void initState() {
    super.initState();
    _openSub =
        sessionsRepo.watchMemberOpenSessions(widget.member.id).listen((sessions) {
          if (!mounted) return;
          setState(() {
            openSessionId = sessions.isNotEmpty ? sessions.first.id : null;
            openSession = sessions.isNotEmpty ? sessions.first : null;
          });
        });
  }

  @override
  void dispose() {
    _openSub?.cancel();
    super.dispose();
  }

  Future<Plan?> _pickSessionPlan(BuildContext context) async {
    // ⬇️ جلب خطط اليومي فقط
    final plans =
    await plansRepo.fetchActiveByCategory(SubscriptionCategory.daily);
    if (plans.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد خطط يومية مفعّلة')),
        );
      }
      return null;
    }

    final defaultPlan = plans.first;

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String current = defaultPlan.id;
        return StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('اختر الخطة', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ...plans.map(
                        (plan) => RadioListTile<String>(
                      value: plan.id,
                      groupValue: current,
                      onChanged: (v) =>
                          setModalState(() => current = v ?? current),
                      title: Text(plan.title),
                      subtitle: Text(
                        '₪ ${plan.price.toStringAsFixed(2)} • ${plan.bandwidthMbps} Mbps',
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, current),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('اختيار'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedId == null) return null;
    return plans.firstWhere((plan) => plan.id == selectedId,
        orElse: () => plans.first);
  }

  String _planSummary(Session? session) {
    if (session == null) return '—';
    final parts = <String>[];
    final category = session.categoryEnum; // ⬅️ استخدم enum المحسوب
    if (category != null) {
      parts.add(category.label);
    }

    final bandwidth = session.bandwidthMbpsSnapshot;
    if (bandwidth != null) {
      parts.add('${bandwidth.toString()} Mbps');
    }

    final price = session.pricePerHourSnapshot;
    final unit = () {
      switch (category) {
        case SubscriptionCategory.daily:
          return ' / يوم';
        case SubscriptionCategory.hours:
          return ' / ساعة';
        case SubscriptionCategory.weekly:
          return ' / أسبوع';
        case SubscriptionCategory.monthly:
          return ' / شهر';
        default:
          return '';
      }
    }();
    parts.add('₪ ${price.toStringAsFixed(2)}$unit');

    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  Future<void> _addOrderFlow(BuildContext context) async {
    if (openSessionId == null) return;

    final sSnap = await settingsRepo.watchSettings().first;
    final drinks = sSnap?.drinks.where((e) => e.active).toList() ?? [];
    if (drinks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مشروبات مفعّلة في الإعدادات')),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddOrderSheet(drinks: drinks),
    );

    if (result != null) {
      await ordersRepo.addOrder(
        sessionId: openSessionId!,
        itemName: result['itemName'] as String,
        unitPriceAtTime: result['unitPriceAtTime'] as num,
        qty: result['qty'] as int,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = openSessionId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عنوان جميل مع أيقونة
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.timer_rounded,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'جلسة يومية — ${widget.member.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (!isOpen)
                FilledButton.icon(
                  onPressed: () async {
                    final choice = await showModalBottomSheet<_CheckInChoice>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.flash_on_rounded),
                              title: const Text('ابدأ الآن'),
                              subtitle:
                              const Text('تسجيل الوقت الحالي كوقت دخول'),
                              onTap: () =>
                                  Navigator.pop(ctx, _CheckInChoice.now),
                            ),
                            const Divider(height: 0),
                            ListTile(
                              leading: const Icon(Icons.schedule_rounded),
                              title: const Text('وقت مخصّص'),
                              subtitle:
                              const Text('اختر تاريخ/ساعة دخول سابقة'),
                              onTap: () =>
                                  Navigator.pop(ctx, _CheckInChoice.custom),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );

                    if (choice == null) return;

                    DateTime? checkInAt;
                    if (choice == _CheckInChoice.custom) {
                      final now = DateTime.now();
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now.subtract(const Duration(days: 30)),
                        lastDate: now,
                        helpText: 'اختر تاريخ الدخول',
                        cancelText: 'إلغاء',
                        confirmText: 'متابعة',
                      );
                      if (pickedDate == null) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(now),
                        helpText: 'اختر ساعة الدخول',
                        cancelText: 'إلغاء',
                        confirmText: 'تأكيد',
                      );
                      if (pickedTime == null) return;

                      final dt = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      if (dt.isAfter(DateTime.now())) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                Text('لا يمكن اختيار وقت في المستقبل')),
                          );
                        }
                        return;
                      }
                      checkInAt = dt;
                    }

                    final plan = await _pickSessionPlan(context);
                    if (plan == null) return;

                    // ⬇️ بدء يومي بخطة محددة + طريقة دفع افتراضيًا كاش
                    final id = await sessionsRepo.startDailyWithPlan(
                      memberId: widget.member.id,
                      memberName: widget.member.name,
                      planId: plan.id,
                      paymentMethod: 'cash',
                      checkInAt: checkInAt,
                    );

                    if (context.mounted) {
                      setState(() {
                        openSessionId = id;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            checkInAt == null
                                ? 'تم بدء الجلسة الآن ✅'
                                : 'تم بدء الجلسة بوقت: ${checkInAt.toString().substring(0, 16)} ✅',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('بدء الجلسة (تسجيل دخول)'),
                ),

              if (isOpen) ...[
                if (openSession != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'الخطة الحالية: ${_planSummary(openSession)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _addOrderFlow(context),
                      icon: const Icon(Icons.local_cafe_rounded),
                      label: const Text('إضافة طلب'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final sid = openSessionId;
                        if (sid == null) return;

                        // اقرأ الجلسة لحساب الملخّص
                        final ds =
                        await sessionsRepo.fs.getDoc('sessions/$sid');
                        final m = ds.data();
                        if (m == null) return;

                        final checkIn = DateTime.tryParse(
                            m['checkInAt']?.toString() ?? '');
                        final now = DateTime.now();
                        int minutes = 0;
                        if (checkIn != null) {
                          final diff = now.difference(checkIn);
                          minutes = sessionsRepo.roundTo5ForUi(diff);
                        }

                        final dynamic priceSnapshot =
                            m['pricePerHourSnapshot'] ?? m['hourlyRateAtTime'] ?? 0;
                        final num hourly = priceSnapshot is num
                            ? priceSnapshot
                            : num.tryParse(priceSnapshot.toString()) ?? 0;
                        final drinks = (m['drinksTotal'] ?? 0) as num;
                        final discount = (m['discount'] ?? 0) as num;

                        // شيت إغلاق يومي (طريقة دفع + خصم + إثبات دفع عند اللزوم)
                        final res = await showModalBottomSheet<CloseDailyResult>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CloseDailySheet(
                            sessionId: sid,
                            minutes: minutes,
                            hourlyRate: hourly,
                            drinksTotal: drinks,
                            discount: discount,
                            sessionsRepo: sessionsRepo,
                          ),
                        );

                        if (res == null) return;

                        // أغلق الجلسة
                        await sessionsRepo.stopSessionWithOptions(
                          sessionId: sid,
                          paymentMethod: res.paymentMethod,
                          manualDiscount: res.discount,
                        );

                        if (!mounted) return;

                        // اعرض إيصال الجلسة
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SessionReceiptSheet(sessionId: sid),
                        );

                        // أغلق شاشة الجلسة اليومية
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text('إيقاف وإغلاق'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // الطلبات + الإجمالي
                StreamBuilder<List<OrderModel>>(
                  stream: ordersRepo.watchBySession(openSessionId!),
                  builder: (context, snap) {
                    final orders = snap.data ?? const <OrderModel>[];
                    final drinksTotal =
                    orders.fold<num>(0, (sum, o) => sum + (o.total ?? 0));

                    if (orders.isEmpty) {
                      return const ListTile(
                        title: Text('لا توجد طلبات بعد'),
                        dense: true,
                      );
                    }

                    return Column(
                      children: [
                        ...orders.map(
                              (o) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(.12),
                              child: Icon(Icons.local_cafe_rounded,
                                  size: 18,
                                  color:
                                  Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(
                              '${o.itemName} × ${o.qty}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سعر الوحدة: ${sCurrency(o.unitPriceAtTime ?? 0)}  •  الإجمالي: ${sCurrency(o.total ?? 0)}',
                                  textDirection: TextDirection.rtl,
                                  style:
                                  Theme.of(context).textTheme.bodySmall,
                                ),
                                if (o.createdAt != null)
                                  Text(
                                    'التاريخ: ${o.createdAt.toString().substring(0, 16)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(.7)),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'حذف الطلب',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await ordersRepo.removeOrder(o);
                              },
                            ),
                          ),
                        ),
                        const Divider(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'إجمالي المشروبات: ${sCurrency(drinksTotal)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CheckInChoice { now, custom }

extension _UiRoundExt on SessionsRepo {
  int roundTo5ForUi(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    final rem = mins % 5;
    return rem == 0 ? mins : mins + (5 - rem);
  }
}
