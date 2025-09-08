import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  String mapError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email': return 'Invalid email';
        case 'user-disabled': return 'User disabled';
        case 'user-not-found': return 'User not found';
        case 'wrong-password': return 'Wrong password';
        case 'email-already-in-use': return 'Email already in use';
        case 'weak-password': return 'Weak password';
      }
    }
    return e.toString();
  }
}
