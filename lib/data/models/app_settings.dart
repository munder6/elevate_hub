import 'package:cloud_firestore/cloud_firestore.dart';

class DrinkItem {
  final String name;
  final num price;
  final bool active;

  DrinkItem({
    required this.name,
    required this.price,
    required this.active,
  });

  factory DrinkItem.fromMap(Map<String, dynamic> m) {
    return DrinkItem(
      name: m['name'] ?? '',
      price: m['price'] ?? 0,
      active: m['active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'active': active,
  };
}

class FixedExpenseItem {
  final String name;
  final num amount;

  FixedExpenseItem({required this.name, required this.amount});

  factory FixedExpenseItem.fromMap(Map<String, dynamic> m) {
    return FixedExpenseItem(
      name: m['name'] ?? '',
      amount: m['amount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'amount': amount,
  };
}

class NotesBar {
  final String text;
  final String priority; // info | warn | alert
  final DateTime? startAt;
  final DateTime? endAt;
  final bool active;

  NotesBar({
    required this.text,
    required this.priority,
    this.startAt,
    this.endAt,
    required this.active,
  });

  factory NotesBar.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return NotesBar(text: '', priority: 'info', active: false);
    }
    return NotesBar(
      text: m['text'] ?? '',
      priority: m['priority'] ?? 'info',
      startAt: _toDate(m['startAt']),
      endAt: _toDate(m['endAt']),
      active: m['active'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'priority': priority,
    if (startAt != null) 'startAt': startAt,
    if (endAt != null) 'endAt': endAt,
    'active': active,
  };

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

class AppSettings {
  final num hourly;
  final num weekly;
  final num monthly;
  final List<DrinkItem> drinks;
  final List<FixedExpenseItem> fixedExpenses;
  final NotesBar notesBar;

  AppSettings({
    required this.hourly,
    required this.weekly,
    required this.monthly,
    required this.drinks,
    required this.fixedExpenses,
    required this.notesBar,
  });

  factory AppSettings.fromMap(Map<String, dynamic> m) {
    return AppSettings(
      hourly: m['prices']?['hourly'] ?? 0,
      weekly: m['prices']?['weekly'] ?? 0,
      monthly: m['prices']?['monthly'] ?? 0,
      drinks: (m['drinks'] as List<dynamic>? ?? [])
          .map((e) => DrinkItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      fixedExpenses: (m['fixed_expenses'] as List<dynamic>? ?? [])
          .map((e) => FixedExpenseItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      notesBar: NotesBar.fromMap(
          m['notes_bar'] != null ? Map<String, dynamic>.from(m['notes_bar']) : null),
    );
  }


}
