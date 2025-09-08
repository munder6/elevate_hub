import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class UsersRepo {
  final fs = FirestoreService();
  final auth = AuthService();

  String _userPath(String uid) => 'users/$uid';

  Map<String, dynamic> _defaultPerms() => const AppPerms().toMap();

  Future<void> createUserIfMissing() async {
    final u = auth.currentUser;
    if (u == null) return;
    final ref = fs.doc(_userPath(u.uid));
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': u.email,
        'name': u.displayName,
        'status': 'pending',
        'perms': _defaultPerms(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<AppUser?> getMeOnce() async {
    final u = auth.currentUser;
    if (u == null) return null;
    final ds = await fs.getDoc(_userPath(u.uid));
    final data = ds.data();
    if (!ds.exists || data == null) return null;
    return AppUser.fromMap(ds.id, data);
  }

  Stream<AppUser?> watchMe() {
    final u = auth.currentUser;
    if (u == null) return const Stream.empty();
    return fs.watchDoc(_userPath(u.uid)).map((ds) {
      final data = ds.data();
      if (!ds.exists || data == null) return null;
      return AppUser.fromMap(ds.id, data);
    });
  }

  Stream<List<AppUser>> watchAllUsers() {
    return fs
        .col('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs
        .map((d) => AppUser.fromMap(d.id, d.data()))
        .toList(growable: false));
  }

  Future<void> updateStatus(String uid, String status) async {
    await fs.update(_userPath(uid), {'status': status});
  }

  Future<void> updatePerms(String uid, AppPerms perms) async {
    await fs.update(_userPath(uid), {'perms': perms.toMap()});
  }
}
