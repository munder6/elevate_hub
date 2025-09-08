import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/services/auth_service.dart';

class AppController extends GetxController {
  final firebaseReady = true
      .obs; // Firebase initializeApp تم في main.dart — نعتبره جاهز هنا
  final initializing = false.obs;
  String? initError;

  final currentUser = Rxn<User>();
  final _auth = AuthService();
  StreamSubscription<User?>? _authSub;

  @override
  void onInit() {
    super.onInit();
    _authSub = _auth.authStateChanges().listen(
          (user) => currentUser.value = user,
      onError: (e) => initError = e.toString(),
    );
    currentUser.value = _auth.currentUser;
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }
}
