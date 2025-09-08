import 'package:get/get.dart';

import '../../../data/models/session.dart';
import '../../../data/repositories/sessions_repo.dart';

import '../../../data/models/weekly_cycle.dart';
import '../../../data/models/monthly_cycle.dart';
import '../../../data/repositories/cycles_overview_repo.dart';

class SessionsController extends GetxController {
  final SessionsRepo sessionsRepo;
  final cyclesRepo = CyclesOverviewRepo();

  SessionsController(this.sessionsRepo);

  final tabIndex = 0.obs;
  void setTab(int i) => tabIndex.value = i;

  // -------- Hourly (sessions) --------
  Stream<SessionsSummary> get daySummary   => sessionsRepo.watchTodaySummary(status: 'closed');
  Stream<SessionsSummary> get weekSummary  => sessionsRepo.watchThisWeekSummary(status: 'closed');
  Stream<SessionsSummary> get monthSummary => sessionsRepo.watchThisMonthSummary(status: 'closed');

  Stream<List<Session>> get daySessions    => sessionsRepo.watchToday(status: 'closed');
  Stream<List<Session>> get weekSessions   => sessionsRepo.watchThisWeek(status: 'closed');
  Stream<List<Session>> get monthSessions  => sessionsRepo.watchThisMonth(status: 'closed');

  // -------- Weekly cycles (overview-only) --------
  Stream<CyclesOverviewSummary> get wDaySummary    => cyclesRepo.weeklyTodaySummary(status: 'active');
  Stream<CyclesOverviewSummary> get wWeekSummary   => cyclesRepo.weeklyThisWeekSummary(status: 'active');
  Stream<CyclesOverviewSummary> get wMonthSummary  => cyclesRepo.weeklyThisMonthSummary(status: 'active');

  Stream<List<WeeklyCycle>> get wDayList   => cyclesRepo.watchWeeklyToday(status: 'active');
  Stream<List<WeeklyCycle>> get wWeekList  => cyclesRepo.watchWeeklyThisWeek(status: 'active');
  Stream<List<WeeklyCycle>> get wMonthList => cyclesRepo.watchWeeklyThisMonth(status: 'active');

  // -------- Monthly cycles (overview-only) --------
  Stream<CyclesOverviewSummary> get mDaySummary    => cyclesRepo.monthlyTodaySummary(status: 'active');
  Stream<CyclesOverviewSummary> get mWeekSummary   => cyclesRepo.monthlyThisWeekSummary(status: 'active');
  Stream<CyclesOverviewSummary> get mMonthSummary  => cyclesRepo.monthlyThisMonthSummary(status: 'active');

  Stream<List<MonthlyCycle>> get mDayList   => cyclesRepo.watchMonthlyToday(status: 'active');
  Stream<List<MonthlyCycle>> get mWeekList  => cyclesRepo.watchMonthlyThisWeek(status: 'active');
  Stream<List<MonthlyCycle>> get mMonthList => cyclesRepo.watchMonthlyThisMonth(status: 'active');
}
