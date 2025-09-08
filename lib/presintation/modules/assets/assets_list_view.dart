import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/asset.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/assets_repo.dart';
import '../../routes/app_routes.dart';
import 'asset_form_dialog.dart';

class AssetsListView extends StatefulWidget {
  const AssetsListView({super.key});

  @override
  State<AssetsListView> createState() => _AssetsListViewState();
}

class _AssetsListViewState extends State<AssetsListView> {
  final usersRepo = UsersRepo();
  final repo = AssetsRepo();

  bool activeOnly = true;
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
      body: StreamBuilder<AppUser?>(
        stream: usersRepo.watchMe(),
        builder: (context, meSnap) {
          if (!meSnap.hasData) return const Center(child: CircularProgressIndicator());
          final me = meSnap.data!;
          // حسب الـ spec: Admin فقط (أو perms.assets لو مفعّل)
          if (!(me.perms.isAdmin || me.perms.assets)) {
            Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
            return const SizedBox.shrink();
          }

          return StreamBuilder<List<AssetModel>>(
            stream: repo.watchAll(activeOnly: activeOnly ? true : null),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              var items = snap.data!;

              if (search.trim().isNotEmpty) {
                final q = search.toLowerCase();
                items = items.where((a) =>
                a.name.toLowerCase().contains(q) ||
                    (a.category ?? '').toLowerCase().contains(q)).toList();
              }

              Future<void> addOrEdit([AssetModel? initial]) async {
                final res = await showDialog<AssetModel>(
                  context: context,
                  builder: (_) => AssetFormDialog(initial: initial),
                );
                if (res == null) return;
                if (initial == null) {
                  await repo.add(res);
                } else {
                  await repo.update(res.copyWith(id: initial.id));
                }
              }

              final totalActiveValue = items
                  .where((a) => a.active)
                  .fold<num>(0, (sum, a) => sum + a.value);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Search by name/category',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (v) => setState(() => search = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Active only'),
                          selected: activeOnly,
                          onSelected: (v) => setState(() => activeOnly = v),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => addOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: const Text('Total active value'),
                    trailing: Text('$totalActiveValue'),
                  ),
                  const Divider(height: 0),
                  if (items.isEmpty)
                    const Expanded(child: Center(child: Text('No assets')))
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final a = items[i];
                          return ListTile(
                            leading: const Icon(Icons.chair_alt),
                            title: Text(a.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (a.category != null) Text(a.category!),
                                Text('Value: ${a.value}'),
                                Text('Purchased: ${a.purchaseDate?.toIso8601String().substring(0,10) ?? '—'}'),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                Switch(
                                  value: a.active,
                                  onChanged: (v) => repo.toggleActive(a.id, v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => addOrEdit(a),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => repo.delete(a.id),
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
