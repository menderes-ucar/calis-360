import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/soru.dart';

class SoruRepository {
  SoruRepository({
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
      throw StateError('Soru işlemi için aktif oturum gerekli.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('sorular');
  }

  String createId() => _collection(_requireUid()).doc().id;

  Future<void> addSoru(Soru soru) async {
    final uid = _requireUid();
    await _collection(uid).doc(soru.soruId).set({
      ...soru.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Soru>> getSorular() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Soru>[]);

    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Soru.fromJson(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<Soru?> getSoru(String id) async {
    final uid = _requireUid();
    final doc = await _collection(uid).doc(id).get();
    final data = doc.data();
    return data == null ? null : Soru.fromJson(data, doc.id);
  }

  Future<void> updateSoru(Soru soru) async {
    final uid = _requireUid();
    await _collection(uid).doc(soru.soruId).update({
      ...soru.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSoru(String id) async {
    final uid = _requireUid();
    await _collection(uid).doc(id).delete();
  }
}
