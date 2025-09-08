import 'dart:async';
import 'dart:ui' show ImageFilter; // للتمويه (Blur)
import 'package:flutter/foundation.dart' show kIsWeb; // للكشف عن الويب

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../controller/app_controller.dart';
import '../../../data/repositories/users_repo.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/settings_repo.dart';
import '../../../data/models/app_settings.dart';
import '../../routes/app_routes.dart';
import '../../../data/services/auth_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final AppController app;
  final auth = AuthService();
  final usersRepo = UsersRepo();
  final settingsRepo = SettingsRepo();

  Worker? _authWorker;
  StreamSubscription<User?>? _authSub;

  void _goLogin() {
    if (!mounted) return;
    Future.microtask(() => Get.offAllNamed(AppRoutes.login));
  }

  void _safeNav(String route) {
    try {
      Future.microtask(() => Get.toNamed(route));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المسار غير متاح بعد')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    app = Get.find<AppController>();

    _authWorker = ever<User?>(app.currentUser, (u) {
      if (u == null) _goLogin();
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u == null) _goLogin();
    });
  }

  @override
  void dispose() {
    _authWorker?.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl, // ✅ إجبار RTL لكل الصفحة
      child: Scaffold(
        body: StreamBuilder<AppUser?>(
          stream: usersRepo.watchMe(),
          builder: (context, meSnap) {
            if (!meSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final me = meSnap.data!;
            final email = me.email;

            // إجراءات سريعة بحسب الصلاحيات
            final actions = <_ActionItem>[
              if (me.perms.sessions)
                _ActionItem(
                  label: 'الأعضاء',
                  icon: Icons.group_rounded,
                  onTap: () => _safeNav(AppRoutes.members),
                ),
              if (me.perms.sessions || me.perms.isAdmin)
                _ActionItem(
                  label: 'المحافظ',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => _safeNav(AppRoutes.wallets),
                ),
              if (me.perms.orders == true || me.perms.isAdmin)
                _ActionItem(
                  label: 'الطلبات',
                  icon: Icons.local_cafe_rounded,
                  onTap: () => _safeNav(AppRoutes.orders),
                ),
              _ActionItem(
                label: 'الجلسات',
                icon: Icons.event_note_rounded,
                onTap: () => _safeNav(AppRoutes.sessionsOverview),
              ),
              if (me.perms.debts == true || me.perms.isAdmin)
                _ActionItem(
                  label: 'الديون',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => _safeNav(AppRoutes.debts),
                ),
              if (me.perms.isAdmin || me.perms.coupons == true)
                _ActionItem(
                  label: 'الكوبونات',
                  icon: Icons.card_giftcard_outlined,
                  onTap: () => _safeNav(AppRoutes.coupons),
                ),
              if (me.perms.isAdmin ||
                  (me.perms.expensesVar == true || me.perms.expensesFixed == true))
                _ActionItem(
                  label: 'المصاريف',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => _safeNav(AppRoutes.expenses),
                ),
              if (me.perms.isAdmin || me.perms.inventory)
                _ActionItem(
                  label: 'المخزون',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => _safeNav(AppRoutes.inventory),
                ),
              if (me.perms.isAdmin || me.perms.reports)
                _ActionItem(
                  label: 'التقارير',
                  icon: Icons.insert_chart_outlined_rounded,
                  onTap: () => _safeNav(AppRoutes.reports),
                ),
              if (me.perms.settings)
                _ActionItem(
                  label: 'الإعدادات',
                  icon: Icons.settings_rounded,
                  onTap: () => _safeNav(AppRoutes.settings),
                ),
              if (me.perms.isAdmin || me.perms.assets)
                _ActionItem(
                  label: 'الأصول',
                  icon: Icons.chair_alt,
                  onTap: () => _safeNav(AppRoutes.assets),
                ),
              if (me.perms.isAdmin)
                _ActionItem(
                  label: 'المستخدمون الإداريون',
                  icon: Icons.admin_panel_settings_rounded,
                  onTap: () => _safeNav(AppRoutes.adminUsers),
                ),
            ];

            // واجهة ويب أو موبايل
            if (kIsWeb) {
              return _WebDashboard(
                app: app,
                email: email,
                actions: actions,
                settingsRepo: settingsRepo,
              );
            } else {
              return _MobileDashboard(
                app: app,
                email: email,
                actions: actions,
                settingsRepo: settingsRepo,
                auth: auth,
                onLogout: () async {
                  await auth.signOut();
                  _goLogin();
                },
              );
            }
          },
        ),
      ),
    );
  }
}

