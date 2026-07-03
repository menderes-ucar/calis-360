import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sinav_takvimi.dart';

class SinavTakvimiRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sınav programı ekleme (kendi UID altında)
  Future<void> addSinavProgram(SinavTakvimi sinavTakvimi) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavTakvimi")
        .doc(sinavTakvimi.sinavId)
        .set(sinavTakvimi.toJson());
  }

  /// Kullanıcının sınav takvimlerini listeleme (Stream)
  Stream<List<SinavTakvimi>> getDers() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavTakvimi")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SinavTakvimi.fromjson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Tek bir sınavı silme (kendi UID)
  Future<void> deleteSinav(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavTakvimi")
        .doc(id)
        .delete();
  }

  /// Sınav programını güncelleme (kendi UID)
  Future<void> updateDersProgram(SinavTakvimi sinavTakvimi) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavTakvimi")
        .doc(sinavTakvimi.sinavId)
        .update(sinavTakvimi.toJson());
  }
}
