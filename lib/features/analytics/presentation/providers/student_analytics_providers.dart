import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_solver/presentation/providers/ai_solver_providers.dart';
import '../../../study_data/presentation/providers/study_data_providers.dart';
import '../../application/analytics_engine.dart';
import '../../domain/analytics_models.dart';

final analyticsEngineProvider = Provider<AnalyticsEngine>((ref) {
  return const AnalyticsEngine();
});

final studentAnalyticsReportProvider =
    Provider.autoDispose<AsyncValue<AnalyticsReport>>((ref) {
      final exams = ref.watch(sinavlarProvider);
      final questions = ref.watch(sorularProvider);
      final aiHistory = ref.watch(aiHistoryProvider);
      final plans = ref.watch(dersProgramiProvider);
      final goals = ref.watch(hedeflerProvider);

      final asyncValues = <AsyncValue<dynamic>>[
        exams,
        questions,
        aiHistory,
        plans,
        goals,
      ];

      for (final value in asyncValues) {
        if (value.hasError) {
          return AsyncValue.error(
            value.error!,
            value.stackTrace ?? StackTrace.current,
          );
        }
      }

      if (asyncValues.any((value) => value.isLoading && !value.hasValue)) {
        return const AsyncValue.loading();
      }

      final report = ref
          .watch(analyticsEngineProvider)
          .build(
            exams: exams.valueOrNull ?? const [],
            questions: questions.valueOrNull ?? const [],
            aiSolutions: aiHistory.valueOrNull ?? const [],
            studyPlans: plans.valueOrNull ?? const [],
            goals: goals.valueOrNull ?? const [],
          );

      return AsyncValue.data(report);
    });