/* ------------------------------- واجهة الموبايل ------------------------------- */

class _MobileDashboard extends StatelessWidget {
  final AppController app;
  final String email;
  final List<_ActionItem> actions;
  final SettingsRepo settingsRepo;
  final AuthService auth;
  final Future<void> Function() onLogout;

  const _MobileDashboard({
    required this.app,
    required this.email,
    required this.actions,
    required this.settingsRepo,
    required this.auth,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        // شريط علوي شفاف مع طبقة تمويه
        SliverAppBar(
          pinned: true,
          elevation: 0,
          toolbarHeight: kToolbarHeight,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: theme.colorScheme.surface.withOpacity(0.55),
              ),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              const SizedBox(width: 8),
              Icon(Icons.dashboard_customize_rounded,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Text('لوحة التحكم'),
            ],
          ),
          actions: [
            Obx(() => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0),
              child: Icon(
                app.firebaseReady.value
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
              ),
            )),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),

        // شريط الملاحظات
        SliverToBoxAdapter(
          child: _NotesBar(settingsRepo: settingsRepo),
        ),

        // تحية + البريد
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'مرحبًا 👋',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: theme.colorScheme.surfaceVariant.withOpacity(.6),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(.5),
                    ),
                  ),
                  child: Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.75),
                    ),
                    textDirection: TextDirection.ltr, // ✅ البريد يبقى LTR
                  ),
                ),
              ],
            ),
          ),
        ),

        // قائمة الإجراءات: كروت بعرض كامل
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          sliver: SliverList.separated(
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ActionTileCard(item: actions[i]),
          ),
        ),
      ],
    );
  }
}

/* -------------------------------- واجهة الويب -------------------------------- */

class _WebDashboard extends StatefulWidget {
  final AppController app;
  final String email;
  final List<_ActionItem> actions;
  final SettingsRepo settingsRepo;

  const _WebDashboard({
    required this.app,
    required this.email,
    required this.actions,
    required this.settingsRepo,
  });

