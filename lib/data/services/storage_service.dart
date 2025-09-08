import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  FirebaseStorage? get _st => FirebaseStorage.instance;

  bool get isReady {
    try { FirebaseStorage.instance; return true; } catch (_) { return false; }
  }

  Future<String> getDownloadUrl(String path) async {
    if (!isReady) throw StateError('Firebase not ready');
    return _st!.ref(path).getDownloadURL();
  }
}
