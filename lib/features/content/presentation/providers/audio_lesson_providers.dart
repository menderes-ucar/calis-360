import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/audio_lesson_repository.dart';

final audioLessonRepositoryProvider = Provider<AudioLessonRepository>((ref) {
  return AudioLessonRepository(
    functions: ref.watch(firebaseFunctionsProvider),
  );
});