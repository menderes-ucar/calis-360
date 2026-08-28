import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class QuestionMediaRepository {
  QuestionMediaRepository({
    required FirebaseAuth auth,
    required FirebaseStorage storage,
  }) : _auth = auth,
       _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<String> uploadQuestionImage({
    required String questionId,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Görsel yüklemek için aktif oturum gerekli.');
    }

    final ref = _storage.ref().child(
      'users/$uid/questions/$questionId/question.jpg',
    );

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: mimeType,
        cacheControl: 'public,max-age=31536000,immutable',
      ),
    );

    return ref.getDownloadURL();
  }

  Future<void> deleteQuestionImage(String questionId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _storage
          .ref()
          .child('users/$uid/questions/$questionId/question.jpg')
          .delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
