import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/coupon.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/coupons_repo.dart';
import '../../../data/repositories/members_repo.dart';
import '../../routes/app_routes.dart';
import 'coupon_form_dialog.dart';

class CouponsListView extends StatelessWidget {
  const CouponsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final usersRepo = UsersRepo();
    final couponsRepo = CouponsRepo();
    final membersRepo = MembersRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
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
          // حسب الجدول: الكوبونات Admin فقط
          final canManage = me.perms.isAdmin || me.perms.coupons == true;
          if (!canManage) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox.shrink();
          }

          return StreamBuilder<List<Coupon>>(
            stream: couponsRepo.watchAll(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final items = snap.data!;

              Future<void> addOrEdit([Coupon? initial]) async {
                final members = await membersRepo.watchAll().first;
                final result = await showDialog<Coupon>(
                  context: context,
                  builder: (_) => CouponFormDialog(initial: initial, members: members),
                );
                if (result == null) return;
                if (initial == null) {
                  await couponsRepo.add(result);
                } else {
                  await couponsRepo.update(result.copyWith(id: initial.id));
                }
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => addOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add coupon'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  if (items.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No coupons yet')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final c = items[i];
                          String target() {
                            if (c.appliesTo == 'member') return 'Member: ${c.memberId}';
                            return 'All members';
                          }

                          return ListTile(
                            title: Text('${c.code}  •  ${c.kind} ${c.value}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scope: ${c.scope} • ${target()}'),
                                Text('Active: ${c.active} • '
                                    'From: ${c.validFrom?.toIso8601String().substring(0,10) ?? '—'} '
                                    'To: ${c.validTo?.toIso8601String().substring(0,10) ?? '—'}'),
                                if (c.maxRedemptions != null) Text('Max redemptions: ${c.maxRedemptions}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => addOrEdit(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async => CouponsRepo().delete(c.id),
                                ),
                              ],
                            ),
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
    );
  }
}

extension on Coupon {
  Coupon copyWith({
    String? id,
    String? code,
    String? kind,
    num? value,
    String? scope,
    String? appliesTo,
    String? memberId,
    DateTime? validFrom,
    DateTime? validTo,
    int? maxRedemptions,
    bool? active,
  }) {
    return Coupon(
      id: id ?? this.id,
      code: code ?? this.code,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      scope: scope ?? this.scope,
      appliesTo: appliesTo ?? this.appliesTo,
      memberId: memberId ?? this.memberId,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      maxRedemptions: maxRedemptions ?? this.maxRedemptions,
      active: active ?? this.active,
    );
  }
}
