import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hedef.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HedefRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. VERİ EKLEME
  Future<void> addHedef(Hedef hedef) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("hedefler")
        .doc(hedef.hedefId)
        .set({
      "hedefAd": hedef.hedefAd,
      "hedefNote": hedef.hedefNote,
      "hedefTarihi": hedef.hedefTarihi,
      "hedefZamani": hedef.hedefZamani,
    });
  }

  // 2. VERİ LİSTELEME (Stream şeklinde dinleme)
  Stream<List<Hedef>> getHedef() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("hedefler")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Hedef.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  // 3. TEK VERİ GETİRME
  Future<Hedef?> getHedefById(String id) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore
        .collection("users")
        .doc(userId)
        .collection("hedefler")
        .doc(id)
        .get();
    if (doc.exists) {
      return Hedef.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // 4. VERİ GÜNCELLEME
  Future<void> updateHedef(Hedef hedef) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("hedefler")
        .doc(hedef.hedefId)
        .update({
      "hedefAd": hedef.hedefAd,
      "hedefNote": hedef.hedefNote,
      "hedefTarihi": hedef.hedefTarihi,
    });
  }

  // 5. VERİ SİLME
  Future<void> deleteHedef(String id) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("hedefler")
        .doc(id)
        .delete();
  }

  Future<void> updateTamamlandi(String id, bool value) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("hedefler")
        .doc(id)
        .update({
      "tamamlandi": value,
    });
  }
}
