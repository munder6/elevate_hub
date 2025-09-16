enum SubscriptionCategory { hours, daily, weekly, monthly }

extension SubscriptionCategoryX on SubscriptionCategory {
  String get rawValue {
    switch (this) {
      case SubscriptionCategory.hours:
        return 'HOURS';
      case SubscriptionCategory.daily:
        return 'DAILY';
      case SubscriptionCategory.weekly:
        return 'WEEKLY';
      case SubscriptionCategory.monthly:
        return 'MONTHLY';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionCategory.hours:
        return 'بالساعة';
      case SubscriptionCategory.daily:
        return 'يومي';
      case SubscriptionCategory.weekly:
        return 'أسبوعي';
      case SubscriptionCategory.monthly:
        return 'شهري';
    }
  }

  bool get requiresDaysCount => this != SubscriptionCategory.hours;

  int? get enforcedDaysCount {
    switch (this) {
      case SubscriptionCategory.hours:
        return 0;
      case SubscriptionCategory.daily:
        return 1;
      case SubscriptionCategory.weekly:
        return null; // > 0
      case SubscriptionCategory.monthly:
        return null; // > 0
    }
  }
}

SubscriptionCategory? subscriptionCategoryFromRaw(String? raw) {
  if (raw == null) return null;
  switch (raw.toUpperCase()) {
    case 'HOURS':
      return SubscriptionCategory.hours;
    case 'DAILY':
      return SubscriptionCategory.daily;
    case 'WEEKLY':
      return SubscriptionCategory.weekly;
    case 'MONTHLY':
      return SubscriptionCategory.monthly;
    default:
      return null;
  }
}

List<SubscriptionCategory> get allSubscriptionCategories =>
    SubscriptionCategory.values;