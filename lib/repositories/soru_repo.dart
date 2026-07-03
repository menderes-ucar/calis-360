import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/soru.dart';

class SoruRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Soru ekleme (kendi UID altında)
  Future<void> addSoru(Soru soru) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sorular")
        .doc(soru.soruId)
        .set({
      "soruAd": soru.soruAd,
      "soruDers": soru.soruDers,
      "soruKonu": soru.soruKonu,
      "soruCevap": soru.soruCevap,
    });
  }

  // 2. Kullanıcının sorularını listeleme (Stream)
  Stream<List<Soru>> getSorular() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("sorular")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Soru.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  // 3. Tek bir soru getirme (kendi UID)
  Future<Soru?> getSoru(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("sorular")
        .doc(id)
        .get();
    if (doc.exists) {
      return Soru.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // 4. Soru güncelleme (kendi UID)
  Future<void> updateSoru(Soru soru) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sorular")
        .doc(soru.soruId)
        .update({
      "soruAd": soru.soruAd,
      "soruDers": soru.soruDers,
      "soruKonu": soru.soruKonu,
      "soruCevap": soru.soruCevap,
    });
  }

  // 5. Soru silme (kendi UID)
  Future<void> deleteSoru(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sorular")
        .doc(id)
        .delete();
  }
}
