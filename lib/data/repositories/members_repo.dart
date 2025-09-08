import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import '../services/firestore_service.dart';

class MembersRepo {
  final fs = FirestoreService();
  CollectionReference<Map<String, dynamic>> get _col => fs.col('members');

  Stream<List<Member>> watchAll({bool includeInactive = true}) {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (q) => q.docs.map((d) => Member.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<void> add(Member m) async {
    await _col.add({
      'name': m.name,
      'phone': m.phone,
      'notes': m.notes,
      'isActive': m.isActive,
      'preferredPlan': m.preferredPlan, // 👈
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getMemberName(String memberId) async {
    final snap = await fs.getDoc('members/$memberId');
    final m = snap.data();
    return m == null ? null : (m['name'] as String?) ?? '';
  }

  Future<void> update(Member m) async {
    await fs.update('members/${m.id}', {
      'name': m.name,
      'phone': m.phone,
      'notes': m.notes,
      'isActive': m.isActive,
      'preferredPlan': m.preferredPlan, // 👈
    });
  }

  Stream<Member?> watchOne(String id) {
    return fs.watchDoc('members/$id').map((d) {
      final m = d.data();
      if (!d.exists || m == null) return null;
      return Member.fromMap(d.id, m);
    });
  }

  Future<void> delete(String id) async {
    final batch = FirebaseFirestore.instance.batch();
    // delete member document
    batch.delete(fs.doc('members/$id'));
    // delete wallet document
    batch.delete(fs.doc('wallets/$id'));

    // delete wallet transactions for this member
    final walletTx = await fs
        .col('wallet_tx')
        .where('memberId', isEqualTo: id)
        .get();
    for (final d in walletTx.docs) {
      batch.delete(d.reference);
    }

    // delete debts for this member
    final debts = await fs.col('debts').where('memberId', isEqualTo: id).get();
    for (final d in debts.docs) {
      batch.delete(d.reference);
    }

    await batch.commit();
  }
}
