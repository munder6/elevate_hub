import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../controller/app_controller.dart'; // لو مجلدك "controllers" بدّل المسار
import '../../../data/repositories/users_repo.dart';
import '../../../data/models/app_user.dart';
import '../../routes/app_routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final AppController app;
  final usersRepo = UsersRepo();

  StreamSubscription<AppUser?>? _meSub;
  Worker? _authWorker; // <-- نخزن worker تبع ever

  void _routeTo(String target) {
    if (!mounted) return;
    if (Get.currentRoute != target) {
      // نؤجّل التوجيه لمايكروتاسك لتجنّب أي تعارض مع الـ build
      Future.microtask(() => Get.offAllNamed(target));
    }
  }

  void _decide(AppUser? me) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _routeTo(AppRoutes.login);
      return;
    }
    if (me == null || me.status != 'active') {
      _routeTo(AppRoutes.activationPending);
      return;
    }
    _routeTo(AppRoutes.dashboard);
  }

  @override
  void initState() {
    super.initState();
    app = Get.find<AppController>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _routeTo(AppRoutes.login);
      } else {
        await usersRepo.createUserIfMissing();
        _meSub = usersRepo.watchMe().listen(_decide);
      }

      // خزّن الـ worker لتصفيته لاحقاً
      _authWorker = ever<User?>(app.currentUser, (u) async {
        await _meSub?.cancel();
        if (u == null) {
          _routeTo(AppRoutes.login);
        } else {
          await usersRepo.createUserIfMissing();
          _meSub = usersRepo.watchMe().listen(_decide);
        }
      });
    });
  }

  @override
  void dispose() {
    _meSub?.cancel();
    _authWorker?.dispose(); // <-- مهم
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: FlutterLogo(size: 100)),
    );
  }
}
