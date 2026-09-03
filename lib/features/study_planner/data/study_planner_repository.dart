import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/study_plan_models.dart';

class StudyPlannerRepository {
  StudyPlannerRepository({
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _functions = functions,
       _auth = auth;

  static const int programCreditCost = 10;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final Random _random = Random.secure();

  String _createRequestId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final suffix = List.generate(
      12,
      (_) => _random.nextInt(36).toRadixString(36),
    ).join();
    return 'plan_${micros}_$suffix';
  }

  Future<GeneratedStudyPlan> generate(StudyPlanRequest request) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('AI programı oluşturmak için aktif oturum gerekli.');
    }

    await user.getIdToken(true);

    final callable = _functions.httpsCallable(
      'generateWeeklyStudyPlan',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );

    try {
      final response = await callable.call<Map<dynamic, dynamic>>({
        ...request.toJson(),
        'requestId': _createRequestId(),
      });

      final plan = GeneratedStudyPlan.fromCallable(
        Map<String, dynamic>.from(response.data),
      );

      if (plan.sessions.isEmpty) {
        throw StateError('AI geçerli bir çalışma programı oluşturamadı.');
      }

      return plan;
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason']?.toString() : null;

      if (reason == 'insufficient_credits') {
        throw StateError(
          'AI haftalık program oluşturmak için $programCreditCost kredi gerekiyor. Kredi bakiyen yetersiz.',
        );
      }
      if (reason == 'request_in_progress') {
        throw StateError('Bu AI program isteği zaten işleniyor. Biraz sonra tekrar dene.');
      }

      throw StateError(
        error.message ?? 'AI programı şu anda oluşturulamadı. Tekrar dene.',
      );
    }
  }
}
