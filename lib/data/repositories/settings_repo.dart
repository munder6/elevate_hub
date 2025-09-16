// lib/data/repositories/settings_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_settings.dart';

class SettingsRepo {
  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _doc => _db.doc('settings/app');

  /// Ensure the document exists (idempotent).
  Future<void> ensureExists() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set({
        'prices': {'hourly': 0, 'weekly': 0, 'monthly': 0},
        'drinks': <Map<String, dynamic>>[],
        'fixed_expenses': <Map<String, dynamic>>[],
        'notes_bar': {
          'text': '',
          'priority': 'info',
          'active': false,
        },
      }, SetOptions(merge: true));
    }
  }

  Stream<AppSettings?> watchSettings() {
    return _doc.snapshots().map((s) {
      if (!s.exists) return null;
      return AppSettings.fromMap(s.data() ?? {});
    });
  }

  Future<void> updatePrices({num? hourly, num? weekly, num? monthly}) async {
    await ensureExists();
    final Map<String, dynamic> data = {};
    if (hourly != null || weekly != null || monthly != null) {
      data['prices'] = {
        if (hourly != null) 'hourly': hourly,
        if (weekly != null) 'weekly': weekly,
        if (monthly != null) 'monthly': monthly,
      };
    }
    if (data.isNotEmpty) {
      await _doc.set(data, SetOptions(merge: true)); // upsert
    }
  }

  Future<void> updateDrinks(List<DrinkItem> drinks) async {
    await ensureExists();
    await _doc.set({
      'drinks': drinks.map((d) => d.toMap()).toList(),
    }, SetOptions(merge: true)); // upsert
  }

  Future<void> updateFixedExpenses(List<FixedExpenseItem> items) async {
    await ensureExists();
    await _doc.set({
      'fixed_expenses': items.map((e) => e.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  Future<void> updateNotesBar(NotesBar notes) async {
    await ensureExists();
    await _doc.set({
      'notes_bar': notes.toMap(),
    }, SetOptions(merge: true));
  }
}
