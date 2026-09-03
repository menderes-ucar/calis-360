import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../models/dersProgrami.dart';
import '../../../../models/hedef.dart';
import '../../../../models/sinav.dart';
import '../../../../models/soru.dart';
import '../../../ai_solver/domain/ai_solution.dart';
import '../../../ai_solver/presentation/providers/ai_solver_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../study_data/presentation/providers/study_data_providers.dart';
import '../../data/gamification_repository.dart';
import '../../domain/gamification_summary.dart';
import '../../domain/leaderboard_entry.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

final studyActivityDaysProvider = StreamProvider.autoDispose<List<DateTime>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value(const <DateTime>[]);
  return ref.watch(gamificationRepositoryProvider).watchActivityDays();
});

final leaderboardEntriesProvider =
    StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value(const <LeaderboardEntry>[]);
  return ref.watch(gamificationRepositoryProvider).watchTopLeaderboard();
});

final leaderboardRankProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return 0;
  await ref.watch(leaderboardSyncProvider.future);
  return ref.watch(gamificationRepositoryProvider).getCurrentUserRank();
});

final gamificationSummaryProvider = Provider<AsyncValue<GamificationSummary>>((
  ref,
) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return const AsyncLoading();

  final questions = ref.watch(sorularProvider);
  final exams = ref.watch(sinavlarProvider);
  final aiHistory = ref.watch(aiHistoryProvider);
  final plans = ref.watch(dersProgramiProvider);
  final goals = ref.watch(hedeflerProvider);
  final loggedActivityDays = ref.watch(studyActivityDaysProvider);

  final error = _firstError([
    questions,
    exams,
    aiHistory,
    plans,
    goals,
  ]);
  if (error != null) {
    return AsyncError(error, StackTrace.current);
  }

  if (questions.isLoading ||
      exams.isLoading ||
      aiHistory.isLoading ||
      plans.isLoading ||
      goals.isLoading) {
    return const AsyncLoading();
  }

  final questionList = questions.valueOrNull ?? const <Soru>[];
  final examList = exams.valueOrNull ?? const <Sinav>[];
  final aiList = aiHistory.valueOrNull ?? const <AiSolution>[];
  final planList = plans.valueOrNull ?? const <DersProgram>[];
  final goalList = goals.valueOrNull ?? const <Hedef>[];
  final activityList = loggedActivityDays.valueOrNull ?? const <DateTime>[];

  return AsyncData(
    _buildSummary(
      questions: questionList,
      exams: examList,
      aiHistory: aiList,
      plans: planList,
      goals: goalList,
      loggedActivityDays: activityList,
    ),
  );
});

final leaderboardSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return;

  final summaryValue = ref.watch(gamificationSummaryProvider);
  final userValue = ref.watch(currentAppUserProvider);
  final summary = summaryValue.valueOrNull;
  final user = userValue.valueOrNull;

  if (summary == null || user == null) return;

  await ref.read(gamificationRepositoryProvider).syncLeaderboard();
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
  required List<Hedef> goals,
  required List<DateTime> loggedActivityDays,
}) {
  final correct = questions.where((item) => item.isCorrect).length;
  final wrong = questions.where((item) => item.isWrong).length;
  final reviewOrUnresolved = questions
      .where((item) => item.isUnresolved || item.needsReview)
      .length;
  final completedPlans = plans.where((item) => item.tamamlandi).length;
  final completedGoals = goals.where((item) => item.tamamlandi).length;

  final activityDays = <DateTime>{};

  void addDate(DateTime? value) {
    if (value == null) return;
    final local = value.toLocal();
    activityDays.add(DateTime(local.year, local.month, local.day));
  }

  for (final value in loggedActivityDays) {
    addDate(value);
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
  for (final item in goals.where((item) => item.tamamlandi)) {
    addDate(item.updatedAt ?? item.createdAt);
  }

  final streaks = _calculateStreaks(activityDays);

  // Dengeli puan formülü:
  // doğru soru 10, yanlış soru 3, tekrar/bekleyen soru 1,
  // tamamlanmış AI çözümü 4, deneme 25, tamamlanan çalışma 10,
  // tamamlanan hedef 10 ve aktif olunan her benzersiz gün 5 puan.
  // Böylece yalnızca kredi harcamak puanı domine etmez; düzenli çalışma,
  // doğru cevap ve tamamlanan planlar daha fazla ağırlık taşır.
  final score =
      (correct * 10) +
      (wrong * 3) +
      (reviewOrUnresolved * 1) +
      (aiHistory.length * 4) +
      (exams.length * 25) +
      (completedPlans * 10) +
      (completedGoals * 10) +
      (activityDays.length * 5);

  final aiRequestIds = aiHistory
      .map((item) => item.requestId.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final nonDuplicateQuestions = questions.where((item) {
    final requestId = item.aiRequestId?.trim();
    return requestId == null || requestId.isEmpty || !aiRequestIds.contains(requestId);
  }).length;

  return GamificationSummary(
    score: score,
    currentStreak: streaks.$1,
    longestStreak: streaks.$2,
    solvedCount: aiHistory.length + nonDuplicateQuestions,
    correctCount: correct,
    wrongCount: wrong,
    completedStudyCount: completedPlans,
    completedGoalCount: completedGoals,
    examCount: exams.length,
    activeDayCount: activityDays.length,
  );
}

(int, int) _calculateStreaks(Set<DateTime> activityDays) {
  if (activityDays.isEmpty) return (0, 0);

  final normalized = activityDays
      .map((day) => DateTime(day.year, day.month, day.day))
      .toSet();
  final sorted = normalized.toList()..sort();

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

  // Kullanıcı bugün henüz çalışmadıysa dün biten seri gün sonuna kadar korunur.
  // Dün de aktivite yoksa seri gerçekten kırılmış kabul edilir.
  DateTime? cursor;
  if (normalized.contains(today)) {
    cursor = today;
  } else if (normalized.contains(yesterday)) {
    cursor = yesterday;
  }

  if (cursor == null) return (0, longest);

  var streakCursor = cursor;
  var current = 0;
  while (normalized.contains(streakCursor)) {
    current += 1;
    streakCursor = streakCursor.subtract(const Duration(days: 1));
  }

  return (current, longest);
}
