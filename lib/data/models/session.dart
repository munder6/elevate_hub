import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elevate_hub/data/models/subscription_category.dart';

class Session {
  final String id;
  final String memberId;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int minutes; // المحسوبة بالتقريب
  final num pricePerHourSnapshot;
  final num drinksTotal; // 0 الآن (هنربطه لاحقًا بالـ Orders)
  final num discount; // يدوي/كوبون لاحقًا
  final String paymentMethod; // cash | card | other | app | unpaid
  final num sessionAmount;
  final num grandTotal;
  final String status; // open | closed
  final String createdBy;
  final String? memberName;

  final String? planId;
  final SubscriptionCategory? category;
  final num? bandwidthMbpsSnapshot;

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
    required this.paymentMethod,
    required this.sessionAmount,
    required this.grandTotal,
    required this.status,
    required this.createdBy,
    this.memberName,
    this.planId,
    this.category,
    this.bandwidthMbpsSnapshot,
    this.paymentProofUrl,
    this.paymentProofUploadedAt,
    this.paymentProofUploadedBy,
  });

  factory Session.fromMap(String id, Map<String, dynamic> m) => Session(
    id: id,
    memberId: (m['memberId'] ?? '') as String,
    memberName: m['memberName'] as String?,
    checkInAt: DateTime.parse((m['checkInAt'] ?? DateTime.now().toIso8601String()) as String),
    checkOutAt: m['checkOutAt'] != null ? DateTime.parse(m['checkOutAt'] as String) : null,
    minutes: (m['minutes'] ?? 0) as int,
    pricePerHourSnapshot:
    (m['pricePerHourSnapshot'] ?? m['hourlyRateAtTime'] ?? 0) as num,
    drinksTotal: (m['drinksTotal'] ?? 0) as num,
    discount: (m['discount'] ?? 0) as num,
    paymentMethod: (m['paymentMethod'] ?? 'cash') as String,
    sessionAmount: (m['sessionAmount'] ?? 0) as num,
    grandTotal: (m['grandTotal'] ?? 0) as num,
    status: (m['status'] ?? 'open') as String,
    createdBy: (m['createdBy'] ?? '') as String,
    planId: m['planId'] as String?,
    category: subscriptionCategoryFromRaw(m['category']?.toString()),
    bandwidthMbpsSnapshot: m['bandwidthMbpsSnapshot'] as num?,
    paymentProofUrl: m['paymentProofUrl'] as String?,
    paymentProofUploadedAt: m['paymentProofUploadedAt'] != null
        ? DateTime.tryParse(m['paymentProofUploadedAt'] as String)
        : null,
    paymentProofUploadedBy: m['paymentProofUploadedBy'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    if (memberName != null) 'memberName': memberName,
    'checkInAt': checkInAt.toIso8601String(),
    if (checkOutAt != null) 'checkOutAt': checkOutAt!.toIso8601String(),
    'minutes': minutes,
    'hourlyRateAtTime': pricePerHourSnapshot,
    'pricePerHourSnapshot': pricePerHourSnapshot,
    'drinksTotal': drinksTotal,
    'discount': discount,
    'paymentMethod': paymentMethod,
    'sessionAmount': sessionAmount,
    'grandTotal': grandTotal,
    'status': status,
    'createdBy': createdBy,
    if (planId != null) 'planId': planId,
    if (category != null) 'category': category!.rawValue,
    if (bandwidthMbpsSnapshot != null)
      'bandwidthMbpsSnapshot': bandwidthMbpsSnapshot,

    // حقول إثبات الدفع (اختيارية)
    if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
    if (paymentProofUploadedAt != null)
      'paymentProofUploadedAt': paymentProofUploadedAt!.toIso8601String(),
    if (paymentProofUploadedBy != null) 'paymentProofUploadedBy': paymentProofUploadedBy,
  };

  num get hourlyRateAtTime => pricePerHourSnapshot;
}
