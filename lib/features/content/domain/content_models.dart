class StudySubject {
  const StudySubject({
    required this.id,
    required this.name,
    required this.examGroup,
    required this.iconKey,
    required this.order,
  });

  final String id;
  final String name;
  final String examGroup;
  final String iconKey;
  final int order;

  factory StudySubject.fromMap(String id, Map<String, dynamic> map) {
    return StudySubject(
      id: id,
      name: (map['name'] ?? '').toString(),
      examGroup: (map['examGroup'] ?? 'TYT').toString(),
      iconKey: (map['iconKey'] ?? 'school').toString(),
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudyUnit {
  const StudyUnit({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.order,
    required this.topicCount,
  });

  final String id;
  final String subjectId;
  final String name;
  final int order;
  final int topicCount;

  factory StudyUnit.fromMap(
    String id,
    String subjectId,
    Map<String, dynamic> map,
  ) {
    return StudyUnit(
      id: id,
      subjectId: subjectId,
      name: (map['name'] ?? '').toString(),
      order: (map['order'] as num?)?.toInt() ?? 0,
      topicCount: (map['topicCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudyTopic {
  const StudyTopic({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.title,
    required this.shortDescription,
    required this.examScopes,
    required this.contentStatus,
    required this.contentVersion,
    required this.learningObjectives,
    required this.narrationText,
    required this.summary,
    required this.keyPoints,
    required this.formulas,
    required this.commonMistakes,
    required this.examples,
    required this.quiz,
    required this.readAccess,
    required this.audioAccess,
    required this.audioCreditCost,
    required this.estimatedReadMinutes,
    required this.order,
  });

  final String id;
  final String subjectId;
  final String unitId;
  final String title;
  final String shortDescription;
  final List<String> examScopes;
  final String contentStatus;
  final int contentVersion;
  final List<String> learningObjectives;
  final String narrationText;
  final String summary;
  final List<String> keyPoints;
  final List<String> formulas;
  final List<String> commonMistakes;
  final List<StudyExample> examples;
  final List<StudyQuizQuestion> quiz;
  final String readAccess;
  final String audioAccess;
  final int audioCreditCost;
  final int estimatedReadMinutes;
  final int order;

  bool get isReadingFree => readAccess == 'free';
  bool get isPublished => contentStatus == 'published';
  bool get hasNarration => narrationText.trim().isNotEmpty;

  factory StudyTopic.fromMap(
    String id,
    String subjectId,
    String unitId,
    Map<String, dynamic> map,
  ) {
    List<String> strings(dynamic value) {
      if (value is! List) return const [];
      return value.map((e) => e.toString()).toList(growable: false);
    }

    return StudyTopic(
      id: id,
      subjectId: subjectId,
      unitId: unitId,
      title: (map['title'] ?? '').toString(),
      shortDescription: (map['shortDescription'] ?? '').toString(),
      examScopes: strings(map['examScopes']),
      contentStatus: (map['contentStatus'] ?? 'catalog').toString(),
      contentVersion: (map['contentVersion'] as num?)?.toInt() ?? 1,
      learningObjectives: strings(map['learningObjectives']),
      narrationText: (map['narrationText'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      keyPoints: strings(map['keyPoints']),
      formulas: strings(map['formulas']),
      commonMistakes: strings(map['commonMistakes']),
      examples: (map['examples'] is List)
          ? (map['examples'] as List)
                .whereType<Map>()
                .map((e) => StudyExample.fromMap(Map<String, dynamic>.from(e)))
                .toList(growable: false)
          : const [],
      quiz: (map['quiz'] is List)
          ? (map['quiz'] as List)
                .whereType<Map>()
                .map(
                  (e) =>
                      StudyQuizQuestion.fromMap(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const [],
      readAccess: (map['readAccess'] ?? 'free').toString(),
      audioAccess: (map['audioAccess'] ?? 'credits').toString(),
      audioCreditCost: (map['audioCreditCost'] as num?)?.toInt() ?? 3,
      estimatedReadMinutes: (map['estimatedReadMinutes'] as num?)?.toInt() ?? 3,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudyExample {
  const StudyExample({required this.question, required this.solution});

  final String question;
  final String solution;

  factory StudyExample.fromMap(Map<String, dynamic> map) {
    return StudyExample(
      question: (map['question'] ?? '').toString(),
      solution: (map['solution'] ?? '').toString(),
    );
  }
}

class StudyQuizQuestion {
  const StudyQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  factory StudyQuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    return StudyQuizQuestion(
      question: (map['question'] ?? '').toString(),
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString()).toList(growable: false)
          : const [],
      correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: (map['explanation'] ?? '').toString(),
    );
  }
}
