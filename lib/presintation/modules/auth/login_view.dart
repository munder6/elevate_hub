// lib/presentation/modules/auth/login_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controller/app_controller.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/repositories/users_repo.dart';
import '../../routes/app_routes.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;

  final app = Get.find<AppController>();
  final auth = AuthService();
  final usersRepo = UsersRepo();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _routeAfterAuth() async {
    // أنشئ وثيقة لو مش موجودة، ثم اقرؤها مرة واحدة وحدّد الوجهة
    await usersRepo.createUserIfMissing();
    final me = await usersRepo.getMeOnce();

    final target = (me?.status == 'active')
        ? AppRoutes.dashboard
        : AppRoutes.activationPending;

    // نفّذ التوجيه خارج build
    Future.microtask(() => Get.offAllNamed(target));
  }

  Future<void> _doSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!app.firebaseReady.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase not connected')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await auth.signIn(email.text.trim(), password.text);
      await _routeAfterAuth(); // ✅ توجيه فوري
    } catch (e) {
      final msg = auth.mapError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _doRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!app.firebaseReady.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase not connected')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await auth.register(email.text.trim(), password.text);
      await _routeAfterAuth(); // ✅ توجيه فوري بعد إنشاء الحساب
    } catch (e) {
      final msg = auth.mapError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: email,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email?' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: loading ? null : _doSignIn,
                        child: loading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: loading ? null : _doRegister,
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
