// ignore_for_file: file_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/gamification/study_activity_log.dart';
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
    if (value) {
      await StudyActivityLog.recordBestEffort(
        firestore: _firestore,
        uid: uid,
        type: 'study_completed',
      );
    }
  }

  Future<bool> hasProgramInWeek(int weekNumber) async {
    final uid = _requireUid();
    final snapshot = await _collection(
      uid,
    ).where('weekNumber', isEqualTo: weekNumber).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<int> getNextWeekNumber() async {
    final uid = _requireUid();
    final snapshot = await _collection(uid).get();
    var maxWeek = 0;
    for (final doc in snapshot.docs) {
      final value = doc.data()['weekNumber'];
      final week = value is num
          ? value.toInt()
          : int.tryParse((value ?? '1').toString()) ?? 1;
      if (week > maxWeek) maxWeek = week;
    }
    return maxWeek + 1;
  }

  Future<void> addAiGeneratedWeek(List<DersProgram> items) async {
    if (items.isEmpty) return;
    final uid = _requireUid();
    final collection = _collection(uid);
    final batch = _firestore.batch();
    for (final item in items) {
      batch.set(collection.doc(item.dersProgramId), {
        ...item.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateDersProgram(DersProgram dersProgram) async {
    final uid = _requireUid();
    await _collection(uid).doc(dersProgram.dersProgramId).update({
      ...dersProgram.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
