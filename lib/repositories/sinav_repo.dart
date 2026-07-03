import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sınav.dart';

class SinavRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sınav ekleme (kendi UID altında)
  Future<void> addSinav(Sinav sinav) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavlar")
        .doc(sinav.sinavId)
        .set(sinav.toJson());
  }

  /// Tüm sınavları listeleme (kendi UID)
  Stream<List<Sinav>> getSinavlar() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavlar")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Sinav.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Tek bir sınavı getirme (kendi UID)
  Future<Sinav?> getSinav(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavlar")
        .doc(id)
        .get();
    if (doc.exists) {
      return Sinav.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  /// Sınav güncelleme (kendi UID)
  Future<void> updateSinav(Sinav sinav) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavlar")
        .doc(sinav.sinavId)
        .update(sinav.toJson());
  }

  /// Sınav silme (kendi UID)
  Future<void> deleteSinav(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sinavlar")
        .doc(id)
        .delete();
  }
}
