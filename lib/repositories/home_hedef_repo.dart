import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/home_hedef_ekle.dart';

class HomeHedefRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. VERİ EKLEME / GÜNCELLEME (Kullanıcı bazlı)
  Future<void> addOrUpdateHedefForCurrentUser({
    required int net,
    required String uni,
    required String bolum,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final hedef = HomeHedef(
      id: uid,
      net: net,
      uni: uni,
      bolum: bolum,
    );
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("homeHedef")
        .doc(uid)
        .set(hedef.toJson());
  }

  // 2. Kullanıcının kendi hedefini Stream ile dinle
  Stream<HomeHedef?> getHomeHedefForCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("homeHedef")
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final data = snapshot.data() as Map<String, dynamic>;
      return HomeHedef(
        id: uid,
        net: data['net'] ?? 0,
        uni: data['uni'] ?? '',
        bolum: data['bolum'] ?? '',
      );
    });
  }

  // 3. Kullanıcının kendi hedefini sil
  Future<void> deleteHomeHedefForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("homeHedef")
        .doc(uid)
        .delete();
  }

  // 4. Genel listeleme (isteğe bağlı, kullanıcı bazlı değil)
  Stream<List<HomeHedef>> getHomeHedefler() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("homeHedef")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return HomeHedef.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // 5. Tek veri getirme (kendi UID)
  Future<HomeHedef?> getHomeHedefById(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("homeHedef")
        .doc(id)
        .get();
    if (doc.exists) {
      return HomeHedef.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }
}
