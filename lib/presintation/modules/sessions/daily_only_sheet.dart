import 'dart:async';
import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/plan.dart';
import '../../../data/models/session.dart';
import '../../../data/models/subscription_category.dart';
import '../../../data/repositories/plans_repo.dart';
import '../../../data/repositories/sessions_repo.dart';
import 'widgets/close_daily_only_sheet.dart';
import 'widgets/session_receipt_sheet.dart';



class DailyOnlySheet extends StatefulWidget {
  final Member member;
  const DailyOnlySheet({super.key, required this.member});

  @override
  State<DailyOnlySheet> createState() => _DailyOnlySheetState();
}

class _DailyOnlySheetState extends State<DailyOnlySheet> {
  final sessionsRepo = SessionsRepo();
  final plansRepo = PlansRepo();

  late final Stream<List<Plan>> _plansStream;
  StreamSubscription<List<Session>>? _openSub;

  Session? _openDailySession;
  String? _selectedPlanId;

  String _paymentMethod = 'cash'; // cash | app | unpaid | card | other
  final TextEditingController _proofCtrl = TextEditingController();

  bool _starting = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _plansStream =
        plansRepo.watchByCategory(SubscriptionCategory.daily, onlyActive: true);

    _openSub = sessionsRepo
        .watchMemberOpenSessions(widget.member.id)
        .listen((sessions) {
      final daily = sessions.firstWhereOrNull(
            (s) => s.categoryEnum == SubscriptionCategory.daily,
      );
      if (!mounted) return;
      setState(() => _openDailySession = daily);
    });
  }

  @override
  void dispose() {
    _openSub?.cancel();
    _proofCtrl.dispose();
    super.dispose();
  }

  bool get _requiresProof => _paymentMethod == 'app';

  bool get _canStart {
    if (_selectedPlanId == null) return false;
    if (!_requiresProof) return true;
    return _proofCtrl.text.trim().isNotEmpty;
  }

  void _ensureSelection(List<Plan> plans) {
    if (plans.isEmpty) {
      _selectedPlanId = null;
      return;
    }
    if (_selectedPlanId != null && plans.any((p) => p.id == _selectedPlanId)) {
      return;
    }
    _selectedPlanId = plans.first.id;
  }

  Future<void> _startDaily(Plan plan) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final proof = _requiresProof ? _proofCtrl.text.trim() : null;
      await sessionsRepo.startDailyWithPlan(
        memberId: widget.member.id,
        memberName: widget.member.name,
        planId: plan.id,
        paymentMethod: _paymentMethod,
        proofUrl: (proof?.isEmpty ?? true) ? null : proof,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم بدء اليوم واحتساب ₪${plan.price.toStringAsFixed(2)}'),
        ),
      );
      if (_requiresProof) {
        _proofCtrl.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل بدء الاشتراك اليومي: $e')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _finishDaily(Session session) async {
    if (_finishing) return;

    final base = session.dailyPriceSnapshot ?? session.sessionAmount;
    final drinks = session.drinksTotal;

    final result = await showModalBottomSheet<CloseDailyResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CloseDailyOnlySheet(
        sessionId: session.id,
        basePrice: base,
        drinksTotal: drinks,
        initialDiscount: session.discount,
        initialPaymentMethod: session.paymentMethodValue,
        initialProofUrl: session.paymentProofUrl,
      ),
    );
    if (result == null) return;

    setState(() => _finishing = true);
    try {
      await sessionsRepo.finishDailySession(
        sessionId: session.id,
        paymentMethod: result.paymentMethod,
        discount: result.discount,
        proofUrl: result.proofUrl,
      );

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => SessionReceiptSheet(sessionId: session.id),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إغلاق الاشتراك اليومي: $e')),
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Widget _paymentChips(ThemeData theme) {
    const methods = <({String value, String label})>[
      (value: 'cash', label: 'كاش'),
      (value: 'app', label: 'تطبيق'),
      (value: 'unpaid', label: 'تسجيل دين'),
      (value: 'card', label: 'بطاقة'),
      (value: 'other', label: 'أخرى'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: methods
          .map(
            (m) => ChoiceChip(
          label: Text(m.label),
          selected: _paymentMethod == m.value,
          onSelected: (selected) {
            if (!selected) return;
            setState(() {
              _paymentMethod = m.value;
              if (!_requiresProof) _proofCtrl.clear();
            });
          },
        ),
      )
          .toList(),
    );
  }

  Widget _proofField() {
    if (!_requiresProof) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _proofCtrl,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'إثبات الدفع',
            hintText: 'رابط أو مرجع التحويل',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _openSessionCard(Session session, ThemeData theme) {
    final base = session.dailyPriceSnapshot ?? session.sessionAmount;
    final drinks = session.drinksTotal;
    final discount = session.discount;
    final total = (base + drinks - discount).clamp(0, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ملخص الاشتراك المفتوح',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _summaryRow('سعر اليوم', _currency(base)),
            _summaryRow('المشروبات/الخدمات', _currency(drinks)),
            _summaryRow('الخصم', '- ${_currency(discount)}'),
            const Divider(),
            _summaryRow('الإجمالي الحالي', _currency(total), isStrong: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StreamBuilder<List<Plan>>(
            stream: _plansStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final plans = snapshot.data ?? const <Plan>[];
              _ensureSelection(plans);
              final selectedPlan =
              plans.firstWhereOrNull((p) => p.id == _selectedPlanId);

              final hasOpen = _openDailySession != null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('إدارة الاشتراك اليومي',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),

                  // لا توجد جلسة مفتوحة
                  if (!hasOpen) ...[
                    if (plans.isEmpty)
                      Card(
                        color: theme.colorScheme.errorContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_rounded,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'لا توجد خطط يومية مفعّلة',
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Text('اختر الخطة اليومية',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...plans.map(
                            (plan) => RadioListTile<String>(
                          value: plan.id,
                          groupValue: _selectedPlanId,
                          onChanged: (v) => setState(() {
                            _selectedPlanId = v;
                          }),
                          title: Text(plan.title),
                          subtitle: Text(
                            '${plan.bandwidthMbps} Mbps • ₪${plan.price.toStringAsFixed(2)}',
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('طريقة الدفع', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _paymentChips(theme),
                      _proofField(),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _canStart && selectedPlan != null
                            ? () => _startDaily(selectedPlan)
                            : null,
                        icon: _starting
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                            : const Icon(Icons.login_rounded),
                        label: const Text('تسجيل دخول (خصم فوري)'),
                      ),
                    ],
                  ]
                  // يوجد جلسة مفتوحة
                  else ...[
                    _openSessionCard(_openDailySession!, theme),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _finishing
                          ? null
                          : () => _finishDaily(_openDailySession!),
                      icon: _finishing
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                          : const Icon(Icons.logout_rounded),
                      label: const Text('إنهاء وإغلاق'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: isStrong
                ? const TextStyle(fontWeight: FontWeight.w800)
                : null,
          ),
        ],
      ),
    );
  }

  String _currency(num value) => '₪${value.toStringAsFixed(2)}';
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
