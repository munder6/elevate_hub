import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/inventory_item.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/inventory_repo.dart';
import '../../../data/repositories/stock_repo.dart';
import '../../routes/app_routes.dart';
import 'inventory_item_form_dialog.dart';
import 'stock_movement_form.dart';

class InventoryItemDetailView extends StatelessWidget {
  final String id;
  const InventoryItemDetailView({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final usersRepo = UsersRepo();
    final invRepo = InventoryRepo();
    final stockRepo = StockRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Item detail')),
      body: StreamBuilder<AppUser?>(
        stream: usersRepo.watchMe(),
        builder: (context, meSnap) {
          if (!meSnap.hasData) return const Center(child: CircularProgressIndicator());
          final me = meSnap.data!;
          if (!(me.perms.isAdmin || me.perms.inventory)) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox.shrink();
          }

          return StreamBuilder<InventoryItem?>(
            stream: invRepo.watchOne(id),
            builder: (context, itemSnap) {
              if (!itemSnap.hasData) return const Center(child: CircularProgressIndicator());
              final item = itemSnap.data;
              if (item == null) return const Center(child: Text('Item not found'));

              Future<void> edit() async {
                final res = await showDialog<InventoryItem>(
                  context: context,
                  builder: (_) => InventoryItemFormDialog(initial: item),
                );
                if (res != null) {
                  await invRepo.update(res.copyWith(id: item.id));
                }
              }

              Future<void> newMovement() async {
                final data = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => StockMovementForm(invId: item.id),
                );
                if (data != null) {
                  await stockRepo.addMovement(
                    invId: item.id,
                    type: data['type'],
                    qty: data['qty'],
                    reason: data['reason'],
                  );
                }
              }

              return Column(
                children: [
                  ListTile(
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.sku != null) Text('SKU: ${item.sku}'),
                        if (item.category != null) Text('Category: ${item.category}'),
                        Text('Unit: ${item.unit}'),
                        Text('Stock: ${item.stock} (min: ${item.minStock})'),
                        if (item.costPrice != null) Text('Cost: ${item.costPrice}'),
                        if (item.salePrice != null) Text('Sale: ${item.salePrice}'),
                        Text('Active: ${item.isActive}'),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(onPressed: edit, icon: const Icon(Icons.edit)),
                        FilledButton.icon(
                          onPressed: newMovement,
                          icon: const Icon(Icons.move_up_rounded),
                          label: const Text('Movement'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  const ListTile(title: Text('Movements')),
                  Expanded(
                    child: StreamBuilder<List<StockMovement>>(
                      stream: stockRepo.watchByItem(item.id),
                      builder: (context, movSnap) {
                        if (!movSnap.hasData) return const Center(child: CircularProgressIndicator());
                        final list = movSnap.data!;
                        if (list.isEmpty) return const Center(child: Text('No movements yet'));
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (_, i) {
                            final m = list[i];
                            return ListTile(
                              leading: Icon(
                                m.type == 'in'
                                    ? Icons.add_circle_outline
                                    : m.type == 'out'
                                    ? Icons.remove_circle_outline
                                    : Icons.tune,
                              ),
                              title: Text('${m.type.toUpperCase()} — qty: ${m.qty}'),
                              subtitle: Text('Before ${m.before} → After ${m.after}'
                                  '${m.reason != null ? '\n${m.reason}' : ''}'),
                              trailing: Text(m.createdAt?.substring(0, 16) ?? ''),
                            );
                          },
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
