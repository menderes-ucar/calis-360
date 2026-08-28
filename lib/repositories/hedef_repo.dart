import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/hedef.dart';

class HedefRepository {
  HedefRepository({
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
      throw StateError('Hedef işlemi için aktif oturum gerekli.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('hedefler');
  }

  String createId() => _collection(_requireUid()).doc().id;

  Future<void> addHedef(Hedef hedef) async {
    final uid = _requireUid();
    await _collection(uid).doc(hedef.hedefId).set({
      ...hedef.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Hedef>> getHedef() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Hedef>[]);

    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Hedef.fromJson(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<Hedef?> getHedefById(String id) async {
    final uid = _requireUid();
    final doc = await _collection(uid).doc(id).get();
    final data = doc.data();
    return data == null ? null : Hedef.fromJson(data, doc.id);
  }

  Future<void> updateHedef(Hedef hedef) async {
    final uid = _requireUid();
    await _collection(uid).doc(hedef.hedefId).update({
      ...hedef.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHedef(String id) async {
    final uid = _requireUid();
    await _collection(uid).doc(id).delete();
  }

  Future<void> updateTamamlandi(String id, bool value) async {
    final uid = _requireUid();
    await _collection(uid).doc(id).update({
      'tamamlandi': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