  @override
  State<_WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<_WebDashboard> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = widget.actions
        .where((a) => _search.isEmpty || a.label.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Row(
      children: [
        // مع RTL، أول عنصر في الـ Row يكون يمين الشاشة — مناسب كـ NavigationRail
        NavigationRail(
          extended: MediaQuery.of(context).size.width > 1100,
          backgroundColor: theme.colorScheme.surface.withOpacity(.6),
          indicatorColor: theme.colorScheme.primary.withOpacity(.12),
          selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
          unselectedIconTheme: IconThemeData(color: theme.colorScheme.onSurface.withOpacity(.7)),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: Text('لوحة التحكم'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: Text('الأعضاء'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: Text('المحافظ'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.local_cafe_outlined),
              selectedIcon: Icon(Icons.local_cafe),
              label: Text('الطلبات'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: Text('المصاريف'),
            ),
          ],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),

        // المحتوى الرئيسي
        Expanded(
          child: CustomScrollView(
            slivers: [
              // شريط علوي شفاف + تمويه بسيط
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
                    Icon(Icons.dashboard_customize_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'لوحة التحكم - الويب',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 18),
                    // حالة الاتصال السحابي
                    Obx(() => Tooltip(
                      message: widget.app.firebaseReady.value ? 'السحابة: متصل' : 'السحابة: غير متصل',
                      child: Icon(
                        widget.app.firebaseReady.value ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      ),
                    )),
                  ],
                ),
                actions: [
                  // شريط بحث
                  SizedBox(
                    width: 320,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12.0, top: 8, bottom: 8),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'ابحث في الإجراءات…',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant.withOpacity(.7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary.withOpacity(.8),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: theme.colorScheme.surfaceVariant.withOpacity(.6),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.5)),
                      ),
                      child: Text(
                        widget.email,
                        textDirection: TextDirection.ltr, // ✅ يبقى LTR
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(.75),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // بانر ترحيبي واسع
              SliverToBoxAdapter(
                child: _HeroBanner(settingsRepo: widget.settingsRepo),
              ),

              // شبكة بطاقات إجراءات (Wrap مع Hover)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                sliver: SliverToBoxAdapter(
                  child: _ActionsWrap(actions: actions),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* --------------------------- عناصر واجهة مشتركة --------------------------- */

class _NotesBar extends StatelessWidget {
  final SettingsRepo settingsRepo;
  const _NotesBar({required this.settingsRepo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<AppSettings?>(
      stream: settingsRepo.watchSettings(),
      builder: (context, sSnap) {
        final s = sSnap.data;
        if (s == null) return const SizedBox.shrink();
        final n = s.notesBar;
        final now = DateTime.now();
        final inRange = (n.startAt == null || now.isAfter(n.startAt!)) &&
            (n.endAt == null || now.isBefore(n.endAt!));
        if (!n.active || !inRange || n.text.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        final Color base = switch (n.priority) {
          'alert' => Colors.red,
          'warn' => Colors.orange,
          _ => Theme.of(context).colorScheme.primary,
        };
        final Color bg = base.withOpacity(.10);
        final Color bd = base.withOpacity(.25);
        final Color fg = Theme.of(context).brightness == Brightness.dark
            ? base.withOpacity(.75)
            : base.withOpacity(.9);
        final IconData ic = switch (n.priority) {
          'alert' => Icons.error_outline_rounded,
          'warn' => Icons.warning_amber_rounded,
          _ => Icons.info_outline_rounded,
        };

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bg, bg.withOpacity(.6)],
            ),
            border: Border.all(color: bd, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: base.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ic, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  n.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final SettingsRepo settingsRepo;
  const _HeroBanner({required this.settingsRepo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topRight, // اتجاه التدرج يتبع RTL
            end: Alignment.bottomLeft,
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
        child: Column(
          children: [
            // شريط الملاحظات داخل الهيرو
            _NotesBar(settingsRepo: settingsRepo),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'مرحبًا 👋',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                // شارة صغيرة لإبراز حالة عامة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: theme.colorScheme.surfaceVariant.withOpacity(.6),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(.5),
                    ),
                  ),
                  child: Text(
                    'تجربة الويب',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.75),
                      letterSpacing: .2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsWrap extends StatelessWidget {
  final List<_ActionItem> actions;
  const _ActionsWrap({required this.actions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // عرض تقريبي للكرت، ويلتف تلقائيًا
        final double cardWidth = c.maxWidth >= 1280
            ? 260
            : c.maxWidth >= 1024
            ? 240
            : c.maxWidth >= 860
            ? 220
            : 200;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: actions.map((a) {
            return ConstrainedBox(
              constraints: BoxConstraints(minWidth: cardWidth, maxWidth: cardWidth),
              child: _WebActionCard(item: a),
            );
          }).toList(),
        );
      },
    );
  }
}

/* ------------------------------ نموذج إجراء ------------------------------ */

class _ActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/* --------------------------- كرت إجراء (موبايل) --------------------------- */

class _ActionTileCard extends StatefulWidget {
  final _ActionItem item;
  const _ActionTileCard({required this.item});

  @override
  State<_ActionTileCard> createState() => _ActionTileCardState();
}

class _ActionTileCardState extends State<_ActionTileCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color c1 = theme.colorScheme.primary.withOpacity(.06);
    final Color c2 = theme.colorScheme.secondaryContainer.withOpacity(.14);
    final Color border = theme.colorScheme.outlineVariant.withOpacity(.45);
    final Color title = theme.colorScheme.onSurface.withOpacity(.92);
    final Color iconBg = theme.colorScheme.primary.withOpacity(.12);
    final Color chevron = theme.colorScheme.onSurface.withOpacity(.55);

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _pressed ? .98 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() => _pressed = true);
            await Future.delayed(const Duration(milliseconds: 85));
            setState(() => _pressed = false);
            widget.item.onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [c1, c2],
              ),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  // أيقونة داخل كبسولة
                  Container(
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(widget.item.icon, size: 24, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  // عنوان الإجراء
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: title,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                  // السهم سيتّبع RTL تلقائيًا
                  Icon(Icons.arrow_forward_rounded, size: 22, color: chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ----------------------------- كرت إجراء (ويب) ----------------------------- */

class _WebActionCard extends StatefulWidget {
  final _ActionItem item;
  const _WebActionCard({required this.item});

  @override
  State<_WebActionCard> createState() => _WebActionCardState();
}

class _WebActionCardState extends State<_WebActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color c1 = theme.colorScheme.primary.withOpacity(.08);
    final Color c2 = theme.colorScheme.secondaryContainer.withOpacity(.16);
    final Color border = theme.colorScheme.outlineVariant.withOpacity(.4);
    final Color title = theme.colorScheme.onSurface.withOpacity(.95);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: _hover ? (Matrix4.identity()..translate(0.0, -2.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [c1, c2],
          ),
          border: Border.all(
            color: _hover ? theme.colorScheme.primary.withOpacity(.45) : border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hover ? .08 : .04),
              blurRadius: _hover ? 18 : 12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.item.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // أيقونة داخل كبسولة
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      widget.item.icon,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: title,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'فتح ${widget.item.label}',
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
