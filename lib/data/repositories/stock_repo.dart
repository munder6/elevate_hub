import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/stock_movement.dart';

class StockRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _items => fs.col('inventory_items');
  CollectionReference<Map<String, dynamic>> get _movs => fs.col('stock_movements');

  // Watch movements for an item
  Stream<List<StockMovement>> watchByItem(String invId) {
    return _movs
        .where('invId', isEqualTo: invId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => StockMovement.fromMap(d.id, d.data())).toList());
  }

  /// عملية حركة مخزون (in/out/adjust) مع تحديث stock داخل Transaction
  Future<void> addMovement({
    required String invId,
    required String type, // 'in' | 'out' | 'adjust'
    required num qty,
    String? reason,
    String? refType,
    String? refId,
  }) async {
    final uid = auth.currentUser?.uid ?? 'system';
    final nowIso = DateTime.now().toIso8601String();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final itemRef = _items.doc(invId);
      final itemSnap = await tx.get(itemRef);
      final m = itemSnap.data() as Map<String, dynamic>?;
      if (m == null) throw Exception('Item not found');

      final before = (m['stock'] ?? 0) as num;

      num after;
      switch (type) {
        case 'in':
          after = before + qty;
          break;
        case 'out':
          after = (before - qty);
          if (after < 0) after = 0; // ما ننزل عن الصفر
          break;
        case 'adjust':
          after = qty; // qty هنا يمثل القيمة النهائية
          break;
        default:
          throw Exception('Invalid movement type');
      }

      tx.update(itemRef, {'stock': after});

      final movRef = _movs.doc();
      tx.set(movRef, {
        'invId': invId,
        'type': type,
        'qty': qty,
        'reason': reason,
        if (refType != null) 'refType': refType,
        if (refId != null) 'refId': refId,
        'before': before,
        'after': after,
        'createdAt': nowIso,
        'createdBy': uid,
      });
    });
  }
}
