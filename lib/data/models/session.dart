import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String memberId;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int minutes; // المحسوبة بالتقريب
  final num hourlyRateAtTime;
  final num drinksTotal; // 0 الآن (هنربطه لاحقًا بالـ Orders)
  final num discount; // يدوي/كوبون لاحقًا
  final String paymentMethod; // cash | card | other | app | unpaid
  final num sessionAmount;
  final num grandTotal;
  final String status; // open | closed
  final String createdBy;
  final String? memberName;

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
    required this.hourlyRateAtTime,
    required this.drinksTotal,
    required this.discount,
    required this.paymentMethod,
    required this.sessionAmount,
    required this.grandTotal,
    required this.status,
    required this.createdBy,
    this.memberName,
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
    hourlyRateAtTime: (m['hourlyRateAtTime'] ?? 0) as num,
    drinksTotal: (m['drinksTotal'] ?? 0) as num,
    discount: (m['discount'] ?? 0) as num,
    paymentMethod: (m['paymentMethod'] ?? 'cash') as String,
    sessionAmount: (m['sessionAmount'] ?? 0) as num,
    grandTotal: (m['grandTotal'] ?? 0) as num,
    status: (m['status'] ?? 'open') as String,
    createdBy: (m['createdBy'] ?? '') as String,
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
    'hourlyRateAtTime': hourlyRateAtTime,
    'drinksTotal': drinksTotal,
    'discount': discount,
    'paymentMethod': paymentMethod,
    'sessionAmount': sessionAmount,
    'grandTotal': grandTotal,
    'status': status,
    'createdBy': createdBy,

    // حقول إثبات الدفع (اختيارية)
    if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
    if (paymentProofUploadedAt != null)
      'paymentProofUploadedAt': paymentProofUploadedAt!.toIso8601String(),
    if (paymentProofUploadedBy != null) 'paymentProofUploadedBy': paymentProofUploadedBy,
  };
}
