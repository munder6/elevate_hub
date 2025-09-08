import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';

import '../../../data/repositories/reports_repo.dart';
import '../../../data/export/excel_exporter.dart';

import '../../../data/models/session.dart';
import '../../../data/models/order.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/inventory_item.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/users_repo.dart';
import '../../routes/app_routes.dart';

enum ReportRangeType { daily, weekly, monthly, custom }

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> with SingleTickerProviderStateMixin {
  final usersRepo = UsersRepo();
  final repo = ReportsRepo();
  final exporter = ExcelExporter();

  late final TabController _tab;

  ReportRangeType rangeType = ReportRangeType.daily;
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();

  // data
  bool loading = false;
  List<Session> sessions = [];
  List<OrderModel> orders = [];
  List<Expense> expVar = [];
  final Map<String, List<Expense>> expFixedByMonth = {};
  List<InventoryItem> inventory = [];
  List<Debt> debts = [];
  num revenue = 0, expenses = 0, net = 0;
  String? topDrink;
  String? savedPath;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _applyRangePreset();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _applyRangePreset() {
    final now = DateTime.now();
    switch (rangeType) {
      case ReportRangeType.daily:
        from = DateTime(now.year, now.month, now.day, 0, 0);
        to = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ReportRangeType.weekly:
        final start = now.subtract(Duration(days: now.weekday % 7));
        from = DateTime(start.year, start.month, start.day);
        to = from.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case ReportRangeType.monthly:
        from = DateTime(now.year, now.month, 1);
        final next = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
        to = next;
        break;
      case ReportRangeType.custom:
      // لا تغيّر
        break;
    }
    setState(() {});
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) setState(() => from = DateTime(d.year, d.month, d.day));
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: to,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) setState(() => to = DateTime(d.year, d.month, d.day, 23, 59, 59));
  }

  Future<void> _fetch() async {
    setState(() { loading = true; savedPath = null; });
    try {
      // sessions / orders / expenses / inventory / debts
      sessions = await repo.fetchSessions(from, to);
      orders = await repo.fetchOrders(from, to);
      expVar = await repo.fetchVariableExpenses(from, to);

      // fixed by month (ضمن المدى)
      expFixedByMonth.clear();
      DateTime cursor = DateTime(from.year, from.month, 1);
      while (!cursor.isAfter(DateTime(to.year, to.month, 1))) {
        final mk = '${cursor.year.toString().padLeft(4,'0')}-${cursor.month.toString().padLeft(2,'0')}';
        final list = await repo.fetchFixedMonthlyExpenses(cursor);
        expFixedByMonth[mk] = list;
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }

      inventory = await repo.inventorySnapshot();
      debts = await repo.fetchDebts(from, to);

      // summary
      final s = await repo.summary(from, to);
      revenue = s.revenue;
      expenses = s.expenses;
      net = s.net;
      topDrink = s.topDrink;

      setState(() {});
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _export() async {
    setState(() { loading = true; savedPath = null; });
    try {
      final file = await exporter.buildAndSave(
        from: from,
        to: to,
        sessions: sessions,
        orders: orders,
        expensesVariable: expVar,
        expensesFixedByMonth: expFixedByMonth,
        inventory: inventory,
        debts: debts,
        revenue: revenue,
        expenses: expenses,
        net: net,
        topDrink: topDrink,
      );
      setState(() => savedPath = file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel saved: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() { loading = false; });
    }
  }

  Widget _head() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          runSpacing: 8,
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<ReportRangeType>(
              value: rangeType,
              items: const [
                DropdownMenuItem(value: ReportRangeType.daily, child: Text('Daily')),
                DropdownMenuItem(value: ReportRangeType.weekly, child: Text('Weekly')),
                DropdownMenuItem(value: ReportRangeType.monthly, child: Text('Monthly')),
                DropdownMenuItem(value: ReportRangeType.custom, child: Text('Custom')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => rangeType = v);
                if (v != ReportRangeType.custom) _applyRangePreset();
              },
            ),
            OutlinedButton.icon(
              onPressed: _pickFrom,
              icon: const Icon(Icons.calendar_today),
              label: Text('From: ${from.toIso8601String().substring(0,10)}'),
            ),
            OutlinedButton.icon(
              onPressed: _pickTo,
              icon: const Icon(Icons.calendar_month),
              label: Text('To: ${to.toIso8601String().substring(0,10)}'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: loading ? null : _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Fetch'),
            ),
            FilledButton.icon(
              onPressed: (loading || sessions.isEmpty && orders.isEmpty && expVar.isEmpty && debts.isEmpty)
                  ? null : _export,
              icon: const Icon(Icons.file_download),
              label: const Text('Export'),
            ),
            if (savedPath != null)
              SelectableText(
                savedPath!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return ListTile(
      title: Text('Revenue: $revenue   |   Expenses: $expenses   |   Net: $net'),
      subtitle: Text('Top drink: ${topDrink ?? '—'}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Sessions'),
            Tab(text: 'Orders'),
            Tab(text: 'Expenses'),
            Tab(text: 'Inventory'),
            Tab(text: 'Debts'),
          ],
        ),
      ),
      body: StreamBuilder<AppUser?>(
        stream: usersRepo.watchMe(),
        builder: (context, meSnap) {
          if (!meSnap.hasData) return const Center(child: CircularProgressIndicator());
          final me = meSnap.data!;
          if (!(me.perms.isAdmin || me.perms.reports)) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox.shrink();
          }

          return TabBarView(
            controller: _tab,
            children: [
              // Summary
              Column(
                children: [
                  _head(),
                  const Divider(height: 0),
                  _summary(),
                  const SizedBox(height: 8),
                  if (loading) const LinearProgressIndicator(),
                ],
              ),

              // Sessions
              Column(
                children: [
                  _head(),
                  const Divider(height: 0),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(child: Text('No sessions'))
                        : ListView.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        return ListTile(
                          title: Text('Member: ${s.memberId ?? '—'}  |  Total: ${s.grandTotal ?? 0}'),
                          subtitle: Text('${s.checkInAt?.toString().substring(0,16)}  •  ${s.status}'),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Orders
              Column(
                children: [
                  _head(),
                  const Divider(height: 0),
                  Expanded(
                    child: orders.isEmpty
                        ? const Center(child: Text('No orders'))
                        : ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final o = orders[i];
                        return ListTile(
                          title: Text('${o.itemName ?? '—'}  •  ${o.qty ?? 0}  •  total: ${o.total ?? 0}'),
                          subtitle: Text(o.createdAt?.toString().substring(0,16) ?? ''),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Expenses
              Column(
                children: [
                  _head(),
                  const Divider(height: 0),
                  Expanded(
                    child: ListView(
                      children: [
                        const ListTile(title: Text('Variable')),
                        if (expVar.isEmpty)
                          const ListTile(title: Text('—'))
                        else
                          ...expVar.map((e) => ListTile(
                            title: Text('${e.category} — ${e.amount}'),
                            subtitle: Text(e.createdAt?.toString().substring(0,16) ?? ''),
                          )),
                        const Divider(),
                        const ListTile(title: Text('Fixed by month')),
                        if (expFixedByMonth.isEmpty)
                          const ListTile(title: Text('—'))
                        else
                          ...expFixedByMonth.entries.expand((entry) {
                            final mk = entry.key;
                            final list = entry.value;
                            return [
                              ListTile(title: Text('Month: $mk')),
                              ...list.map((e) => ListTile(
                                title: Text('${e.category} — ${e.amount}'),
                                subtitle: Text(e.reason ?? ''),
                              )),
                              const Divider(),
                            ];
                          }),
                      ],
                    ),
                  ),
                ],
              ),

              // Inventory
              Column(
                children: [
                  _head(),
                  const Divider(height: 0),
                  Expanded(
                    child: inventory.isEmpty
                        ? const Center(child: Text('No inventory'))
                        : ListView.separated(
                      itemCount: inventory.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final it = inventory[i];
                        return ListTile(
                          title: Text(it.name),
                          subtitle: Text('Stock: ${it.stock} / Min: ${it.minStock} ${it.unit}'),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Debts
              Column(
                children: [
                  _head(),
                  const Divider(height: 0),
                  Expanded(
                    child: debts.isEmpty
                        ? const Center(child: Text('No debts'))
                        : ListView.separated(
                      itemCount: debts.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final d = debts[i];
                        return ListTile(
                          title: Text('Member: ${d.id ?? '—'}  |  Amount: ${d.amount ?? 0}'),
                          subtitle: Text('${d.status ?? ''} • ${d.createdAt?.toString().substring(0,16) ?? ''}'),
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
