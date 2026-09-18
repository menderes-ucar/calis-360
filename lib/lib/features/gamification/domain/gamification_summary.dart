class GamificationSummary {
  const GamificationSummary({
    required this.score,
    required this.currentStreak,
    required this.longestStreak,
    required this.solvedCount,
    required this.correctCount,
    required this.wrongCount,
    required this.completedStudyCount,
    required this.completedGoalCount,
    required this.examCount,
    required this.activeDayCount,
  });

  final int score;
  final int currentStreak;
  final int longestStreak;
  final int solvedCount;
  final int correctCount;
  final int wrongCount;
  final int completedStudyCount;
  final int completedGoalCount;
  final int examCount;
  final int activeDayCount;

  int? get accuracyPercent {
    final measured = correctCount + wrongCount;
    if (measured == 0) return null;
    return ((correctCount / measured) * 100).round();
  }

  bool get hasActivity =>
      solvedCount > 0 ||
      examCount > 0 ||
      completedStudyCount > 0 ||
      completedGoalCount > 0 ||
      activeDayCount > 0;
}
