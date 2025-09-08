import 'package:flutter/material.dart';

import '../../../../data/models/member.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../data/repositories/sessions_repo.dart';
import '../../../../data/repositories/weekly_repo.dart';
import '../../../../data/repositories/monthly_repo.dart';
import '../../../../data/repositories/orders_repo.dart';

class QuickAddOrderSheet extends StatefulWidget {
  final List<Member> members;
  final List<DrinkItem> drinks;

  const QuickAddOrderSheet({
    super.key,
    required this.members,
    required this.drinks,
  });

  @override
  State<QuickAddOrderSheet> createState() => _QuickAddOrderSheetState();
}

class _QuickAddOrderSheetState extends State<QuickAddOrderSheet> {
  final sessionsRepo = SessionsRepo();
  final weeklyRepo = WeeklyRepo();
  final monthlyRepo = MonthlyRepo();
  final ordersRepo = OrdersRepo();

  int memberIdx = 0;
  int drinkIdx = 0;
  int qty = 1;

  String target = 'auto'; // auto | daily | weekly | monthly

  @override
  Widget build(BuildContext context) {
    final m = widget.members[memberIdx];
    final d = widget.drinks[drinkIdx];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إضافة طلب سريع', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // العضو
              DropdownButtonFormField<int>(
                value: memberIdx,
                decoration: const InputDecoration(labelText: 'العضو'),
                items: [
                  for (int i = 0; i < widget.members.length; i++)
                    DropdownMenuItem(value: i, child: Text(widget.members[i].name)),
                ],
                onChanged: (v) => setState(() => memberIdx = v ?? 0),
              ),
              const SizedBox(height: 8),

              // الوجهة
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(labelText: 'الوجهة'),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('تلقائي (حسب الخطة المفضلة)')),
                  DropdownMenuItem(value: 'daily', child: Text('جلسة يومية')),
                  DropdownMenuItem(value: 'weekly', child: Text('دورة أسبوعية')),
                  DropdownMenuItem(value: 'monthly', child: Text('دورة شهرية')),
                ],
                onChanged: (v) => setState(() => target = v ?? 'auto'),
              ),
              const SizedBox(height: 8),

              // المشروب
              DropdownButtonFormField<int>(
                value: drinkIdx,
                decoration: const InputDecoration(labelText: 'المشروب'),
                items: [
                  for (int i = 0; i < widget.drinks.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('${widget.drinks[i].name} — ₪ ${widget.drinks[i].price.toStringAsFixed(2)}',
                          textDirection: TextDirection.ltr),
                    ),
                ],
                onChanged: (v) => setState(() => drinkIdx = v ?? 0),
              ),
              const SizedBox(height: 8),

              // الكمية + الإجمالي
              Row(
                children: [
                  const Text('الكمية'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: qty > 1 ? () => setState(() => qty--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$qty'),
                  IconButton(
                    onPressed: () => setState(() => qty++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  Text(
                    'الإجمالي: ₪ ${(widget.drinks[drinkIdx].price * qty).toStringAsFixed(2)}',
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('إضافة'),
                onPressed: () async {
                  final member = widget.members[memberIdx];
                  final drink = widget.drinks[drinkIdx];

                  // تحديد الوجهة الفعلية
                  String? resolved = target;
                  if (target == 'auto') {
                    resolved = switch (member.preferredPlan) {
                      'hour' => 'daily',
                      'week' => 'weekly',
                      'month' => 'monthly',
                      _ => 'daily',
                    };
                  }

                  // جلب الحاوية النشطة أو إبلاغ المستخدم
                  if (resolved == 'daily') {
                    final open = await sessionsRepo.watchMemberOpenSessions(member.id).first;
                    if (open.isEmpty) {
                      _snack(context, 'لا توجد جلسة يومية نشطة للعضو ${member.name}');
                      return;
                    }
                    await ordersRepo.addOrder(
                      sessionId: open.first.id,
                      itemName: drink.name,
                      unitPriceAtTime: drink.price,
                      qty: qty,
                    );
                  } else if (resolved == 'weekly') {
                    final active = await weeklyRepo.watchActiveByMember(member.id).first;
                    if (active.isEmpty) {
                      _snack(context, 'لا توجد دورة أسبوعية نشطة للعضو ${member.name}');
                      return;
                    }
                    await ordersRepo.addOrderForWeekly(
                      cycleId: active.first.id,
                      itemName: drink.name,
                      unitPriceAtTime: drink.price,
                      qty: qty,
                    );
                  } else if (resolved == 'monthly') {
                    final active = await monthlyRepo.watchActiveByMember(member.id).first;
                    if (active.isEmpty) {
                      _snack(context, 'لا توجد دورة شهرية نشطة للعضو ${member.name}');
                      return;
                    }
                    await ordersRepo.addOrderForMonthly(
                      cycleId: active.first.id,
                      itemName: drink.name,
                      unitPriceAtTime: drink.price,
                      qty: qty,
                    );
                  }

                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
