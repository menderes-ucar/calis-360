// ignore_for_file: file_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/dersProgrami.dart';

class DersProgramiRepository {
  DersProgramiRepository({
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
      throw StateError('Ders programı işlemi için aktif oturum gerekli.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('dersProgram');
  }

  String createId() => _collection(_requireUid()).doc().id;

  Future<void> addDersProgram(DersProgram dersProgram) async {
    final uid = _requireUid();
    await _collection(uid).doc(dersProgram.dersProgramId).set({
      ...dersProgram.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<DersProgram>> getDersProgram() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <DersProgram>[]);

    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => DersProgram.fromjson(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<void> deleteDersProgram(String id) async {
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

  Future<void> updateDersProgram(DersProgram dersProgram) async {
    final uid = _requireUid();
    await _collection(uid).doc(dersProgram.dersProgramId).update({
      ...dersProgram.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
