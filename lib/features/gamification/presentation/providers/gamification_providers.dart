import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_solver/domain/ai_solution.dart';
import '../../../ai_solver/presentation/providers/ai_solver_providers.dart';
import '../../../study_data/presentation/providers/study_data_providers.dart';
import '../../../../models/dersProgrami.dart';
import '../../../../models/sinav.dart';
import '../../../../models/soru.dart';
import '../../domain/gamification_summary.dart';

final gamificationSummaryProvider = Provider<AsyncValue<GamificationSummary>>((
  ref,
) {
  final questions = ref.watch(sorularProvider);
  final exams = ref.watch(sinavlarProvider);
  final aiHistory = ref.watch(aiHistoryProvider);
  final plans = ref.watch(dersProgramiProvider);

  final error = _firstError([questions, exams, aiHistory, plans]);
  if (error != null) {
    return AsyncError(error, StackTrace.current);
  }

  if (questions.isLoading ||
      exams.isLoading ||
      aiHistory.isLoading ||
      plans.isLoading) {
    return const AsyncLoading();
  }

  final questionList = questions.valueOrNull ?? const <Soru>[];
  final examList = exams.valueOrNull ?? const <Sinav>[];
  final aiList = aiHistory.valueOrNull ?? const <AiSolution>[];
  final planList = plans.valueOrNull ?? const <DersProgram>[];

  return AsyncData(
    _buildSummary(
      questions: questionList,
      exams: examList,
      aiHistory: aiList,
      plans: planList,
    ),
  );
});

Object? _firstError(List<AsyncValue<dynamic>> values) {
  for (final value in values) {
    if (value.hasError) return value.error;
  }
  return null;
}

GamificationSummary _buildSummary({
  required List<Soru> questions,
  required List<Sinav> exams,
  required List<AiSolution> aiHistory,
  required List<DersProgram> plans,
}) {
  final correct = questions.where((item) => item.isCorrect).length;
  final wrong = questions.where((item) => item.isWrong).length;
  final completedPlans = plans.where((item) => item.tamamlandi).length;

  // Skor, yalnızca kullanıcının mevcut kayıtlarından hesaplanır. Sunucu tarafında
  // kalıcı leaderboard'a geçildiğinde aynı formül tek kaynaktan yönetilebilir.
  final score =
      (aiHistory.length * 12) +
      (correct * 8) +
      (wrong * 3) +
      (questions.where((item) => item.isUnresolved || item.needsReview).length *
          2) +
      (exams.length * 20) +
      (completedPlans * 6);

  final activityDays = <DateTime>{};

  void addDate(DateTime? value) {
    if (value == null) return;
    final local = value.toLocal();
    activityDays.add(DateTime(local.year, local.month, local.day));
  }

  for (final item in questions) {
    addDate(item.createdAt ?? item.updatedAt);
  }
  for (final item in exams) {
    addDate(item.createdAt ?? item.updatedAt);
  }
  for (final item in aiHistory) {
    addDate(item.createdAt);
  }
  for (final item in plans.where((item) => item.tamamlandi)) {
    addDate(item.updatedAt ?? item.createdAt);
  }

  final streaks = _calculateStreaks(activityDays);

  return GamificationSummary(
    score: score,
    currentStreak: streaks.$1,
    longestStreak: streaks.$2,
    solvedCount: aiHistory.length + questions.length,
    correctCount: correct,
    wrongCount: wrong,
    completedStudyCount: completedPlans,
    examCount: exams.length,
  );
}

(int, int) _calculateStreaks(Set<DateTime> activityDays) {
  if (activityDays.isEmpty) return (0, 0);

  final sorted = activityDays.toList()..sort();
  var longest = 1;
  var running = 1;

  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    if (gap == 1) {
      running += 1;
      if (running > longest) longest = running;
    } else if (gap > 1) {
      running = 1;
    }
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  DateTime? cursor;
  if (activityDays.contains(today)) {
    cursor = today;
  } else if (activityDays.contains(yesterday)) {
    cursor = yesterday;
  }

  if (cursor == null) return (0, longest);

  var streakCursor = cursor;
  var current = 0;
  while (activityDays.contains(streakCursor)) {
    current += 1;
    streakCursor = streakCursor.subtract(const Duration(days: 1));
  }

  return (current, longest);
}
