import 'subscription_category.dart';

class Plan {
  final String id;
  final String title;
  final SubscriptionCategory category;
  final int bandwidthMbps;
  final int daysCount;
  final num price;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Plan({
    required this.id,
    required this.title,
    required this.category,
    required this.bandwidthMbps,
    required this.daysCount,
    required this.price,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  Plan copyWith({
    String? id,
    String? title,
    SubscriptionCategory? category,
    int? bandwidthMbps,
    int? daysCount,
    num? price,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Plan(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      bandwidthMbps: bandwidthMbps ?? this.bandwidthMbps,
      daysCount: daysCount ?? this.daysCount,
      price: price ?? this.price,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Plan.fromMap(String id, Map<String, dynamic> data) {
    final category =
        subscriptionCategoryFromRaw(data['category']?.toString()) ??
            SubscriptionCategory.hours;
    return Plan(
      id: id,
      title: (data['title'] ?? '') as String,
      category: category,
      bandwidthMbps: (data['bandwidthMbps'] ?? 0) as int,
      daysCount: (data['daysCount'] ?? 0) as int,
      price: (data['price'] ?? 0) as num,
      active: (data['active'] ?? true) as bool,
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamps = true}) {
    return {
      'title': title,
      'category': category.rawValue,
      'bandwidthMbps': bandwidthMbps,
      'daysCount': daysCount,
      'price': price,
      'active': active,
      if (includeTimestamps && createdAt != null)
        'createdAt': createdAt!.toIso8601String(),
      if (includeTimestamps && updatedAt != null)
        'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  num get dayCostSnapshot =>
      daysCount > 0 ? price / daysCount : price;

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}