enum StudyPlanMode {
  aiTopics('ai_topics'),
  manualTopics('manual_topics'),
  subjectsOnly('subjects_only');

  const StudyPlanMode(this.value);
  final String value;
}

class StudyPlanRequest {
  const StudyPlanRequest({
    required this.examScope,
    required this.field,
    required this.dailyHours,
    required this.studyDays,
    required this.offDay,
    required this.intensity,
    required this.weakSubjects,
    required this.mode,
    required this.selectedSubjects,
    required this.selectedTopics,
    required this.targetWeek,
  });

  final String examScope;
  final String field;
  final int dailyHours;
  final int studyDays;
  final String? offDay;
  final String intensity;
  final List<String> weakSubjects;
  final StudyPlanMode mode;
  final List<String> selectedSubjects;
  final Map<String, List<String>> selectedTopics;
  final int targetWeek;

  Map<String, dynamic> toJson() => {
    'examScope': examScope,
    'field': field,
    'dailyHours': dailyHours,
    'studyDays': studyDays,
    'offDay': offDay,
    'intensity': intensity,
    'weakSubjects': weakSubjects,
    'mode': mode.value,
    'selectedSubjects': selectedSubjects,
    'selectedTopics': selectedTopics,
    'targetWeek': targetWeek,
  };
}

class GeneratedStudySession {
  const GeneratedStudySession({
    required this.day,
    required this.examType,
    required this.subject,
    required this.topic,
    required this.startHour,
    required this.durationMinutes,
  });

  final String day;
  final String examType;
  final String subject;
  final String topic;
  final int startHour;
  final int durationMinutes;

  factory GeneratedStudySession.fromMap(Map<String, dynamic> map) {
    int readInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return GeneratedStudySession(
      day: (map['day'] ?? '').toString().trim(),
      examType: (map['examType'] ?? map['exam'] ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      topic: (map['topic'] ?? map['task'] ?? '').toString().trim(),
      startHour: readInt(map['startHour'], 9).clamp(0, 23).toInt(),
      durationMinutes: readInt(
        map['durationMinutes'],
        60,
      ).clamp(20, 240).toInt(),
    );
  }
}

class GeneratedStudyPlan {
  const GeneratedStudyPlan({
    required this.title,
    required this.summary,
    required this.sessions,
    required this.creditCost,
    required this.remainingCredits,
  });

  final String title;
  final String summary;
  final List<GeneratedStudySession> sessions;
  final int creditCost;
  final int remainingCredits;

  factory GeneratedStudyPlan.fromCallable(Map<String, dynamic> raw) {
    final root = raw['plan'] is Map
        ? Map<String, dynamic>.from(raw['plan'] as Map)
        : raw;

    final sessions = <GeneratedStudySession>[];
    final directSessions = root['sessions'];
    if (directSessions is List) {
      for (final item in directSessions.whereType<Map>()) {
        sessions.add(
          GeneratedStudySession.fromMap(Map<String, dynamic>.from(item)),
        );
      }
    }

    final days = root['days'];
    if (days is List) {
      for (final dayItem in days.whereType<Map>()) {
        final dayMap = Map<String, dynamic>.from(dayItem);
        final day = (dayMap['day'] ?? '').toString();
        final daySessions = dayMap['sessions'];
        if (daySessions is! List) continue;
        for (final item in daySessions.whereType<Map>()) {
          final sessionMap = Map<String, dynamic>.from(item);
          sessionMap.putIfAbsent('day', () => day);
          sessions.add(GeneratedStudySession.fromMap(sessionMap));
        }
      }
    }

    return GeneratedStudyPlan(
      title: (root['title'] ?? 'AI Haftalık Çalışma Programı').toString(),
      summary: (root['summary'] ?? '').toString(),
      sessions: sessions,
      creditCost:
          ((raw['entitlement'] is Map
                      ? (raw['entitlement'] as Map)['creditCost']
                      : null)
                  as num?)
              ?.toInt() ??
          10,
      remainingCredits:
          ((raw['entitlement'] is Map
                      ? (raw['entitlement'] as Map)['remainingCredits']
                      : null)
                  as num?)
              ?.toInt() ??
          0,
    );
  }
}
