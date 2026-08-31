import 'package:cloud_functions/cloud_functions.dart';

class AudioLessonAuthorization {
  const AudioLessonAuthorization({
    required this.premium,
    required this.creditCost,
    required this.creditBalance,
    required this.replay,
  });

  final bool premium;
  final int creditCost;
  final int creditBalance;
  final bool replay;
}

class AudioLessonRepository {
  AudioLessonRepository({
    required FirebaseFunctions functions,
  }) : _functions = functions;

  final FirebaseFunctions _functions;

  Future<AudioLessonAuthorization> authorize({
    required String subjectId,
    required String unitId,
    required String topicId,
  }) async {
    final requestId =
        'audio_${DateTime.now().microsecondsSinceEpoch}_$topicId';

    final callable = _functions.httpsCallable(
      'authorizeAudioLesson',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 30),
      ),
    );

    final response = await callable.call<Map<String, dynamic>>({
      'subjectId': subjectId,
      'unitId': unitId,
      'topicId': topicId,
      'requestId': requestId,
    });

    final data = response.data;

    return AudioLessonAuthorization(
      premium: data['premium'] == true,
      creditCost: (data['creditCost'] as num?)?.toInt() ?? 0,
      creditBalance: (data['creditBalance'] as num?)?.toInt() ?? 0,
      replay: data['replay'] == true,
    );
  }
}