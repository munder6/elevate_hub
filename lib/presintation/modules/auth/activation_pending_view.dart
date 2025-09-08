// lib/presentation/modules/auth/activation_pending_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/repositories/users_repo.dart';
import '../../../data/models/app_user.dart';
import '../../routes/app_routes.dart';
import '../../../data/services/auth_service.dart';

class ActivationPendingView extends StatefulWidget {
  const ActivationPendingView({super.key});

  @override
  State<ActivationPendingView> createState() => _ActivationPendingViewState();
}

class _ActivationPendingViewState extends State<ActivationPendingView> {
  final auth = AuthService();
  final repo = UsersRepo();

  StreamSubscription<AppUser?>? _meSub;
  StreamSubscription<User?>? _authSub; // ⬅️ مستمع على FirebaseAuth

  void _goLogin() {
    if (!mounted) return;
    if (Get.currentRoute != AppRoutes.login) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.login));
    }
  }

  void _goDashboard() {
    if (!mounted) return;
    if (Get.currentRoute != AppRoutes.dashboard) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.dashboard));
    }
  }

  @override
  void initState() {
    super.initState();

    // لو تفعّل الحساب → Dashboard
    _meSub = repo.watchMe().listen((me) {
      if (me?.status == 'active') {
        _goDashboard();
      }
    });

    // لو عمل Sign out → Login
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u == null) {
        _goLogin();
      }
    });
  }

  @override
  void dispose() {
    _meSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activation pending')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_clock, size: 56),
            const SizedBox(height: 12),
            const Text('Your account is awaiting activation by admin.'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await auth.signOut();
                _goLogin();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ]),
        ),
      ),
    );
  }
}
