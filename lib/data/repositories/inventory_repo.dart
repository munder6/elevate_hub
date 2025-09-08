import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/inventory_item.dart';

class InventoryRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('inventory_items');

  // Watch
  Stream<List<InventoryItem>> watchAll({bool? activeOnly}) {
    final q = _col.orderBy('name');
    return q.snapshots().map((s) {
      final list = s.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList();
      if (activeOnly == null) return list;
      return list.where((e) => e.isActive == activeOnly).toList();
    });
  }

  Stream<InventoryItem?> watchOne(String id) {
    return _col.doc(id).snapshots().map((ds) {
      final m = ds.data();
      if (!ds.exists || m == null) return null;
      return InventoryItem.fromMap(ds.id, m);
    });
  }

  // CRUD
  Future<String> add(InventoryItem item) async {
    final doc = await _col.add(item.toMap());
    return doc.id;
  }

  Future<void> update(InventoryItem item) async {
    await fs.update('inventory_items/${item.id}', item.toMap());
  }

  Future<void> toggleActive(String id, bool active) async {
    await fs.update('inventory_items/$id', {'isActive': active});
  }
}
