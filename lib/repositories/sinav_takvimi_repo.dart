import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sinav_takvimi.dart';

class SinavTakvimiRepository {
  SinavTakvimiRepository({
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
      throw StateError('Sınav takvimi işlemi için aktif oturum gerekli.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('sinavTakvimi');
  }

  String createId() => _collection(_requireUid()).doc().id;

  Future<void> addSinavProgram(SinavTakvimi sinavTakvimi) async {
    final uid = _requireUid();
    await _collection(uid).doc(sinavTakvimi.sinavId).set({
      ...sinavTakvimi.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SinavTakvimi>> getDers() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <SinavTakvimi>[]);

    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SinavTakvimi.fromjson(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<void> deleteSinav(String id) async {
    final uid = _requireUid();
    await _collection(uid).doc(id).delete();
  }

  Future<void> updateDersProgram(SinavTakvimi sinavTakvimi) async {
    final uid = _requireUid();
    await _collection(uid).doc(sinavTakvimi.sinavId).update({
      ...sinavTakvimi.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
