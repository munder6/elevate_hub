import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elevate_hub/data/models/subscription_category.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return int.tryParse('$value');
}

num? _asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return num.tryParse('$value');
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}

class Session {
  final String id;
  final String memberId;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int minutes; // المحسوبة بالتقريب
  final num pricePerHourSnapshot;
  final num drinksTotal; // 0 الآن (هنربطه لاحقًا بالـ Orders)
  final num discount; // يدوي/كوبون لاحقًا
  final String? _paymentMethod; // القيمة الخام كما هي مخزّنة
  final num sessionAmount;
  final num grandTotal;
  final String status; // open | closed
  final String createdBy;
  final String? memberName;

  final String? planId;
  /// raw string مثل 'daily' أو 'hours'...
  final String? category;
  final int? bandwidthMbpsSnapshot;
  final num? dailyPriceSnapshot;
  final String? dailyChargeRef;

  // حقول إثبات الدفع (جديدة)
  final String? paymentProofUrl;
  final DateTime? paymentProofUploadedAt;
  final String? paymentProofUploadedBy;

  Session({
    required this.id,
    required this.memberId,
    required this.checkInAt,
    required this.checkOutAt,
    required this.minutes,
    required this.pricePerHourSnapshot,
    required this.drinksTotal,
    required this.discount,
    required this.sessionAmount,
    required this.grandTotal,
    required this.status,
    required this.createdBy,
    String? paymentMethod,
    this.memberName,
    this.planId,
    this.category,
    this.bandwidthMbpsSnapshot,
    this.dailyPriceSnapshot,
    this.dailyChargeRef,
    this.paymentProofUrl,
    this.paymentProofUploadedAt,
    this.paymentProofUploadedBy,
  }) : _paymentMethod = paymentMethod;

  /// تحويل القيمة النصية للفئة إلى الـ enum (إن أمكن)
  SubscriptionCategory? get categoryEnum =>
      subscriptionCategoryFromRaw(category);

  /// قيمة طريقة الدفع مع افتراضي 'cash'
  String get paymentMethodValue => _paymentMethod ?? 'cash';

  /// إبقاء التوافق مع الاسم القديم
  String get paymentMethod => paymentMethodValue;

  factory Session.fromMap(String id, Map<String, dynamic> m) => Session(
    id: id,
    memberId: (m['memberId'] ?? '') as String,
    memberName: m['memberName'] as String?,
    checkInAt: _asDateTime(m['checkInAt']) ?? DateTime.now(),
    checkOutAt: _asDateTime(m['checkOutAt']),
    minutes: (m['minutes'] ?? 0) as int,
    pricePerHourSnapshot:
    (m['pricePerHourSnapshot'] ?? m['hourlyRateAtTime'] ?? 0) as num,
    drinksTotal: (m['drinksTotal'] ?? 0) as num,
    discount: (m['discount'] ?? 0) as num,
    paymentMethod: (m['paymentMethod'] as String?) ?? 'cash',
    sessionAmount: (m['sessionAmount'] ?? 0) as num,
    grandTotal: (m['grandTotal'] ?? 0) as num,
    status: (m['status'] ?? 'open') as String,
    createdBy: (m['createdBy'] ?? '') as String,
    planId: m['planId'] as String?,
    // نخزن القيمة خامة، والتحويل للـ enum يتم عبر getter أعلاه
    category: m['category']?.toString(),
    bandwidthMbpsSnapshot: _asInt(m['bandwidthMbpsSnapshot']),
    dailyPriceSnapshot:
    _asNum(m['dailyPriceSnapshot'] ?? m['sessionAmount']),
    dailyChargeRef: m['dailyChargeRef']?.toString(),
    paymentProofUrl: m['paymentProofUrl'] as String?,
    paymentProofUploadedAt: _asDateTime(m['paymentProofUploadedAt']),
    paymentProofUploadedBy: m['paymentProofUploadedBy'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    if (memberName != null) 'memberName': memberName,
    'checkInAt': checkInAt.toIso8601String(),
    if (checkOutAt != null) 'checkOutAt': checkOutAt!.toIso8601String(),
    'minutes': minutes,
    // الإبقاء على المفتاحين للتوافق الرجعي
    'hourlyRateAtTime': pricePerHourSnapshot,
    'pricePerHourSnapshot': pricePerHourSnapshot,
    'drinksTotal': drinksTotal,
    'discount': discount,
    'paymentMethod': paymentMethodValue,
    'sessionAmount': sessionAmount,
    'grandTotal': grandTotal,
    'status': status,
    'createdBy': createdBy,
    if (planId != null) 'planId': planId,
    if (category != null) 'category': category,
    if (bandwidthMbpsSnapshot != null)
      'bandwidthMbpsSnapshot': bandwidthMbpsSnapshot,
    if (dailyPriceSnapshot != null)
      'dailyPriceSnapshot': dailyPriceSnapshot,
    if (dailyChargeRef != null) 'dailyChargeRef': dailyChargeRef,

    // حقول إثبات الدفع (اختيارية)
    if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
    if (paymentProofUploadedAt != null)
      'paymentProofUploadedAt': paymentProofUploadedAt!.toIso8601String(),
    if (paymentProofUploadedBy != null)
      'paymentProofUploadedBy': paymentProofUploadedBy,
  };

  num get hourlyRateAtTime => pricePerHourSnapshot;
}
