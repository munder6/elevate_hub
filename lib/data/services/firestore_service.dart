import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> doc(String path) => _db.doc(path);
  CollectionReference<Map<String, dynamic>> col(String path) => _db.collection(path);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDoc(String path) => doc(path).snapshots();

  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(String path) => doc(path).get();

  Future<void> set(String path, Map<String, dynamic> data, {bool merge = true}) =>
      doc(path).set(data, SetOptions(merge: merge));

  Future<void> update(String path, Map<String, dynamic> data) => doc(path).update(data);

  Future<QuerySnapshot<Map<String, dynamic>>> getCol(String path) => col(path).get();

  Future<void> delete(String path) => doc(path).delete();
}
