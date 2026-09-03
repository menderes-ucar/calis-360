import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/study_planner_repository.dart';
import '../../domain/study_plan_models.dart';

final studyPlannerRepositoryProvider = Provider<StudyPlannerRepository>((ref) {
  return StudyPlannerRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final studyPlannerControllerProvider = StateNotifierProvider<
    StudyPlannerController, AsyncValue<GeneratedStudyPlan?>>((ref) {
  return StudyPlannerController(ref.watch(studyPlannerRepositoryProvider));
});

class StudyPlannerController
    extends StateNotifier<AsyncValue<GeneratedStudyPlan?>> {
  StudyPlannerController(this._repository) : super(const AsyncData(null));

  final StudyPlannerRepository _repository;

  Future<GeneratedStudyPlan?> generate(StudyPlanRequest request) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final plan = await _repository.generate(request);
      state = AsyncData(plan);
      return plan;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void clear() => state = const AsyncData(null);
}
