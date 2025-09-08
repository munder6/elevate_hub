import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elevate_hub/presintation/modules/sessions/widgets/close_daily_sheet.dart';
import 'package:elevate_hub/presintation/modules/sessions/widgets/session_receipt_sheet.dart';
import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/session.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/debts_repo.dart';
import '../../../data/repositories/sessions_repo.dart';
import '../../../data/repositories/orders_repo.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/services/auth_service.dart';
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
  final _debtsRepo = DebtsRepo();
  final _auth = AuthService();

  String? openSessionId;
  StreamSubscription<List<Session>>? _openSub;

  @override
  void initState() {
    super.initState();
    _openSub = sessionsRepo.watchMemberOpenSessions(widget.member.id).listen((sessions) {
      if (!mounted) return;
      setState(() => openSessionId = sessions.isNotEmpty ? sessions.first.id : null);
    });
  }

  @override
  void dispose() {
    _openSub?.cancel();
    super.dispose();
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
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عنوان جميل مع أيقونة
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(.12),
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
                              subtitle: const Text('تسجيل الوقت الحالي كوقت دخول'),
                              onTap: () => Navigator.pop(ctx, _CheckInChoice.now),
                            ),
                            const Divider(height: 0),
                            ListTile(
                              leading: const Icon(Icons.schedule_rounded),
                              title: const Text('وقت مخصّص'),
                              subtitle: const Text('اختر تاريخ/ساعة دخول سابقة'),
                              onTap: () => Navigator.pop(ctx, _CheckInChoice.custom),
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
                            const SnackBar(content: Text('لا يمكن اختيار وقت في المستقبل')),
                          );
                        }
                        return;
                      }
                      checkInAt = dt;
                    }

                    final id = await sessionsRepo.startSession(
                      widget.member.id,
                      memberName: widget.member.name,
                      checkInAt: checkInAt,
                    );

                    if (context.mounted) {
                      setState(() => openSessionId = id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            checkInAt == null
                                ? 'تم بدء الجلسة الآن ✅'
                                : 'تم بدء الجلسة بوقت: ${checkInAt.toString().substring(0,16)} ✅',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('بدء الجلسة (تسجيل دخول)'),
                ),

              if (isOpen) ...[
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
                        final ds = await sessionsRepo.fs.getDoc('sessions/$sid');
                        final m = ds.data();
                        if (m == null) return;

                        final checkIn = DateTime.tryParse(m['checkInAt']?.toString() ?? '');
                        final now = DateTime.now();
                        int minutes = 0;
                        if (checkIn != null) {
                          final diff = now.difference(checkIn);
                          minutes = sessionsRepo.roundTo5ForUi(diff);
                        }

                        final hourly = (m['hourlyRateAtTime'] ?? 0) as num;
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

                        // لو لم يُدفع → دين
                        if (res.paymentMethod == 'unpaid') {
                          final stopped = await sessionsRepo.fs.getDoc('sessions/$sid');
                          final sm = stopped.data();
                          if (sm != null) {
                            final memberId = sm['memberId'] as String?;
                            String memberName = (sm['memberName'] as String?) ?? '';
                            if ((memberName.isEmpty) && memberId != null) {
                              try {
                                final ms = await sessionsRepo.fs.getDoc('members/$memberId');
                                final mm = ms.data();
                                if (mm != null) memberName = (mm['name'] as String?) ?? '';
                              } catch (_) {}
                            }
                            final grand = (sm['grandTotal'] ?? 0) as num;

                            if (memberId != null && grand > 0) {
                              final debtRef =
                              sessionsRepo.fs.doc('debts/session_$sid');
                              final ds = await debtRef.get();
                              final data = {
                                'amount': grand,
                                'reason': 'جلسة يومية غير مدفوعة',
                                'memberId': memberId,
                                'memberName': memberName,
                                'refType': 'session',
                                'refId': sid,
                              };
                              if (ds.exists) {
                                await debtRef.set(data, SetOptions(merge: true));
                              } else {
                                await debtRef.set({
                                  ...data,
                                  'status': 'open',
                                  'createdAt': DateTime.now().toIso8601String(),
                                  'payments': <Map<String, dynamic>>[],
                                });
                              }

                              final q = await sessionsRepo.fs
                                  .col('debts')
                                  .where('refType', isEqualTo: 'session')
                                  .where('refId', isEqualTo: sid)
                                  .get();
                              for (final d in q.docs) {
                                if (d.id != 'session_$sid') {
                                  await d.reference.delete();
                                }
                              }
                            }
                          }
                        }

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
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
                              child: Icon(Icons.local_cafe_rounded,
                                  size: 18, color: Theme.of(context).colorScheme.primary),
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
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (o.createdAt != null)
                                  Text(
                                    'التاريخ: ${o.createdAt.toString().substring(0,16)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(.7)),
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
