import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_settings.dart';
import '../services/firestore_service.dart';

class SettingsRepo {
  final fs = FirestoreService();
  final String _docPath = 'settings/app';

  Stream<AppSettings?> watchSettings() {
    return fs.watchDoc(_docPath).map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppSettings.fromMap(snap.data()!);
    });
  }

  Future<void> updatePrices({num? hourly, num? weekly, num? monthly}) async {
    await fs.update(_docPath, {
      'prices.hourly': hourly,
      'prices.weekly': weekly,
      'prices.monthly': monthly,
    });
  }

  Future<void> updateDrinks(List<DrinkItem> drinks) async {
    await fs.update(_docPath, {
      'drinks': drinks.map((d) => d.toMap()).toList(),
    });
  }

  Future<void> updateFixedExpenses(List<FixedExpenseItem> list) async {
    await fs.update(_docPath, {
      'fixed_expenses': list.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> updateNotesBar(NotesBar n) async {
    await fs.update(_docPath, {
      'notes_bar': n.toMap(),
    });
  }
}
