import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/models/app_user.dart';

class AdminUsersView extends StatelessWidget {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = UsersRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Users')),
      body: StreamBuilder<List<AppUser>>(
        stream: repo.watchAllUsers(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final users = snap.data!;
          if (users.isEmpty) return const Center(child: Text('No users'));

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (ctx, i) {
              final u = users[i];
              return ExpansionTile(
                title: Text(u.email),
                subtitle: Text('${u.status}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('Status:'),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: u.status,
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('pending')),
                            DropdownMenuItem(value: 'active', child: Text('active')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            await repo.updateStatus(u.id, v);
                            Get.snackbar('Updated', 'Status → $v', snackPosition: SnackPosition.BOTTOM);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _PermsEditor(user: u, onSave: (perms) async {
                      await repo.updatePerms(u.id, perms);
                      Get.snackbar('Saved', 'Permissions updated', snackPosition: SnackPosition.BOTTOM);
                    }),
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

class _PermsEditor extends StatefulWidget {
  final AppUser user;
  final Future<void> Function(AppPerms) onSave;
  const _PermsEditor({required this.user, required this.onSave});

  @override
  State<_PermsEditor> createState() => _PermsEditorState();
}

class _PermsEditorState extends State<_PermsEditor> {
  late AppPerms p;

  @override
  void initState() {
    super.initState();
    p = widget.user.perms;
  }

  Widget sw(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        sw('Admin', p.isAdmin, (v) => p = AppPerms(
          isAdmin: v,
          settings: p.settings,
          reports: p.reports,
          orders: p.orders,
          sessions: p.sessions,
          expensesVar: p.expensesVar,
          expensesFixed: p.expensesFixed,
          inventory: p.inventory,
          assets: p.assets,
          debts: p.debts,
          coupons: p.coupons,
        )),
        sw('Settings', p.settings, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: v, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Reports', p.reports, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: v, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Orders', p.orders, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: v,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Sessions', p.sessions, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: v, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Expenses (variable)', p.expensesVar, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: v, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Expenses (fixed monthly)', p.expensesFixed, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: v,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Inventory', p.inventory, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: v, assets: p.assets, debts: p.debts, coupons: p.coupons,
        )),
        sw('Assets', p.assets, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: v, debts: p.debts, coupons: p.coupons,
        )),
        sw('Debts', p.debts, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: v, coupons: p.coupons,
        )),
        sw('Coupons', p.coupons, (v) => p = AppPerms(
          isAdmin: p.isAdmin, settings: p.settings, reports: p.reports, orders: p.orders,
          sessions: p.sessions, expensesVar: p.expensesVar, expensesFixed: p.expensesFixed,
          inventory: p.inventory, assets: p.assets, debts: p.debts, coupons: v,
        )),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => widget.onSave(p),
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
