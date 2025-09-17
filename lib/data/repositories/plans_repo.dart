import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/plan.dart';
import '../models/subscription_category.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class PlansRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  Future<Plan?> getPlanOnce(String id) => getById(id);

  CollectionReference<Map<String, dynamic>> get _col => fs.col('plans');

  Stream<List<Plan>> watchAll() {
    return _col.orderBy('category').orderBy('bandwidthMbps').snapshots().map(
          (q) => q.docs.map((d) => Plan.fromMap(d.id, d.data())).toList(),
    );
  }

  Stream<List<Plan>> watchByCategory(SubscriptionCategory category,
      {bool onlyActive = false}) {
    Query<Map<String, dynamic>> query =
    _col.where('category', isEqualTo: category.rawValue);
    if (onlyActive) {
      query = query.where('active', isEqualTo: true);
    }
    return query.orderBy('bandwidthMbps').snapshots().map(
          (q) => q.docs.map((d) => Plan.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<List<Plan>> fetchActiveByCategory(SubscriptionCategory category) async {
    final snap = await _col
        .where('category', isEqualTo: category.rawValue)
        .where('active', isEqualTo: true)
        .orderBy('bandwidthMbps')
        .get();
    return snap.docs.map((d) => Plan.fromMap(d.id, d.data())).toList();
  }

  Future<Plan?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Plan.fromMap(doc.id, doc.data()!);
  }

  Future<Plan> requireActivePlan(
      String planId, {
        List<SubscriptionCategory>? allowedCategories,
      }) async {
    final plan = await getById(planId);
    if (plan == null) {
      throw Exception('Plan not found');
    }
    if (!plan.active) {
      throw Exception('Plan is not active');
    }
    if (allowedCategories != null &&
        allowedCategories.isNotEmpty &&
        !allowedCategories.contains(plan.category)) {
      throw Exception('Plan category not allowed for this action');
    }
    return plan;
  }

  Future<String> create(Plan plan) async {
    final now = DateTime.now();
    final doc = _col.doc();
    final data = plan
        .copyWith(id: doc.id, createdAt: now, updatedAt: now)
        .toMap();
    await doc.set({
      ...data,
      'createdBy': auth.currentUser?.uid,
      'updatedBy': auth.currentUser?.uid,
    });
    return doc.id;
  }

  Future<void> update(Plan plan) async {
    final now = DateTime.now();
    await _col.doc(plan.id).set({
      ...plan.copyWith(updatedAt: now).toMap(),
      'updatedBy': auth.currentUser?.uid,
    }, SetOptions(merge: true));
  }

  Future<void> setActive(String planId, bool active) async {
    final now = DateTime.now();
    await _col.doc(planId).update({
      'active': active,
      'updatedAt': now.toIso8601String(),
      'updatedBy': auth.currentUser?.uid,
    });
  }
}