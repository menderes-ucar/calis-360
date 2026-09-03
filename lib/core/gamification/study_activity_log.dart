import 'package:cloud_firestore/cloud_firestore.dart';

class StudyActivityLog {
  StudyActivityLog._();

  static Future<void> recordBestEffort({
    required FirebaseFirestore firestore,
    required String uid,
    required String type,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      await firestore
          .collection('users')
          .doc(uid)
          .collection('studyActivityDays')
          .doc(dateKey)
          .set({
        'dateKey': dateKey,
        'types': FieldValue.arrayUnion([type]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Aktivite günlüğü yardımcı bir katmandır. Firestore yetkisi/ağ sorunu,
      // kullanıcının asıl soru-sınav-plan işlemini başarısız yapmamalı.
    }
  }
}
