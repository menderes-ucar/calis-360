import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/ai_solution.dart';

class AiSolverRepository {
  AiSolverRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _functions = functions,
       _firestore = firestore,
       _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Random _random = Random.secure();

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('AI soru çözümü için aktif oturum gerekli.');
    }
    return uid;
  }

  String createRequestId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final suffix = List.generate(
      12,
      (_) => _random.nextInt(36).toRadixString(36),
    ).join();
    return 'ai_${micros}_$suffix';
  }

  Future<AiSolution> solve({
    required String requestId,
    required String questionText,
    required String subject,
    required String topic,
    required String examScope,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final uid = _requireUid();

    // Özellikle eski Android cihazlarda callable öncesinde güncel ID token kullan.
    await _auth.currentUser?.getIdToken(true);

    final callable = _functions.httpsCallable(
      'solveQuestionWithAi',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );

    final payload = <String, dynamic>{
      'requestId': requestId,
      'questionText': questionText.trim(),
      'subject': subject.trim(),
      'topic': topic.trim(),
      'examScope': examScope.trim().toUpperCase(),
    };

    if (imageBytes != null && imageBytes.isNotEmpty) {
      payload['imageBase64'] = base64Encode(imageBytes);
      payload['imageMimeType'] = imageMimeType ?? 'image/jpeg';
    }

    debugPrint(
      '[AI_SOLVER] calling solveQuestionWithAi '
      'uid=$uid image=${imageBytes?.lengthInBytes ?? 0}B '
      'mime=${imageMimeType ?? '-'} text=${questionText.trim().length}',
    );

    try {
      final response = await callable.call<Map<dynamic, dynamic>>(payload);
      debugPrint('[AI_SOLVER] callable success');
      return AiSolution.fromCallable(Map<String, dynamic>.from(response.data));
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[AI_SOLVER] callable error '
        'code=${error.code} message=${error.message} details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[AI_SOLVER] unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Stream<List<AiSolution>> watchHistory({int limit = 20}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <AiSolution>[]);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_requests')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.data()['status'] == 'completed')
              .map((doc) => AiSolution.fromHistoryDoc(doc.id, doc.data()))
              .toList(growable: false),
        );
  }
}
