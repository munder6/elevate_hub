import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';

import '../../../../controller/app_controller.dart';
import '../../presintation/routes/app_routes.dart';

class WebShell extends StatelessWidget {
  const WebShell({super.key});

  @override
  Widget build(BuildContext context) {
    assert(kIsWeb, 'WebShell is intended for web only');
    final theme = Theme.of(context);
    final app = Get.find<AppController>();

    return Scaffold(
      body: Row(
        children: [
          // ==== ثابت: Sidebar ====
          _WebSidebar(
            onSelect: (route) => Get.rootDelegate.toNamed(
              AppRoutes.dashboard + route,
            ),
            selectedRoute: Get.currentRoute, // هتفيد بالتظليل
          ),

          // ==== ثابت: AppBar + Body Outlet ====
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 64,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: theme.colorScheme.surface.withOpacity(0.6),
                      ),
                    ),
                  ),
                  titleSpacing: 16,
                  title: Row(
                    children: [
                      Icon(Icons.dashboard_customize_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Dashboard',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Obx(() => Tooltip(
                        message: app.firebaseReady.value
                            ? 'Cloud: Connected'
                            : 'Cloud: Offline',
                        child: Icon(
                          app.firebaseReady.value
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                        ),
                      )),
                    ],
                  ),
                ),

                // ==== هنا يتبدّل المحتوى فقط ====
                SliverFillRemaining(
                  child: GetRouterOutlet(
                    // أول Child route للويب
                    initialRoute: AppRoutes.dashHome,
                    // نحافظ على حالة الصفحات عند التنقل
                    anchorRoute: AppRoutes.dashboard,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- Sidebar ثابت للويب --------------------------- */

class _WebSidebar extends StatelessWidget {
  final void Function(String route) onSelect;
  final String selectedRoute;

  const _WebSidebar({
    required this.onSelect,
    required this.selectedRoute,
  });

  int _selectedIndex() {
    if (selectedRoute.endsWith(AppRoutes.dashMembers)) return 1;
    if (selectedRoute.endsWith(AppRoutes.dashWallets)) return 2;
    if (selectedRoute.endsWith(AppRoutes.dashOrders)) return 3;
    if (selectedRoute.endsWith(AppRoutes.dashDebts)) return 4;
    if (selectedRoute.endsWith(AppRoutes.dashReports)) return 5;
    if (selectedRoute.endsWith(AppRoutes.dashSettings)) return 6;
    // home
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extended = MediaQuery.of(context).size.width > 1200;

    return NavigationRail(
      selectedIndex: _selectedIndex(),
      extended: extended,
      backgroundColor: theme.colorScheme.surface.withOpacity(.6),
      indicatorColor: theme.colorScheme.primary.withOpacity(.12),
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            onSelect(AppRoutes.dashHome);
            break;
          case 1:
            onSelect(AppRoutes.dashMembers);
            break;
          case 2:
            onSelect(AppRoutes.dashWallets);
            break;
          case 3:
            onSelect(AppRoutes.dashOrders);
            break;
          case 4:
            onSelect(AppRoutes.dashDebts);
            break;
          case 5:
            onSelect(AppRoutes.dashReports);
            break;
          case 6:
            onSelect(AppRoutes.dashSettings);
            break;
        }
      },
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group),
          label: Text('Members'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: Text('Wallets'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_cafe_outlined),
          selectedIcon: Icon(Icons.local_cafe),
          label: Text('Orders'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.request_page_outlined),
          selectedIcon: Icon(Icons.request_page),
          label: Text('Debts'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.insert_chart_outlined),
          selectedIcon: Icon(Icons.insert_chart),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}

/* ------------------------- محتوى الصفحة الرئيسية للويب ------------------------- */

class WebDashHomeView extends StatelessWidget {
  const WebDashHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: ListView(
        children: [
          // بانر بسيط
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(.10),
                  theme.colorScheme.secondaryContainer.withOpacity(.18),
                ],
              ),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.waving_hand_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Welcome to the Web dashboard shell. The sidebar and the top bar are persistent — only the content changes.',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Grid بطاقات صغيرة كـ Launchers
          LayoutBuilder(
            builder: (context, c) {
              double w = c.maxWidth;
              int cols = w >= 1200 ? 4 : w >= 900 ? 3 : w >= 600 ? 2 : 1;
              final items = [
                _HomeCardData('Members', Icons.group, AppRoutes.dashMembers),
                _HomeCardData('Wallets', Icons.account_balance_wallet_outlined, AppRoutes.dashWallets),
                _HomeCardData('Orders', Icons.local_cafe_rounded, AppRoutes.dashOrders),
                _HomeCardData('Debts', Icons.request_page_outlined, AppRoutes.dashDebts),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.8,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _HomeLauncherCard(data: items[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeCardData {
  final String title;
  final IconData icon;
  final String route;
  _HomeCardData(this.title, this.icon, this.route);
}

class _HomeLauncherCard extends StatelessWidget {
  final _HomeCardData data;
  const _HomeLauncherCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c1 = theme.colorScheme.primary.withOpacity(.06);
    final c2 = theme.colorScheme.secondaryContainer.withOpacity(.14);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Get.rootDelegate
          .toNamed(AppRoutes.dashboard + data.route),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon,
                  color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: theme.colorScheme.onSurface.withOpacity(.6)),
          ],
        ),
      ),
    );
  }
}
