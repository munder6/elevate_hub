import 'package:get/get.dart';

import '../modules/admin/admin_users_view.dart';
import '../modules/assets/assets_list_view.dart';
import '../modules/auth/activation_pending_view.dart';
import '../modules/auth/login_view.dart';
import '../modules/coupons/coupons_list_view.dart';
import '../modules/dashboard/dashboard_view.dart';
import '../modules/debts/debts_list_view.dart';
import '../modules/expenses/expenses_list_view.dart';
import '../modules/inventory/inventory_item_detail_view.dart';
import '../modules/inventory/inventory_list_view.dart';
import '../modules/inventory/low_stock_view.dart';
import '../modules/members/member_detail_view.dart';
import '../modules/members/members_list_view.dart';
import '../modules/orders/orders_list_view.dart';
import '../modules/reports/reports_view.dart';
import '../modules/sessions/sessions_overview_view.dart';
import '../modules/settings/settings_view.dart';
import '../modules/splash/splash_view.dart';
import '../wallet/wallets_list_view.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const activationPending = '/activation_pending';
  static const adminUsers = '/admin/users';
  static const settings = '/settings';
  static const members = '/members';
  static const debts = '/debts';
  static const orders = '/orders';
  static const memberDetail = '/members/detail';
  static const coupons = '/coupons';
  static const expenses = '/expenses';
  static const inventory = '/inventory';
  static const inventoryItem = '/inventory/item';
  static const inventoryLowStock = '/inventory/low';
  static const assets = '/assets';
  static const reports = '/reports';
  static const wallets = '/wallets';
  static const sessionsOverview = '/sessions_overview';


  static const String dashHome   = '/home';
  static const String dashMembers = '/members';
  static const String dashWallets = '/wallets';
  static const String dashOrders  = '/orders';
  static const String dashDebts   = '/debts';
  static const String dashReports = '/reports';
  static const String dashSettings = '/settings';


  static List<GetPage> pages = [
    GetPage(name: splash, page: () => const SplashView()),
    GetPage(name: login, page: () => const LoginView()),
    GetPage(name: dashboard, page: () => const DashboardView()),
    GetPage(name: activationPending, page: () => const ActivationPendingView()),
    GetPage(name: adminUsers, page: () => const AdminUsersView()),
    GetPage(name: settings, page: () => const SettingsView()),
    GetPage(name: members, page: () => const MembersListView()),
    GetPage(name: debts, page: () => const DebtsListView()),
    GetPage(name: orders, page: () => const OrdersListView()),
    GetPage(name: coupons, page: () => const CouponsListView()),
    GetPage(name: expenses, page: () => const ExpensesListView()),
    GetPage(name: inventory, page: () => const InventoryListView()),
    GetPage(name: assets, page: () => const AssetsListView()),
    GetPage(name: reports, page: () => const ReportsView()),
    GetPage(name: wallets, page: () => const WalletsListView()),
    GetPage(name: sessionsOverview, page: () => const SessionsOverviewView()),
    GetPage(name: inventoryItem, page: () {
      final id = Get.parameters['id'] ?? '';
      return InventoryItemDetailView(id: id);
    }),
    GetPage(name: inventoryLowStock, page: () => const LowStockView()),
    GetPage(
      name: memberDetail,
      page: () {
        // ناخذ id من query أو arguments
        final params = Get.parameters;
        final arg = Get.arguments;
        final id = (params['id'] as String?) ?? (arg as String?);
        return MemberDetailView(memberId: id ?? '');
      },
      transition: Transition.cupertino,
    ),

  ];
}

