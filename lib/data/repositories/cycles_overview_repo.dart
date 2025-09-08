import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weekly_cycle.dart';
import '../models/monthly_cycle.dart';
import '../services/firestore_service.dart';
import '../utils/date_ranges.dart';

class CyclesOverviewSummary {
  final int count;
  final num collected; // dayCost * daysUsed
  final num drinks;    // drinksTotal
  final num total;     // collected + drinks
  const CyclesOverviewSummary({
    required this.count,
    required this.collected,
    required this.drinks,
    required this.total,
  });
}

class CyclesOverviewRepo {
  final fs = FirestoreService();
  CollectionReference<Map<String, dynamic>> get _weekly => fs.col('weekly_cycles');
  CollectionReference<Map<String, dynamic>> get _monthly => fs.col('monthly_cycles');

  /* ---------------------------- Weekly ---------------------------- */
  Stream<List<WeeklyCycle>> watchWeeklyBetween(DateTime start, DateTime end, {String? status}) {
    final qs = _weekly
        .orderBy('startDate', descending: true)
        .where('startDate', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('startDate', isLessThanOrEqualTo: end.toIso8601String())
        .snapshots();

    return qs.map((q) {
      final all = q.docs.map((d) => WeeklyCycle.fromMap(d.id, d.data())).toList();
      return status == null ? all : all.where((c) => c.status == status).toList();
    });
  }

  Stream<CyclesOverviewSummary> weeklySummaryBetween(DateTime start, DateTime end, {String? status}) {
    return watchWeeklyBetween(start, end, status: status).map((list) {
      final count = list.length;
      num collected = 0, drinks = 0;
      for (final c in list) {
        collected += c.dayCost * c.daysUsed;
        drinks += c.drinksTotal;
      }
      return CyclesOverviewSummary(count: count, collected: collected, drinks: drinks, total: collected + drinks);
    });
  }

  Stream<List<WeeklyCycle>> watchWeeklyToday({String? status}) {
    final now = DateTime.now();
    return watchWeeklyBetween(now.dayStart, now.dayEnd, status: status);
  }
  Stream<List<WeeklyCycle>> watchWeeklyThisWeek({String? status}) {
    final now = DateTime.now();
    return watchWeeklyBetween(now.weekStart, now.weekEnd, status: status);
  }
  Stream<List<WeeklyCycle>> watchWeeklyThisMonth({String? status}) {
    final now = DateTime.now();
    return watchWeeklyBetween(now.monthStart, now.monthEnd, status: status);
  }

  Stream<CyclesOverviewSummary> weeklyTodaySummary({String? status}) {
    final now = DateTime.now();
    return weeklySummaryBetween(now.dayStart, now.dayEnd, status: status);
  }
  Stream<CyclesOverviewSummary> weeklyThisWeekSummary({String? status}) {
    final now = DateTime.now();
    return weeklySummaryBetween(now.weekStart, now.weekEnd, status: status);
  }
  Stream<CyclesOverviewSummary> weeklyThisMonthSummary({String? status}) {
    final now = DateTime.now();
    return weeklySummaryBetween(now.monthStart, now.monthEnd, status: status);
  }

  /* ---------------------------- Monthly --------------------------- */
  Stream<List<MonthlyCycle>> watchMonthlyBetween(DateTime start, DateTime end, {String? status}) {
    final qs = _monthly
        .orderBy('startDate', descending: true)
        .where('startDate', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('startDate', isLessThanOrEqualTo: end.toIso8601String())
        .snapshots();

    return qs.map((q) {
      final all = q.docs.map((d) => MonthlyCycle.fromMap(d.id, d.data())).toList();
      return status == null ? all : all.where((c) => c.status == status).toList();
    });
  }

  Stream<CyclesOverviewSummary> monthlySummaryBetween(DateTime start, DateTime end, {String? status}) {
    return watchMonthlyBetween(start, end, status: status).map((list) {
      final count = list.length;
      num collected = 0, drinks = 0;
      for (final c in list) {
        collected += c.dayCost * c.daysUsed;
        drinks += c.drinksTotal;
      }
      return CyclesOverviewSummary(count: count, collected: collected, drinks: drinks, total: collected + drinks);
    });
  }

  Stream<List<MonthlyCycle>> watchMonthlyToday({String? status}) {
    final now = DateTime.now();
    return watchMonthlyBetween(now.dayStart, now.dayEnd, status: status);
  }
  Stream<List<MonthlyCycle>> watchMonthlyThisWeek({String? status}) {
    final now = DateTime.now();
    return watchMonthlyBetween(now.weekStart, now.weekEnd, status: status);
  }
  Stream<List<MonthlyCycle>> watchMonthlyThisMonth({String? status}) {
    final now = DateTime.now();
    return watchMonthlyBetween(now.monthStart, now.monthEnd, status: status);
  }

  Stream<CyclesOverviewSummary> monthlyTodaySummary({String? status}) {
    final now = DateTime.now();
    return monthlySummaryBetween(now.dayStart, now.dayEnd, status: status);
  }
  Stream<CyclesOverviewSummary> monthlyThisWeekSummary({String? status}) {
    final now = DateTime.now();
    return monthlySummaryBetween(now.weekStart, now.weekEnd, status: status);
  }
  Stream<CyclesOverviewSummary> monthlyThisMonthSummary({String? status}) {
    final now = DateTime.now();
    return monthlySummaryBetween(now.monthStart, now.monthEnd, status: status);
  }
}
