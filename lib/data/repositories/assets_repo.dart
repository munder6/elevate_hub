import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/asset.dart';

class AssetsRepo {
  final fs = FirestoreService();

  CollectionReference<Map<String, dynamic>> get _col => fs.col('assets');

  // قراءة كل الأصول (نفلتر Active على العميل لتجنب فهرس مركّب)
  Stream<List<AssetModel>> watchAll({bool? activeOnly}) {
    final q = _col.orderBy('purchaseDate', descending: true);
    return q.snapshots().map((s) {
      var list = s.docs.map((d) => AssetModel.fromMap(d.id, d.data())).toList();
      if (activeOnly != null) {
        list = list.where((a) => a.active == activeOnly).toList();
      }
      return list;
    });
  }

  Future<String> add(AssetModel a) async {
    final doc = await _col.add(a.toMap());
    return doc.id;
  }

  Future<void> update(AssetModel a) async {
    await fs.update('assets/${a.id}', a.toMap());
  }

  Future<void> toggleActive(String id, bool active) async {
    await fs.update('assets/$id', {'active': active});
  }

  Future<void> delete(String id) async {
    await fs.delete('assets/$id');
  }
}
