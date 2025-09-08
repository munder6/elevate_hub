import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/inventory_item.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/repositories/inventory_repo.dart';
import '../../routes/app_routes.dart';

class LowStockView extends StatelessWidget {
  const LowStockView({super.key});

  @override
  Widget build(BuildContext context) {
    final usersRepo = UsersRepo();
    final invRepo = InventoryRepo();

    return Scaffold(
      appBar: AppBar(title: const Text('Low stock')),
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
            stream: invRepo.watchAll(activeOnly: true),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final low = snap.data!.where((e)=> e.isLow).toList();
              if (low.isEmpty) return const Center(child: Text('All good 👌'));

              return ListView.separated(
                itemCount: low.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final it = low[i];
                  return ListTile(
                    leading: const Icon(Icons.warning_amber, color: Colors.amber),
                    title: Text(it.name),
                    subtitle: Text('Stock: ${it.stock} / Min: ${it.minStock} ${it.unit}'),
                    trailing: TextButton(
                      onPressed: ()=> Get.toNamed('${AppRoutes.inventoryItem}?id=${it.id}'),
                      child: const Text('Details'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
