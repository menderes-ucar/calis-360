import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dersProgrami.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DersProgramiRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addDersProgram(DersProgram dersProgram) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("dersProgram")
        .doc(dersProgram.dersProgramId)
        .set(dersProgram.toJson());
  }

  Stream<List<DersProgram>> getDersProgram() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("dersProgram")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DersProgram.fromjson(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> deleteDersProgram(String id) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("dersProgram")
        .doc(id)
        .delete();
  }

  Future<void> updateTamamlandi(String id, bool value) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("dersProgram")
        .doc(id)
        .update({
      "tamamlandi": value,
    });
  }

  Future<void> updateDersProgram(DersProgram dersProgram) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("dersProgram")
        .doc(dersProgram.dersProgramId)
        .update(dersProgram.toJson());
  }
}
