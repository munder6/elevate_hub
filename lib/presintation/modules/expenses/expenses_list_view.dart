import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/expenses_repo.dart';
import '../../routes/app_routes.dart';
import 'expense_form_dialog.dart';

class ExpensesListView extends StatefulWidget {
  const ExpensesListView({super.key});

  @override
  State<ExpensesListView> createState() => _ExpensesListViewState();
}

class _ExpensesListViewState extends State<ExpensesListView> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final usersRepo = UsersRepo();
  final repo = ExpensesRepo();

  DateTime selectedDay = DateTime.now();
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) setState(() => selectedDay = d);
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) setState(() => selectedMonth = DateTime(d.year, d.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Daily (variable)'),
            Tab(text: 'Fixed monthly'),
          ],
        ),
      ),
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
          // الصلاحيات حسب الجدول: admin + accountant لهم الدخول (و staff للمتغيرة إن حبيت)
          final canView = me.perms.isAdmin || me.perms.expenses == true;
          if (!canView) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox.shrink();
          }

          return TabBarView(
            controller: _tab,
            children: [
              // ---- Daily (variable) ----
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDay,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () async {
                            final data = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (_) => const ExpenseFormDialog(),
                            );
                            if (data != null) {
                              await repo.addVariable(
                                amount: data['amount'],
                                category: data['category'],
                                reason: (data['reason'] as String).isEmpty ? null : data['reason'],
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  Expanded(
                    child: StreamBuilder<List<Expense>>(
                      stream: repo.watchByDay(selectedDay),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final items = snap.data!;
                        if (items.isEmpty) return const Center(child: Text('No expenses'));

                        final total = items.fold<num>(0, (s, e) => s + e.amount);

                        return Column(
                          children: [
                            ListTile(
                              title: Text('Total: $total'),
                            ),
                            const Divider(height: 0),
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const Divider(height: 0),
                                itemBuilder: (_, i) {
                                  final e = items[i];
                                  return ListTile(
                                    title: Text('${e.category} — ${e.amount}'),
                                    subtitle: e.reason != null && e.reason!.trim().isNotEmpty
                                        ? Text(e.reason!)
                                        : null,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => repo.delete(e.id),
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
                ],
              ),

              // ---- Fixed Monthly ----
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickMonth,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}',
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () async {
                            final data = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (_) => const ExpenseFormDialog(fixedMonthly: true),
                            );
                            if (data != null) {
                              await repo.addFixedMonthly(
                                amount: data['amount'],
                                category: data['category'],
                                reason: (data['reason'] as String).isEmpty ? null : data['reason'],
                                month: (data['month'] as DateTime?) ?? selectedMonth,
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  Expanded(
                    child: StreamBuilder<List<Expense>>(
                      stream: repo.watchFixedByMonth(selectedMonth),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final items = snap.data!;
                        if (items.isEmpty) return const Center(child: Text('No fixed items'));

                        final total = items.fold<num>(0, (s, e) => s + e.amount);
                        return Column(
                          children: [
                            ListTile(title: Text('Total: $total')),
                            const Divider(height: 0),
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const Divider(height: 0),
                                itemBuilder: (_, i) {
                                  final e = items[i];
                                  return ListTile(
                                    title: Text('${e.category} — ${e.amount}'),
                                    subtitle: e.reason != null && e.reason!.trim().isNotEmpty
                                        ? Text(e.reason!)
                                        : null,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => repo.delete(e.id),
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
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
