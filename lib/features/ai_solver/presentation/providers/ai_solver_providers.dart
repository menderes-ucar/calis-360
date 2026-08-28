import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/ai_solver_repository.dart';
import '../../domain/ai_solution.dart';

final aiSolverRepositoryProvider = Provider<AiSolverRepository>((ref) {
  return AiSolverRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final aiHistoryProvider = StreamProvider.autoDispose<List<AiSolution>>((ref) {
  return ref.watch(aiSolverRepositoryProvider).watchHistory(limit: 100);
});

final aiSolverControllerProvider =
    StateNotifierProvider<AiSolverController, AsyncValue<AiSolution?>>((ref) {
      return AiSolverController(ref.watch(aiSolverRepositoryProvider));
    });

class AiSolverController extends StateNotifier<AsyncValue<AiSolution?>> {
  AiSolverController(this._repository) : super(const AsyncData(null));

  final AiSolverRepository _repository;

  String createRequestId() => _repository.createRequestId();

  Future<AiSolution?> solve({
    required String requestId,
    required String questionText,
    required String subject,
    required String topic,
    required String examScope,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    if (state.isLoading) return null;

    state = const AsyncLoading();
    try {
      final result = await _repository.solve(
        requestId: requestId,
        questionText: questionText,
        subject: subject,
        topic: topic,
        examScope: examScope,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );
      state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
