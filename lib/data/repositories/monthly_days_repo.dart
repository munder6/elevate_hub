import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/monthly_day.dart';

class MonthlyDaysRepo {
  final fs = FirestoreService();
  CollectionReference<Map<String, dynamic>> get _col => fs.col('monthly_days');

  Stream<List<MonthlyDay>> watchByCycle(String cycleId) {
    return _col.where('cycleId', isEqualTo: cycleId)
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d)=>MonthlyDay.fromMap(d.id, d.data())).toList());
  }

  Future<MonthlyDay?> getOpenDay(String cycleId) async {
    final q = await _col.where('cycleId', isEqualTo: cycleId)
        .where('status', isEqualTo: 'open')
        .orderBy('startAt', descending: true)
        .limit(1).get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return MonthlyDay.fromMap(d.id, d.data());
  }

  Future<bool> existsForDate({required String cycleId, required String dateKey}) async {
    final q = await _col.where('cycleId', isEqualTo: cycleId)
        .where('dateKey', isEqualTo: dateKey)
        .limit(1).get();
    return q.docs.isNotEmpty;
  }
}
