import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/plan.dart';
import '../../../data/models/subscription_category.dart';
import '../../../data/repositories/plans_repo.dart';

class MemberFormDialog extends StatefulWidget {
  final Member? initial;
  const MemberFormDialog({super.key, this.initial});

  @override
  State<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<MemberFormDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController notes;
  bool isActive = true;

  String? preferredPlan; // 'hour' | 'week' | 'month' | 'daily' | null
  String? selectedPlanId;
  final plansRepo = PlansRepo();

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?.name ?? '');
    phone = TextEditingController(text: widget.initial?.phone ?? '');
    notes = TextEditingController(text: widget.initial?.notes ?? '');
    isActive = widget.initial?.isActive ?? true;
    preferredPlan = widget.initial?.preferredPlan; // قد تكون null
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  List<SubscriptionCategory> get _categories => const [
    SubscriptionCategory.hours,
    SubscriptionCategory.daily,
    SubscriptionCategory.weekly,
    SubscriptionCategory.monthly,
  ];

  int _initialTabIndex() {
    final value = preferredPlan;
    final category = switch (value) {
      'week' => SubscriptionCategory.weekly,
      'month' => SubscriptionCategory.monthly,
      'daily' => SubscriptionCategory.daily,
      _ => SubscriptionCategory.hours,
    };
    return _categories.indexOf(category).clamp(0, _categories.length - 1);
  }

  String _preferredValueForCategory(SubscriptionCategory category) {
    switch (category) {
      case SubscriptionCategory.hours:
        return 'hour';
      case SubscriptionCategory.daily:
        return 'daily';
      case SubscriptionCategory.weekly:
        return 'week';
      case SubscriptionCategory.monthly:
        return 'month';
    }
  }

  Widget _buildPlansTab(SubscriptionCategory category) {
    return StreamBuilder<List<Plan>>(
      stream: plansRepo.watchByCategory(category, onlyActive: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snapshot.data ?? const <Plan>[];
        if (plans.isEmpty) {
          return const Center(child: Text('لا توجد خطط مفعّلة لهذه الفئة'));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // منع سكرول داخلي
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final isSelected = selectedPlanId == plan.id;
            return Card(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(.12)
                  : null,
              child: ListTile(
                onTap: () {
                  setState(() {
                    selectedPlanId = plan.id;
                    preferredPlan = _preferredValueForCategory(category);
                  });
                },
                title: Text(plan.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السعر: ₪ ${plan.price.toStringAsFixed(2)}',
                      textDirection: TextDirection.ltr,
                    ),
                    if (plan.daysCount > 0) Text('عدد الأيام: ${plan.daysCount}'),
                    Text(
                      'السرعة: ${plan.bandwidthMbps} Mbps',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    // نستخدم Dialog بدل AlertDialog لتفادي IntrinsicWidth
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          // عرض منطقي على الموبايل مع حد أقصى للتابلت/الديسكتوب
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // العنوان
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'تعديل عضو' : 'إضافة عضو',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // المحتوى قابل للتمرير
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(labelText: 'الاسم'),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'إلزامي' : null,
                        ),
                        TextFormField(
                          controller: phone,
                          decoration:
                          const InputDecoration(labelText: 'الهاتف'),
                          keyboardType: TextInputType.phone,
                        ),
                        TextFormField(
                          controller: notes,
                          decoration:
                          const InputDecoration(labelText: 'ملاحظات'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            'الخطة المفضلة (اختياري)',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DefaultTabController(
                          length: _categories.length,
                          initialIndex: _initialTabIndex(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TabBar(
                                isScrollable: true,
                                tabs: [
                                  for (final c in _categories) Tab(text: c.label),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // نثبّت ارتفاع منطقة التبويبات لمنع تمدّد غير منضبط
                              SizedBox(
                                height: 220,
                                child: TabBarView(
                                  // PageView داخلي لكنه آمن هنا لأننا لا نستعمل IntrinsicWidth
                                  children: [
                                    for (final c in _categories) _buildPlansTab(c),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => setState(() {
                              preferredPlan = null;
                              selectedPlanId = null;
                            }),
                            child: const Text('مسح الاختيار'),
                          ),
                        ),
                        SwitchListTile(
                          value: isActive,
                          onChanged: (v) => setState(() => isActive = v),
                          title: const Text('مُفعل'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // الأزرار
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (!(_form.currentState?.validate() ?? false)) return;
                        Navigator.pop<Member>(
                          context,
                          Member(
                            id: widget.initial?.id ?? '',
                            name: name.text.trim(),
                            phone: phone.text.trim().isEmpty
                                ? null
                                : phone.text.trim(),
                            notes: notes.text.trim().isEmpty
                                ? null
                                : notes.text.trim(),
                            isActive: isActive,
                            preferredPlan: preferredPlan,
                          ),
                        );
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
