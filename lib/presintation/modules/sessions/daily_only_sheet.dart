import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../data/models/member.dart';
import '../../../data/models/session.dart';
import '../../../data/models/subscription_category.dart';
import '../../../data/repositories/sessions_repo.dart';
import '../../../data/services/firestore_service.dart';
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
  final fs = FirestoreService();

  StreamSubscription<List<Session>>? _openSessionsSub;
  Session? _openDailySession;
  bool _starting = false;
  bool _finishing = false;
  int? _selectedBandwidth;

  @override
  void initState() {
    super.initState();
    _openSessionsSub =
        sessionsRepo.watchMemberOpenSessions(widget.member.id).listen((list) {
          Session? daily;
          for (final s in list) {
            if (s.category == SubscriptionCategory.daily) {
              daily = s;
              break;
            }
          }
          if (!mounted) return;
          setState(() => _openDailySession = daily);
        });
  }

  @override
  void dispose() {
    _openSessionsSub?.cancel();
    super.dispose();
  }

  // ===== محولات آمنة تمنع toInt على String =====
  int? asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return int.tryParse('$v');
  }

  num? asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return num.tryParse('$v');
  }

  List<_DailyPlanOption> _extractPlans(Map<String, dynamic>? data) {
    final List<_DailyPlanOption> active = [];
    if (data == null) return active;

    final prices = data['prices'];
    if (prices is Map<String, dynamic>) {
      // الشكل الجديد: prices.daily_plans = [ {bandwidth, price, active}, ... ]
      final rawList = prices['daily_plans'];
      if (rawList is List) {
        for (final entry in rawList) {
          if (entry is Map) {
            final map = Map<String, dynamic>.from(entry as Map);
            final isActive = map['active'] != false;

            final bwInt = asInt(map['bandwidth']);
            final priceNum = asNum(map['price']);

            if (isActive && bwInt != null && priceNum != null) {
              active.add(_DailyPlanOption(bandwidth: bwInt, price: priceNum));
            }
          }
        }
        if (active.isNotEmpty) {
          active.sort((a, b) => a.bandwidth.compareTo(b.bandwidth));
          return active;
        }
      }

      // fallback القديم: prices.daily = { "50": 20, 100: 30, ... }
      final fallback = prices['daily'];
      if (fallback is Map) {
        final map = Map<String, dynamic>.from(fallback as Map);
        map.forEach((key, value) {
          final bwInt = asInt(key);
          final priceNum = asNum(value);
          if (bwInt != null && priceNum != null) {
            active.add(_DailyPlanOption(bandwidth: bwInt, price: priceNum));
          }
        });
      }
    }

    active.sort((a, b) => a.bandwidth.compareTo(b.bandwidth));
    return active;
  }

  Future<void> _startDaily(_DailyPlanOption plan) async {
    setState(() => _starting = true);
    try {
      await sessionsRepo.startDailySession(
        memberId: widget.member.id,
        memberName: widget.member.name,
        bandwidthMbps: plan.bandwidth,
        paymentMethod: 'cash',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تسجيل دخول ${widget.member.name} ليوم كامل')),
      );
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
    final base = session.dailyPriceSnapshot ?? session.sessionAmount;
    final drinks = session.drinksTotal;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CloseDailyOnlySheet(
        basePrice: base,
        drinksTotal: drinks,
        initialDiscount: session.discount,
      ),
    );

    if (result == null) return;

    final paymentMethod = (result['paymentMethod'] as String?) ?? 'cash';
    final discount = (result['discount'] as num?) ?? 0;

    setState(() => _finishing = true);
    try {
      await sessionsRepo.finishDailySession(
        sessionId: session.id,
        paymentMethod: paymentMethod,
        discount: discount,
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

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: fs.watchDoc('settings/app'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snap.data?.data();
              final plans = _extractPlans(data);

              // ضبط الاختيار الأولي للخطة
              if (_selectedBandwidth == null && plans.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedBandwidth = plans.first.bandwidth);
                  }
                });
              } else if (plans.isNotEmpty &&
                  plans.every((p) => p.bandwidth != _selectedBandwidth)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedBandwidth = plans.first.bandwidth);
                  }
                });
              }

              final selectedPlan =
              plans.firstWhereOrNull((p) => p.bandwidth == _selectedBandwidth);

              final openSession = _openDailySession;
              final theme = Theme.of(context);

              // حسابات خاصة بوجود جلسة مفتوحة (بدون تعريف متغيرات داخل children)
              num? baseValue;
              num? computedGrand;
              int? bandwidth;
              if (openSession != null) {
                baseValue =
                    openSession.dailyPriceSnapshot ?? openSession.sessionAmount;
                computedGrand =
                    baseValue + openSession.drinksTotal - openSession.discount;

                if (openSession != null) {
                  baseValue =
                      openSession.dailyPriceSnapshot ?? openSession.sessionAmount;
                  computedGrand =
                      baseValue + openSession.drinksTotal - openSession.discount;
                  bandwidth = openSession.bandwidthMbpsSnapshot?.toInt();
                }
              }

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
                  Text('إدارة الاشتراك اليومي', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),

                  // لا توجد جلسة مفتوحة
                  if (openSession == null) ...[
                    if (plans.isEmpty)
                      Card(
                        color: theme.colorScheme.errorContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_rounded,
                                  color: theme.colorScheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'لا توجد خطط يومية مفعلة في الإعدادات.',
                                  style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Text('اختر الخطة اليومية', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: plans
                            .map(
                              (plan) => ChoiceChip(
                            label: Text(
                              '${plan.bandwidth} Mbps • ₪${plan.price.toStringAsFixed(2)}',
                              textDirection: TextDirection.ltr,
                            ),
                            selected: _selectedBandwidth == plan.bandwidth,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _selectedBandwidth = plan.bandwidth);
                            },
                          ),
                        )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      if (selectedPlan != null) ...[
                        _infoTile(
                          icon: Icons.price_change_rounded,
                          title: 'السعر',
                          subtitle:
                          '₪${selectedPlan.price.toStringAsFixed(2)} يتم خصمه الآن',
                        ),
                        _infoTile(
                          icon: Icons.access_time_filled,
                          title: 'المدة',
                          subtitle: 'يوم كامل بدون حساب الساعات',
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed:
                        (_starting || selectedPlan == null) ? null : () => _startDaily(selectedPlan),
                        icon: _starting
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                theme.colorScheme.onPrimary),
                          ),
                        )
                            : const Icon(Icons.login_rounded),
                        label: const Text('تسجيل دخول (خصم فوري)'),
                      ),
                    ],
                  ]

                  // يوجد جلسة مفتوحة
                  else ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ملخص الاشتراك المفتوح',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            if (bandwidth != null)
                              _summaryRow('الباقة', '$bandwidth Mbps'),
                            _summaryRow('سعر اليوم', _currency(baseValue ?? 0)),
                            _summaryRow('المشروبات/الخدمات',
                                _currency(openSession.drinksTotal)),
                            _summaryRow('الخصم المطبق',
                                '- ${_currency(openSession.discount)}'),
                            const Divider(),
                            _summaryRow(
                              'الإجمالي الحالي',
                              _currency((computedGrand ?? 0) < 0 ? 0 : (computedGrand ?? 0)),
                              isStrong: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _finishing ? null : () => _finishDaily(openSession),
                      icon: _finishing
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.onPrimary),
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
            style: isStrong ? const TextStyle(fontWeight: FontWeight.w800) : null,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  String _currency(num value) => '₪${value.toStringAsFixed(2)}';
}

class _DailyPlanOption {
  final int bandwidth;
  final num price;
  const _DailyPlanOption({required this.bandwidth, required this.price});
}

extension IterableFirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
