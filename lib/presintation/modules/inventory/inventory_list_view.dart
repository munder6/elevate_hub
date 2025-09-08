import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/inventory_item.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/inventory_repo.dart';
import '../../routes/app_routes.dart';
import 'inventory_item_form_dialog.dart';

class InventoryListView extends StatefulWidget {
  const InventoryListView({super.key});

  @override
  State<InventoryListView> createState() => _InventoryListViewState();
}

class _InventoryListViewState extends State<InventoryListView> {
  final usersRepo = UsersRepo();
  final invRepo = InventoryRepo();
  bool showActiveOnly = true;
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Low stock',
            onPressed: () => Get.toNamed(AppRoutes.inventoryLowStock),
            icon: const Icon(Icons.report_gmailerrorred_outlined),
          ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: usersRepo.watchMe(),
        builder: (context, meSnap) {
          if (!meSnap.hasData) return const Center(child: CircularProgressIndicator());
          final me = meSnap.data!;
          if (!(me.perms.isAdmin || me.perms.inventory)) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox.shrink();
          }

          return StreamBuilder<List<InventoryItem>>(
            stream: invRepo.watchAll(activeOnly: showActiveOnly ? true : null),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              var items = snap.data!;
              if (search.trim().isNotEmpty) {
                final q = search.toLowerCase();
                items = items.where((e) =>
                e.name.toLowerCase().contains(q) ||
                    (e.sku ?? '').toLowerCase().contains(q) ||
                    (e.category ?? '').toLowerCase().contains(q)
                ).toList();
              }

              Future<void> add() async {
                final res = await showDialog<InventoryItem>(
                  context: context,
                  builder: (_) => const InventoryItemFormDialog(),
                );
                if (res != null) {
                  await invRepo.add(res);
                }
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search name/SKU/category',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(()=> search = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Active only'),
                          selected: showActiveOnly,
                          onSelected: (v)=> setState(()=> showActiveOnly = v),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: add,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  if (items.isEmpty)
                    const Expanded(child: Center(child: Text('No items')))
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final it = items[i];
                          return ListTile(
                            leading: it.isLow
                                ? const Icon(Icons.warning_amber, color: Colors.amber)
                                : const Icon(Icons.inventory_2_outlined),
                            title: Text(it.name),
                            subtitle: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (it.sku != null) Text('SKU: ${it.sku}'),
                                if (it.category != null) Text(it.category!),
                                Chip(
                                  label: Text('Stock: ${it.stock} ${it.unit} (min ${it.minStock})'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            onTap: () => Get.toNamed('${AppRoutes.inventoryItem}?id=${it.id}'),
                            trailing: Switch(
                              value: it.isActive,
                              onChanged: (v) => invRepo.toggleActive(it.id, v),
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
