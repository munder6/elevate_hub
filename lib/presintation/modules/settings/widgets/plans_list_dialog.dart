import 'package:flutter/material.dart';

import '../../../../data/models/plan.dart';
import '../../../../data/models/subscription_category.dart';
import '../../../../data/repositories/plans_repo.dart';
import 'plan_editor_dialog.dart';

class PlansListDialog extends StatefulWidget {
  const PlansListDialog({super.key});

  @override
  State<PlansListDialog> createState() => _PlansListDialogState();
}

class _PlansListDialogState extends State<PlansListDialog> {
  final plansRepo = PlansRepo();
  SubscriptionCategory? categoryFilter;
  int? bandwidthFilter;
  bool showInactive = false;

  Future<void> _createPlan() async {
    final plan = await showDialog<Plan>(
      context: context,
      builder: (_) => const PlanEditorDialog(),
    );
    if (plan != null) {
      await plansRepo.create(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت إضافة الخطة ${plan.title}')),
        );
      }
    }
  }

  Future<void> _editPlan(Plan plan) async {
    final updated = await showDialog<Plan>(
      context: context,
      builder: (_) => PlanEditorDialog(initial: plan),
    );
    if (updated != null) {
      await plansRepo.update(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الخطة ${updated.title}')),
        );
      }
    }
  }

  Future<void> _toggleActive(Plan plan, bool value) async {
    await plansRepo.setActive(plan.id, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'تم تفعيل ${plan.title}' : 'تم إيقاف ${plan.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('الخطط والتسعير')),
            IconButton(
              onPressed: _createPlan,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'إضافة خطة',
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 480,
          child: StreamBuilder<List<Plan>>(
            stream: plansRepo.watchAll(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final plans = snapshot.data!;
              final filtered = plans.where((plan) {
                final matchesCategory =
                    categoryFilter == null || plan.category == categoryFilter;
                final matchesBandwidth =
                    bandwidthFilter == null || plan.bandwidthMbps == bandwidthFilter;
                final matchesActive = showInactive || plan.active;
                return matchesCategory && matchesBandwidth && matchesActive;
              }).toList()
                ..sort((a, b) => a.title.compareTo(b.title));

              final bandwidthOptions = plans
                  .where((plan) =>
              categoryFilter == null || plan.category == categoryFilter)
                  .map((plan) => plan.bandwidthMbps)
                  .toSet()
                  .toList()
                ..sort();

              return Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<SubscriptionCategory?>(
                          value: categoryFilter,
                          decoration:
                          const InputDecoration(labelText: 'الفئة', isDense: true),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('كل الفئات'),
                            ),
                            for (final c in allSubscriptionCategories)
                              DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ),
                          ],
                          onChanged: (c) => setState(() {
                            categoryFilter = c;
                            bandwidthFilter = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: bandwidthFilter,
                          decoration:
                          const InputDecoration(labelText: 'السرعة', isDense: true),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('كل السرعات'),
                            ),
                            for (final bw in bandwidthOptions)
                              DropdownMenuItem(
                                value: bw,
                                child: Text('$bw Mbps'),
                              ),
                          ],
                          onChanged: (v) => setState(() => bandwidthFilter = v),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showInactive,
                          onChanged: (v) => setState(() => showInactive = v ?? false),
                        ),
                        const Text('عرض غير المفعّل'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Expanded(
                      child: Center(child: Text('لا توجد خطط مطابقة للفلتر الحالي')),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final plan = filtered[index];
                          return Card(
                            child: ListTile(
                              title: Text(plan.title),
                              subtitle: Text(
                                '${plan.category.label} • ₪ ${plan.price.toStringAsFixed(2)} • ${plan.daysCount} يوم • ${plan.bandwidthMbps} Mbps',
                                textDirection: TextDirection.ltr,
                              ),
                              onTap: () => _editPlan(plan),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: plan.active,
                                    onChanged: (v) => _toggleActive(plan, v),
                                  ),
                                  IconButton(
                                    onPressed: () => _editPlan(plan),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'تعديل',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}