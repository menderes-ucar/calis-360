enum AnalyticsTrend { improving, stable, declining, insufficient }

enum AnalyticsInsightTone { positive, neutral, warning, critical }

class AnalyticsTrendPoint {
  const AnalyticsTrendPoint({
    required this.label,
    required this.value,
    this.date,
  });

  final String label;
  final double value;
  final DateTime? date;
}

class SubjectAnalytics {
  const SubjectAnalytics({
    required this.subject,
    required this.latestNet,
    required this.previousAverageNet,
    required this.deltaNet,
    required this.trend,
    required this.examCount,
    required this.difficultQuestionCount,
    required this.recentDifficultQuestionCount,
    required this.aiHelpCount,
    required this.recentAiHelpCount,
    required this.studyCompletionRate,
  });

  final String subject;
  final double latestNet;
  final double previousAverageNet;
  final double deltaNet;
  final AnalyticsTrend trend;
  final int examCount;
  final int difficultQuestionCount;
  final int recentDifficultQuestionCount;
  final int aiHelpCount;
  final int recentAiHelpCount;
  final double? studyCompletionRate;
}

class TopicAnalytics {
  const TopicAnalytics({
    required this.subject,
    required this.topic,
    required this.masteryScore,
    required this.masteryConfidence,
    required this.difficultQuestionCount,
    required this.recentDifficultQuestionCount,
    required this.wrongQuestionCount,
    required this.unresolvedQuestionCount,
    required this.reviewQuestionCount,
    required this.correctQuestionCount,
    required this.aiHelpCount,
    required this.recentAiHelpCount,
    required this.plannedStudyCount,
    required this.completedStudyCount,
    required this.examOccurrenceCount,
    required this.examQuestionCount,
    required this.examCorrectCount,
    required this.examWrongCount,
    required this.examBlankCount,
    required this.examSuccessRate,
    required this.latestExamSuccessRate,
    required this.examSuccessDelta,
    required this.priorityScore,
    required this.reasons,
  });

  final String subject;
  final String topic;

  /// 0-100 arası tahmini konu hakimiyet skoru. Ham sınav yüzdesi değildir;
  /// kayıtlı yanlış/çözülemeyen soru, AI yardım ihtiyacı, çalışma ve ders trendi
  /// birlikte değerlendirilir.
  final int masteryScore;
  final int masteryConfidence;

  final int difficultQuestionCount;
  final int recentDifficultQuestionCount;
  final int wrongQuestionCount;
  final int unresolvedQuestionCount;
  final int reviewQuestionCount;
  final int correctQuestionCount;
  final int aiHelpCount;
  final int recentAiHelpCount;
  final int plannedStudyCount;
  final int completedStudyCount;

  /// Konu kırılımı girilmiş sınavlardan gelen gerçek performans sinyalleri.
  final int examOccurrenceCount;
  final int examQuestionCount;
  final int examCorrectCount;
  final int examWrongCount;
  final int examBlankCount;
  final double? examSuccessRate;
  final double? latestExamSuccessRate;
  final double? examSuccessDelta;

  final int priorityScore;
  final List<String> reasons;

  double? get studyCompletionRate =>
      plannedStudyCount == 0 ? null : completedStudyCount / plannedStudyCount;

  String get masteryLabel {
    if (masteryConfidence < 25) return 'Veri az';
    if (masteryScore >= 80) return 'Güçlü';
    if (masteryScore >= 65) return 'İyi';
    if (masteryScore >= 50) return 'Orta';
    if (masteryScore >= 35) return 'Zayıf';
    return 'Kritik';
  }
}

class StudyAnalytics {
  const StudyAnalytics({
    required this.totalPlanCount,
    required this.completedPlanCount,
    required this.totalPlannedHours,
    required this.completedPlannedHours,
  });

  final int totalPlanCount;
  final int completedPlanCount;
  final int totalPlannedHours;
  final int completedPlannedHours;

  double get completionRate =>
      totalPlanCount == 0 ? 0 : completedPlanCount / totalPlanCount;
}

class GoalAnalytics {
  const GoalAnalytics({
    required this.total,
    required this.completed,
    required this.overduePending,
  });

  final int total;
  final int completed;
  final int overduePending;

  double get completionRate => total == 0 ? 0 : completed / total;
}

class AnalyticsInsight {
  const AnalyticsInsight({
    required this.title,
    required this.detail,
    required this.tone,
    this.evidence = const <String>[],
  });

  final String title;
  final String detail;
  final AnalyticsInsightTone tone;
  final List<String> evidence;
}

class AnalyticsRecommendation {
  const AnalyticsRecommendation({
    required this.title,
    required this.action,
    required this.reason,
    required this.priority,
    this.subject,
    this.topic,
    this.evidence = const <String>[],
  });

  final String title;
  final String action;
  final String reason;
  final int priority;
  final String? subject;
  final String? topic;
  final List<String> evidence;
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.generatedAt,
    required this.confidenceScore,
    required this.confidenceLabel,
    required this.examCount,
    required this.datedExamCount,
    required this.aiSolveCount,
    required this.latestTotalNet,
    required this.previousTotalNet,
    required this.totalNetDelta,
    required this.overallTrend,
    required this.examTrend,
    required this.subjects,
    required this.topics,
    required this.study,
    required this.goals,
    required this.insights,
    required this.recommendations,
  });

  final DateTime generatedAt;
  final int confidenceScore;
  final String confidenceLabel;
  final int examCount;
  final int datedExamCount;
  final int aiSolveCount;
  final double? latestTotalNet;
  final double? previousTotalNet;
  final double? totalNetDelta;
  final AnalyticsTrend overallTrend;
  final List<AnalyticsTrendPoint> examTrend;
  final List<SubjectAnalytics> subjects;
  final List<TopicAnalytics> topics;
  final StudyAnalytics study;
  final GoalAnalytics goals;
  final List<AnalyticsInsight> insights;
  final List<AnalyticsRecommendation> recommendations;

  bool get hasUsefulData =>
      examCount > 0 ||
      aiSolveCount > 0 ||
      topics.isNotEmpty ||
      study.totalPlanCount > 0 ||
      goals.total > 0;
}
