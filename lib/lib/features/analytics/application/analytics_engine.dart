import '../../ai_solver/domain/ai_solution.dart';
import '../../../models/dersProgrami.dart';
import '../../../models/hedef.dart';
import '../../../models/sinav.dart';
import '../../../models/soru.dart';
import '../domain/analytics_models.dart';

class AnalyticsEngine {
  const AnalyticsEngine();

  AnalyticsReport build({
    required List<Sinav> exams,
    required List<Soru> questions,
    required List<AiSolution> aiSolutions,
    required List<DersProgram> studyPlans,
    required List<Hedef> goals,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final datedExams = exams.where((e) => e.createdAt != null).toList()
      ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    final examTrend = datedExams
        .map(
          (exam) => AnalyticsTrendPoint(
            label: exam.sinavAd.trim().isEmpty ? exam.sinavTuru : exam.sinavAd,
            value: _totalNet(exam),
            date: exam.createdAt,
          ),
        )
        .toList(growable: false);

    final latestTotal = examTrend.isEmpty ? null : examTrend.last.value;
    final previousTotal = examTrend.length < 2
        ? null
        : examTrend[examTrend.length - 2].value;
    final totalDelta = latestTotal != null && previousTotal != null
        ? latestTotal - previousTotal
        : null;

    final questionBySubject = <String, List<Soru>>{};
    final questionByTopic = <String, List<Soru>>{};
    for (final question in questions) {
      final subject = _clean(question.soruDers, fallback: 'Diğer');
      final topic = _clean(question.soruKonu, fallback: 'Genel');
      questionBySubject.putIfAbsent(subject, () => <Soru>[]).add(question);
      questionByTopic
          .putIfAbsent(_topicKey(subject, topic), () => <Soru>[])
          .add(question);
    }

    final aiBySubject = <String, List<AiSolution>>{};
    final aiByTopic = <String, List<AiSolution>>{};
    for (final solution in aiSolutions) {
      final subject = _clean(solution.subject, fallback: 'Diğer');
      final topic = _clean(solution.topic, fallback: 'Genel');
      aiBySubject.putIfAbsent(subject, () => <AiSolution>[]).add(solution);
      if (topic != 'Genel') {
        aiByTopic
            .putIfAbsent(_topicKey(subject, topic), () => <AiSolution>[])
            .add(solution);
      }
    }

    final plansBySubject = <String, List<DersProgram>>{};
    final plansByTopic = <String, List<DersProgram>>{};
    for (final plan in studyPlans) {
      final subject = _clean(plan.dersProgramDersAd, fallback: 'Diğer');
      final topic = _clean(plan.dersProgramKonuAd, fallback: 'Genel');
      plansBySubject.putIfAbsent(subject, () => <DersProgram>[]).add(plan);
      plansByTopic
          .putIfAbsent(_topicKey(subject, topic), () => <DersProgram>[])
          .add(plan);
    }

    final examByTopic = <String, List<_ExamTopicEvidence>>{};
    for (final exam in datedExams) {
      for (final subjectEntry in exam.dersDetaylari.entries) {
        final subject = _clean(subjectEntry.key, fallback: 'Diğer');
        for (final topicEntry in subjectEntry.value.konular.entries) {
          final topic = _clean(topicEntry.key, fallback: 'Genel');
          if (topic == 'Genel') continue;
          final detail = topicEntry.value;
          if (detail.toplam == 0) continue;
          examByTopic
              .putIfAbsent(
                _topicKey(subject, topic),
                () => <_ExamTopicEvidence>[],
              )
              .add(
                _ExamTopicEvidence(
                  date: exam.createdAt!,
                  examLabel: exam.sinavAd.trim().isEmpty
                      ? exam.sinavTuru
                      : exam.sinavAd,
                  correct: detail.dogru,
                  wrong: detail.yanlis,
                  blank: detail.bos,
                ),
              );
        }
      }
    }

    final subjects = _buildSubjectAnalytics(
      exams: datedExams,
      questionBySubject: questionBySubject,
      aiBySubject: aiBySubject,
      plansBySubject: plansBySubject,
      now: referenceNow,
    );

    final topics = _buildTopicAnalytics(
      questionByTopic: questionByTopic,
      aiByTopic: aiByTopic,
      plansByTopic: plansByTopic,
      examByTopic: examByTopic,
      subjects: subjects,
      now: referenceNow,
    );

    final completedPlans = studyPlans.where((p) => p.tamamlandi).toList();
    final study = StudyAnalytics(
      totalPlanCount: studyPlans.length,
      completedPlanCount: completedPlans.length,
      totalPlannedHours: studyPlans.fold(
        0,
        (sum, p) => sum + p.dersProgramSaat,
      ),
      completedPlannedHours: completedPlans.fold(
        0,
        (sum, p) => sum + p.dersProgramSaat,
      ),
    );

    final completedGoals = goals.where((g) => g.tamamlandi).length;
    final overdueGoals = goals.where((goal) {
      if (goal.tamamlandi) return false;
      final deadline = DateTime(
        goal.hedefTarihi.year,
        goal.hedefTarihi.month,
        goal.hedefTarihi.day,
        23,
        59,
        59,
      );
      return deadline.isBefore(referenceNow);
    }).length;
    final goalAnalytics = GoalAnalytics(
      total: goals.length,
      completed: completedGoals,
      overduePending: overdueGoals,
    );

    final confidenceScore = _confidenceScore(
      exams: exams,
      questions: questions,
      aiSolutions: aiSolutions,
      studyPlans: studyPlans,
      goals: goals,
    );

    final insights = _buildInsights(
      totalDelta: totalDelta,
      overallTrend: _trendForDelta(totalDelta),
      subjects: subjects,
      topics: topics,
      study: study,
      goals: goalAnalytics,
      examCount: exams.length,
    );

    final recommendations = _buildRecommendations(
      subjects: subjects,
      topics: topics,
      study: study,
      goals: goalAnalytics,
      examCount: exams.length,
    );

    return AnalyticsReport(
      generatedAt: referenceNow,
      confidenceScore: confidenceScore,
      confidenceLabel: _confidenceLabel(confidenceScore),
      examCount: exams.length,
      datedExamCount: datedExams.length,
      aiSolveCount: aiSolutions.length,
      latestTotalNet: latestTotal,
      previousTotalNet: previousTotal,
      totalNetDelta: totalDelta,
      overallTrend: _trendForDelta(totalDelta),
      examTrend: examTrend,
      subjects: subjects,
      topics: topics,
      study: study,
      goals: goalAnalytics,
      insights: insights,
      recommendations: recommendations,
    );
  }

  List<SubjectAnalytics> _buildSubjectAnalytics({
    required List<Sinav> exams,
    required Map<String, List<Soru>> questionBySubject,
    required Map<String, List<AiSolution>> aiBySubject,
    required Map<String, List<DersProgram>> plansBySubject,
    required DateTime now,
  }) {
    final subjectNames = <String>{
      ...questionBySubject.keys,
      ...aiBySubject.keys,
      ...plansBySubject.keys,
      for (final exam in exams) ...exam.netler.keys.map(_cleanSubject),
    };

    final result = <SubjectAnalytics>[];
    for (final subject in subjectNames) {
      final values = <double>[];
      for (final exam in exams) {
        for (final entry in exam.netler.entries) {
          if (_cleanSubject(entry.key) == subject) {
            values.add(entry.value);
            break;
          }
        }
      }

      final latest = values.isEmpty ? 0.0 : values.last;
      final previousValues = values.length <= 1
          ? <double>[]
          : values.sublist(0, values.length - 1);
      final previousAverage = previousValues.isEmpty
          ? latest
          : previousValues.reduce((a, b) => a + b) / previousValues.length;
      final delta = values.length < 2 ? 0.0 : latest - previousAverage;

      final questions = questionBySubject[subject] ?? const <Soru>[];
      final difficult = questions
          .where((q) => !q.isCorrect && !q.isAiSaved)
          .toList();
      final recentDifficult = difficult
          .where((q) => _isRecent(q.createdAt, now, 14))
          .length;
      final ai = aiBySubject[subject] ?? const <AiSolution>[];
      final recentAi = ai.where((s) => _isRecent(s.createdAt, now, 14)).length;
      final plans = plansBySubject[subject] ?? const <DersProgram>[];
      final completed = plans.where((p) => p.tamamlandi).length;

      result.add(
        SubjectAnalytics(
          subject: subject,
          latestNet: latest,
          previousAverageNet: previousAverage,
          deltaNet: delta,
          trend: values.length < 2
              ? AnalyticsTrend.insufficient
              : _trendForDelta(delta),
          examCount: values.length,
          difficultQuestionCount: difficult.length,
          recentDifficultQuestionCount: recentDifficult,
          aiHelpCount: ai.length,
          recentAiHelpCount: recentAi,
          studyCompletionRate: plans.isEmpty ? null : completed / plans.length,
        ),
      );
    }

    result.sort((a, b) {
      final riskA =
          a.difficultQuestionCount +
          a.aiHelpCount +
          (a.trend == AnalyticsTrend.declining ? 5 : 0);
      final riskB =
          b.difficultQuestionCount +
          b.aiHelpCount +
          (b.trend == AnalyticsTrend.declining ? 5 : 0);
      return riskB.compareTo(riskA);
    });
    return result;
  }

  List<TopicAnalytics> _buildTopicAnalytics({
    required Map<String, List<Soru>> questionByTopic,
    required Map<String, List<AiSolution>> aiByTopic,
    required Map<String, List<DersProgram>> plansByTopic,
    required Map<String, List<_ExamTopicEvidence>> examByTopic,
    required List<SubjectAnalytics> subjects,
    required DateTime now,
  }) {
    final subjectMap = {for (final item in subjects) item.subject: item};
    final keys = <String>{
      ...questionByTopic.keys,
      ...aiByTopic.keys,
      ...plansByTopic.keys,
      ...examByTopic.keys,
    };
    final result = <TopicAnalytics>[];

    for (final key in keys) {
      final parts = key.split('\u0000');
      final subject = parts.first;
      final topic = parts.length > 1 ? parts[1] : 'Genel';
      if (topic == 'Genel') continue;

      final questions = questionByTopic[key] ?? const <Soru>[];
      final ai = aiByTopic[key] ?? const <AiSolution>[];
      final plans = plansByTopic[key] ?? const <DersProgram>[];
      final completed = plans.where((p) => p.tamamlandi).length;
      final examEvidence = [
        ...(examByTopic[key] ?? const <_ExamTopicEvidence>[]),
      ]..sort((a, b) => a.date.compareTo(b.date));
      final examCorrect = examEvidence.fold<int>(
        0,
        (sum, item) => sum + item.correct,
      );
      final examWrong = examEvidence.fold<int>(
        0,
        (sum, item) => sum + item.wrong,
      );
      final examBlank = examEvidence.fold<int>(
        0,
        (sum, item) => sum + item.blank,
      );
      final examQuestionCount = examCorrect + examWrong + examBlank;
      final examSuccessRate = examQuestionCount == 0
          ? null
          : (examCorrect / examQuestionCount) * 100.0;
      final latestExamSuccessRate = examEvidence.isEmpty
          ? null
          : examEvidence.last.successRate * 100.0;
      final previousExamSuccessRates = examEvidence.length <= 1
          ? const <double>[]
          : examEvidence
                .sublist(0, examEvidence.length - 1)
                .map((item) => item.successRate * 100.0)
                .toList(growable: false);
      final previousExamSuccessRate = previousExamSuccessRates.isEmpty
          ? null
          : previousExamSuccessRates.reduce((a, b) => a + b) /
                previousExamSuccessRates.length;
      final examSuccessDelta =
          latestExamSuccessRate != null && previousExamSuccessRate != null
          ? latestExamSuccessRate - previousExamSuccessRate
          : null;

      // AI'dan kaydedilen soru AI geçmişinde zaten sinyal olduğu için iki kez cezalandırılmaz.
      final manualQuestions = questions.where((q) => !q.isAiSaved).toList();
      final wrong = manualQuestions.where((q) => q.isWrong).length;
      final unresolved = manualQuestions.where((q) => q.isUnresolved).length;
      final review = manualQuestions.where((q) => q.needsReview).length;
      final correct = manualQuestions.where((q) => q.isCorrect).length;
      final difficult = wrong + unresolved + review;
      final recentDifficult = manualQuestions
          .where((q) => !q.isCorrect && _isRecent(q.createdAt, now, 14))
          .length;
      final recentAi = ai.where((s) => _isRecent(s.createdAt, now, 14)).length;

      final subjectAnalytics = subjectMap[subject];
      var mastery = 68.0;
      mastery -= wrong * 9;
      mastery -= unresolved * 11;
      mastery -= review * 6;
      mastery += correct * 6;
      mastery -= ai.length * 5;
      mastery -= recentAi * 2;
      mastery -= recentDifficult * 3;
      mastery += completed * 4;
      mastery -= (plans.length - completed) * 2;
      if (subjectAnalytics?.trend == AnalyticsTrend.improving) mastery += 5;
      if (subjectAnalytics?.trend == AnalyticsTrend.declining) mastery -= 7;

      // Sınavdaki konu kırılımı, konu hakimiyeti için en güçlü kanıtlardan biridir.
      if (examSuccessRate != null) {
        final examWeight =
            (0.35 + (examQuestionCount / 20.0).clamp(0.0, 1.0) * 0.35).clamp(
              0.35,
              0.70,
            );
        mastery = mastery * (1 - examWeight) + examSuccessRate * examWeight;
        if (examSuccessDelta != null) {
          mastery += (examSuccessDelta / 5.0).clamp(-8.0, 8.0);
        }
      }
      mastery = mastery.clamp(5, 95);

      var evidenceSignals =
          manualQuestions.length +
          ai.length +
          plans.length +
          examEvidence.length * 3;
      if ((subjectAnalytics?.examCount ?? 0) >= 2) {
        evidenceSignals += 2;
      }
      final confidence = (evidenceSignals * 11).clamp(0, 100).toInt();

      var priority = (100 - mastery).round();
      if (recentDifficult >= 2) priority += 8;
      if (recentAi >= 2) priority += 10;
      if (plans.isEmpty && difficult + ai.length >= 2) priority += 10;
      if (examSuccessRate != null && examSuccessRate < 50) priority += 12;
      if (examSuccessDelta != null && examSuccessDelta <= -10) priority += 12;
      priority = priority.clamp(0, 100);

      final reasons = <String>[];
      if (wrong > 0) reasons.add('$wrong soru yanlış işaretlenmiş.');
      if (unresolved > 0) reasons.add('$unresolved soru çözülememiş.');
      if (review > 0) reasons.add('$review soru tekrar bekliyor.');
      if (ai.isNotEmpty) {
        reasons.add('Bu konuda ${ai.length} kez AI yardımı kullanılmış.');
      }
      if (recentAi >= 2) {
        reasons.add('Son 14 günde $recentAi AI yardım isteği var.');
      }
      if (recentDifficult >= 2) {
        reasons.add(
          'Son 14 günde $recentDifficult yeni zorlanma kaydı oluşmuş.',
        );
      }
      if (completed > 0) reasons.add('$completed çalışma planı tamamlanmış.');
      if (plans.isNotEmpty && completed / plans.length < 0.6) {
        reasons.add('Çalışma planı tamamlama oranı düşük.');
      }
      if (examSuccessRate != null) {
        reasons.add(
          '${examEvidence.length} sınavda bu konudan $examQuestionCount soru: '
          '$examCorrect doğru, $examWrong yanlış, $examBlank boş; başarı %${examSuccessRate.round()}.',
        );
      }
      if (examSuccessDelta != null && examSuccessDelta.abs() >= 5) {
        reasons.add(
          examSuccessDelta > 0
              ? 'Son sınavdaki konu başarısı önceki sınav ortalamasına göre ${examSuccessDelta.toStringAsFixed(1)} puan yükseldi.'
              : 'Son sınavdaki konu başarısı önceki sınav ortalamasına göre ${examSuccessDelta.abs().toStringAsFixed(1)} puan düştü.',
        );
      }
      if (subjectAnalytics?.trend == AnalyticsTrend.declining) {
        reasons.add('$subject sınav performansı düşüş eğiliminde.');
      }
      if (subjectAnalytics?.trend == AnalyticsTrend.improving) {
        reasons.add('$subject sınav performansı gelişiyor.');
      }

      result.add(
        TopicAnalytics(
          subject: subject,
          topic: topic,
          masteryScore: mastery.round(),
          masteryConfidence: confidence,
          difficultQuestionCount: difficult,
          recentDifficultQuestionCount: recentDifficult,
          wrongQuestionCount: wrong,
          unresolvedQuestionCount: unresolved,
          reviewQuestionCount: review,
          correctQuestionCount: correct,
          aiHelpCount: ai.length,
          recentAiHelpCount: recentAi,
          plannedStudyCount: plans.length,
          completedStudyCount: completed,
          examOccurrenceCount: examEvidence.length,
          examQuestionCount: examQuestionCount,
          examCorrectCount: examCorrect,
          examWrongCount: examWrong,
          examBlankCount: examBlank,
          examSuccessRate: examSuccessRate,
          latestExamSuccessRate: latestExamSuccessRate,
          examSuccessDelta: examSuccessDelta,
          priorityScore: priority,
          reasons: reasons,
        ),
      );
    }

    result.sort((a, b) {
      final p = b.priorityScore.compareTo(a.priorityScore);
      return p != 0 ? p : a.masteryScore.compareTo(b.masteryScore);
    });
    return result;
  }

  List<AnalyticsInsight> _buildInsights({
    required double? totalDelta,
    required AnalyticsTrend overallTrend,
    required List<SubjectAnalytics> subjects,
    required List<TopicAnalytics> topics,
    required StudyAnalytics study,
    required GoalAnalytics goals,
    required int examCount,
  }) {
    final insights = <AnalyticsInsight>[];

    if (examCount < 2) {
      insights.add(
        const AnalyticsInsight(
          title: 'Sınav trendi için daha fazla veri gerekli',
          detail:
              'En az 2 sınav eklediğinde net değişimini güvenilir biçimde karşılaştırabilirim.',
          tone: AnalyticsInsightTone.neutral,
        ),
      );
    } else if (overallTrend == AnalyticsTrend.improving && totalDelta != null) {
      insights.add(
        AnalyticsInsight(
          title: 'Toplam net yükseliyor',
          detail:
              'Son sınavın bir önceki sınava göre ${totalDelta.toStringAsFixed(2)} net daha yüksek.',
          tone: AnalyticsInsightTone.positive,
        ),
      );
    } else if (overallTrend == AnalyticsTrend.declining && totalDelta != null) {
      insights.add(
        AnalyticsInsight(
          title: 'Son sınavda net kaybı var',
          detail:
              'Toplam netin bir önceki sınava göre ${totalDelta.abs().toStringAsFixed(2)} düştü.',
          tone: AnalyticsInsightTone.warning,
        ),
      );
    }

    final weakTopic = topics
        .where((t) => t.masteryConfidence >= 25)
        .firstOrNull;
    if (weakTopic != null && weakTopic.masteryScore < 55) {
      insights.add(
        AnalyticsInsight(
          title: '${weakTopic.topic} konusu zayıf sinyal veriyor',
          detail: 'Tahmini konu başarı skoru %${weakTopic.masteryScore}.',
          tone: weakTopic.masteryScore < 35
              ? AnalyticsInsightTone.critical
              : AnalyticsInsightTone.warning,
          evidence: weakTopic.reasons,
        ),
      );
    }

    final examDecliningTopics =
        topics
            .where(
              (t) => t.examSuccessDelta != null && t.examSuccessDelta! <= -10,
            )
            .toList()
          ..sort((a, b) => a.examSuccessDelta!.compareTo(b.examSuccessDelta!));
    if (examDecliningTopics.isNotEmpty) {
      final item = examDecliningTopics.first;
      insights.add(
        AnalyticsInsight(
          title: '${item.topic} sınav performansı geriliyor',
          detail:
              'Son sınavdaki konu başarısı önceki sınav ortalamasına göre ${item.examSuccessDelta!.abs().toStringAsFixed(1)} puan daha düşük.',
          tone: AnalyticsInsightTone.warning,
          evidence: item.reasons,
        ),
      );
    }

    final aiHeavy = topics.where((t) => t.recentAiHelpCount >= 2).toList()
      ..sort((a, b) => b.recentAiHelpCount.compareTo(a.recentAiHelpCount));
    if (aiHeavy.isNotEmpty) {
      final item = aiHeavy.first;
      insights.add(
        AnalyticsInsight(
          title: '${item.topic} için sık AI desteği kullanılıyor',
          detail:
              'Son 14 günde ${item.recentAiHelpCount} kez AI çözüm desteği alınmış.',
          tone: AnalyticsInsightTone.warning,
          evidence: item.reasons,
        ),
      );
    }

    if (study.totalPlanCount >= 3) {
      final percent = (study.completionRate * 100).round();
      insights.add(
        AnalyticsInsight(
          title: 'Program tamamlama oranı %$percent',
          detail: percent >= 75
              ? 'Çalışma planını düzenli uyguluyorsun.'
              : 'Planlanan çalışmaların önemli bir kısmı tamamlanmıyor.',
          tone: percent >= 75
              ? AnalyticsInsightTone.positive
              : AnalyticsInsightTone.warning,
        ),
      );
    }

    if (goals.overduePending > 0) {
      insights.add(
        AnalyticsInsight(
          title: '${goals.overduePending} gecikmiş hedef var',
          detail:
              'Süresi geçen tamamlanmamış hedefleri yeniden planlamak çalışma düzenini güçlendirir.',
          tone: AnalyticsInsightTone.warning,
        ),
      );
    }

    return insights.take(7).toList(growable: false);
  }

  List<AnalyticsRecommendation> _buildRecommendations({
    required List<SubjectAnalytics> subjects,
    required List<TopicAnalytics> topics,
    required StudyAnalytics study,
    required GoalAnalytics goals,
    required int examCount,
  }) {
    final recommendations = <AnalyticsRecommendation>[];

    for (final topic in topics.take(5)) {
      if (topic.masteryConfidence < 20 || topic.priorityScore < 30) continue;
      final action = topic.aiHelpCount >= 2 && topic.difficultQuestionCount >= 2
          ? 'Konu anlatımına kısa bir dönüş yap, ardından 15-20 temel/orta seviye soru çöz. Sonra AI kullanmadan 5 kontrol sorusu dene.'
          : topic.studyCompletionRate != null &&
                topic.studyCompletionRate! < 0.6
          ? 'Bu konu için küçük ve tamamlanabilir bir çalışma bloğu planla; ardından zorlandığın soruları tekrar çöz.'
          : 'Yanlış ve çözülemeyen soruları sınıflandır, kısa tekrar yap ve hedefli soru pratiği uygula.';

      recommendations.add(
        AnalyticsRecommendation(
          title: '${topic.topic} konusunu güçlendir',
          action: action,
          reason: topic.examSuccessRate == null
              ? 'Konu başarı skoru %${topic.masteryScore} ve öncelik puanı ${topic.priorityScore}.'
              : 'Konu başarı skoru %${topic.masteryScore}; sınav konu başarısı %${topic.examSuccessRate!.round()} ve öncelik puanı ${topic.priorityScore}.',
          priority: topic.priorityScore,
          subject: topic.subject,
          topic: topic.topic,
          evidence: topic.reasons,
        ),
      );
    }

    for (final subject
        in subjects.where((s) => s.trend == AnalyticsTrend.declining).take(2)) {
      recommendations.add(
        AnalyticsRecommendation(
          title: '${subject.subject} performansını toparla',
          action:
              'Son sınav değişimini, zorlandığın konuları ve AI yardım geçmişini birlikte inceleyip bu derse ek çalışma bloğu ayır.',
          reason:
              'Son netin önceki ortalamanın ${subject.deltaNet.abs().toStringAsFixed(2)} altında.',
          priority: 72,
          subject: subject.subject,
          evidence: [
            'Sınav kaydı: ${subject.examCount}',
            'Zor soru: ${subject.difficultQuestionCount}',
            'AI yardım: ${subject.aiHelpCount}',
          ],
        ),
      );
    }

    if (study.totalPlanCount >= 3 && study.completionRate < 0.65) {
      recommendations.add(
        AnalyticsRecommendation(
          title: 'Çalışma planını sadeleştir',
          action:
              'Bir sonraki hafta için daha az ama tamamlanabilir çalışma bloğu planla.',
          reason:
              'Mevcut program tamamlama oranı %${(study.completionRate * 100).round()}.',
          priority: 68,
        ),
      );
    }

    if (goals.overduePending > 0) {
      recommendations.add(
        AnalyticsRecommendation(
          title: 'Gecikmiş hedefleri yeniden planla',
          action:
              'Süresi geçmiş hedefleri küçük parçalara böl ve gerçekçi yeni tarih ver.',
          reason:
              '${goals.overduePending} hedef süresi geçtiği halde tamamlanmamış.',
          priority: 58,
        ),
      );
    }

    if (examCount < 2) {
      recommendations.add(
        const AnalyticsRecommendation(
          title: 'Bir sınav daha ekle',
          action:
              'İkinci sınav sonucundan sonra ders ve toplam net gelişimini karşılaştır.',
          reason:
              'Tek sınavla yükseliş veya düşüş trendi güvenilir biçimde ölçülemez.',
          priority: 50,
        ),
      );
    }

    recommendations.sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations.take(8).toList(growable: false);
  }

  int _confidenceScore({
    required List<Sinav> exams,
    required List<Soru> questions,
    required List<AiSolution> aiSolutions,
    required List<DersProgram> studyPlans,
    required List<Hedef> goals,
  }) {
    var score = 0;
    score += _scaled(
      exams.where((e) => e.createdAt != null).length,
      target: 6,
      max: 30,
    );
    score += _scaled(
      exams.where((e) => e.hasDetailedBreakdown).length,
      target: 4,
      max: 10,
    );
    score += _scaled(
      questions.where((q) => q.createdAt != null).length,
      target: 20,
      max: 20,
    );
    score += _scaled(
      aiSolutions.where((a) => a.createdAt != null).length,
      target: 15,
      max: 15,
    );
    score += _scaled(studyPlans.length, target: 12, max: 20);
    score += _scaled(goals.length, target: 6, max: 5);

    var sources = 0;
    if (exams.isNotEmpty) sources++;
    if (questions.isNotEmpty) sources++;
    if (aiSolutions.isNotEmpty) sources++;
    if (studyPlans.isNotEmpty) sources++;
    if (goals.isNotEmpty) sources++;
    if (sources >= 3) score += 5;
    return score.clamp(0, 100).toInt();
  }

  bool _isRecent(DateTime? date, DateTime now, int days) {
    if (date == null) return false;
    final diff = now.difference(date).inDays;
    return diff >= 0 && diff <= days;
  }

  int _scaled(int value, {required int target, required int max}) {
    if (value <= 0) return 0;
    return ((value / target).clamp(0.0, 1.0) * max).round();
  }

  String _confidenceLabel(int score) {
    if (score >= 75) return 'Yüksek';
    if (score >= 45) return 'Orta';
    return 'Düşük';
  }

  AnalyticsTrend _trendForDelta(double? delta) {
    if (delta == null) return AnalyticsTrend.insufficient;
    if (delta >= 1) return AnalyticsTrend.improving;
    if (delta <= -1) return AnalyticsTrend.declining;
    return AnalyticsTrend.stable;
  }

  double _totalNet(Sinav exam) =>
      exam.netler.values.fold(0.0, (sum, value) => sum + value);
  String _cleanSubject(String value) => _clean(value, fallback: 'Diğer');
  String _clean(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _topicKey(String subject, String topic) => '$subject\u0000$topic';
}

class _ExamTopicEvidence {
  const _ExamTopicEvidence({
    required this.date,
    required this.examLabel,
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final DateTime date;
  final String examLabel;
  final int correct;
  final int wrong;
  final int blank;

  int get total => correct + wrong + blank;
  double get successRate => total == 0 ? 0 : correct / total;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
