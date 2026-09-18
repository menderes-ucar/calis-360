import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_hedef_ekle.dart';

class HomeHedefRepository {
  HomeHedefRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Ana hedef işlemi için aktif oturum gerekli.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('homeHedef');
  }

  Future<void> addOrUpdateHedefForCurrentUser({
    required int net,
    required String uni,
    required String bolum,
  }) async {
    final uid = _requireUid();
    final hedef = HomeHedef(id: uid, net: net, uni: uni, bolum: bolum);
    await _collection(uid).doc(uid).set({
      ...hedef.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<HomeHedef?> getHomeHedefForCurrentUser() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    return _collection(uid).doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return HomeHedef.fromJson(data, snapshot.id);
    });
  }

  Future<void> deleteHomeHedefForCurrentUser() async {
    final uid = _requireUid();
    await _collection(uid).doc(uid).delete();
  }

  Stream<List<HomeHedef>> getHomeHedefler() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <HomeHedef>[]);

    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => HomeHedef.fromJson(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<HomeHedef?> getHomeHedefById(String id) async {
    final uid = _requireUid();
    final doc = await _collection(uid).doc(id).get();
    final data = doc.data();
    return data == null ? null : HomeHedef.fromJson(data, doc.id);
  }
}
