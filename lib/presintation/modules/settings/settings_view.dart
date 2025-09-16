import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/settings_repo.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/users_repo.dart';
import '../../routes/app_routes.dart';

import 'widgets/edit_prices_dialog.dart';
import 'widgets/edit_drink_dialog.dart';
import 'widgets/edit_fixed_expense_dialog.dart';
import 'widgets/edit_notes_bar_dialog.dart';
import 'widgets/plans_list_dialog.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SettingsRepo();
    final usersRepo = UsersRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<AppUser?>(
        stream: usersRepo.watchMe(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = userSnap.data;
          if (me == null) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.login));
            return const SizedBox();
          }
          if (me.perms.settings != true) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox();
          }

          return StreamBuilder<AppSettings?>(
            stream: repo.watchSettings(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = snap.data!;

              Future<void> editPrices() async {
                final result = await showDialog<Map<String, num>>(
                  context: context,
                  builder: (_) => EditPricesDialog(
                    hourly: s.hourly,
                    weekly: s.weekly,
                    monthly: s.monthly,
                  ),
                );
                if (result != null) {
                  await repo.updatePrices(
                    hourly: result['hourly'],
                    weekly: result['weekly'],
                    monthly: result['monthly'],
                  );
                  Get.snackbar('Saved', 'Prices updated',
                      snackPosition: SnackPosition.BOTTOM);
                }
              }

              Future<void> addDrink() async {
                final item = await showDialog<DrinkItem>(
                  context: context,
                  builder: (_) => const EditDrinkDialog(),
                );
                if (item != null) {
                  final list = [...s.drinks, item];
                  await repo.updateDrinks(list);
                }
              }

              Future<void> editDrink(int index) async {
                final item = await showDialog<DrinkItem>(
                  context: context,
                  builder: (_) => EditDrinkDialog(initial: s.drinks[index]),
                );
                if (item != null) {
                  final list = [...s.drinks];
                  list[index] = item;
                  await repo.updateDrinks(list);
                }
              }

              Future<void> toggleDrink(int index, bool v) async {
                final list = [...s.drinks];
                final d = list[index];
                list[index] = DrinkItem(name: d.name, price: d.price, active: v);
                await repo.updateDrinks(list);
              }

              Future<void> removeDrink(int index) async {
                final list = [...s.drinks]..removeAt(index);
                await repo.updateDrinks(list);
              }

              Future<void> addFixedExpense() async {
                final item = await showDialog<FixedExpenseItem>(
                  context: context,
                  builder: (_) => const EditFixedExpenseDialog(),
                );
                if (item != null) {
                  final list = [...s.fixedExpenses, item];
                  await repo.updateFixedExpenses(list);
                }
              }

              Future<void> editFixedExpense(int index) async {
                final item = await showDialog<FixedExpenseItem>(
                  context: context,
                  builder: (_) =>
                      EditFixedExpenseDialog(initial: s.fixedExpenses[index]),
                );
                if (item != null) {
                  final list = [...s.fixedExpenses];
                  list[index] = item;
                  await repo.updateFixedExpenses(list);
                }
              }

              Future<void> removeFixedExpense(int index) async {
                final list = [...s.fixedExpenses]..removeAt(index);
                await repo.updateFixedExpenses(list);
              }

              Future<void> editNotesBar() async {
                final n = await showDialog<NotesBar>(
                  context: context,
                  builder: (_) => EditNotesBarDialog(initial: s.notesBar),
                );
                if (n != null) {
                  await repo.updateNotesBar(n);
                }
              }

              // TODO: حماية عمليات إدارة الخطط في قواعد الأمان (Firestore rules).
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Prices
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Prices',
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                          onPressed: editPrices,
                          icon: const Icon(Icons.edit)),
                    ],
                  ),
                  Text('Hourly: ${s.hourly}'),
                  Text('Weekly: ${s.weekly}'),
                  Text('Monthly: ${s.monthly}'),
                  ListTile(
                    leading: const Icon(Icons.view_list_outlined),
                    title: const Text('إدارة الخطط'),
                    subtitle:
                    const Text('تعديل وتفعيل خطط الأسعار حسب الفئة'),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const PlansListDialog(),
                    ),
                  ),
                  // TODO: زر للمشرف لتشغيل ترحيل migrate_plans_v1 عند الحاجة.
                  const Divider(height: 32),

                  // Drinks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Drinks',
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                          onPressed: addDrink,
                          icon: const Icon(Icons.add)),
                    ],
                  ),
                  if (s.drinks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text('No drinks'),
                    ),
                  for (int i = 0; i < s.drinks.length; i++)
                    ListTile(
                      title: Text(s.drinks[i].name),
                      subtitle: Text('Price: ${s.drinks[i].price}'),
                      onTap: () => editDrink(i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: s.drinks[i].active,
                            onChanged: (v) => toggleDrink(i, v),
                          ),
                          IconButton(
                            onPressed: () => removeDrink(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 32),

                  // Fixed Expenses
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fixed Expenses',
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                          onPressed: addFixedExpense,
                          icon: const Icon(Icons.add)),
                    ],
                  ),
                  if (s.fixedExpenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text('No fixed expenses'),
                    ),
                  for (int i = 0; i < s.fixedExpenses.length; i++)
                    ListTile(
                      title: Text(s.fixedExpenses[i].name),
                      subtitle: Text('Amount: ${s.fixedExpenses[i].amount}'),
                      onTap: () => editFixedExpense(i),
                      trailing: IconButton(
                        onPressed: () => removeFixedExpense(i),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  const Divider(height: 32),

                  // Notes Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Notes Bar',
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                          onPressed: editNotesBar,
                          icon: const Icon(Icons.edit)),
                    ],
                  ),
                  Text(
                    s.notesBar.text.isNotEmpty
                        ? s.notesBar.text
                        : 'No active note',
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
