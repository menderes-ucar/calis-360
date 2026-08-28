import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sinav.dart';

class SinavRepository {
  SinavRepository({
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
      throw StateError('Sınav işlemi için aktif oturum gerekli.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('sinavlar');
  }

  String createId() => _collection(_requireUid()).doc().id;

  Future<void> addSinav(Sinav sinav) async {
    final uid = _requireUid();
    await _collection(uid).doc(sinav.sinavId).set({
      ...sinav.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Sinav>> getSinavlar() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Sinav>[]);

    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Sinav.fromJson(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<Sinav?> getSinav(String id) async {
    final uid = _requireUid();
    final doc = await _collection(uid).doc(id).get();
    final data = doc.data();
    return data == null ? null : Sinav.fromJson(data, doc.id);
  }

  Future<void> updateSinav(Sinav sinav) async {
    final uid = _requireUid();
    await _collection(uid).doc(sinav.sinavId).update({
      ...sinav.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSinav(String id) async {
    final uid = _requireUid();
    await _collection(uid).doc(id).delete();
  }
}
