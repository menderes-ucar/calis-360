import 'package:cloud_firestore/cloud_firestore.dart';

class AiSolutionStep {
  const AiSolutionStep({
    required this.title,
    required this.explanation,
    required this.expression,
  });

  final String title;
  final String explanation;
  final String expression;

  factory AiSolutionStep.fromMap(Map<String, dynamic> map) {
    return AiSolutionStep(
      title: (map['title'] ?? '').toString(),
      explanation: (map['explanation'] ?? '').toString(),
      expression: (map['expression'] ?? '').toString(),
    );
  }
}

class AiSolution {
  const AiSolution({
    required this.requestId,
    required this.recognizedQuestion,
    required this.shortAnswer,
    required this.finalAnswer,
    required this.steps,
    required this.conceptSummary,
    required this.confidence,
    required this.warnings,
    required this.subject,
    required this.topic,
    required this.examScope,
    required this.chargeMode,
    required this.creditCost,
    required this.remainingCredits,
    this.createdAt,
  });

  final String requestId;
  final String recognizedQuestion;
  final String shortAnswer;
  final String finalAnswer;
  final List<AiSolutionStep> steps;
  final String conceptSummary;
  final String confidence;
  final List<String> warnings;
  final String subject;
  final String topic;
  final String examScope;
  final String chargeMode;
  final int creditCost;
  final int remainingCredits;
  final DateTime? createdAt;

  bool get usedCredit => chargeMode == 'credit' && creditCost > 0;

  factory AiSolution.fromCallable(Map<String, dynamic> map) {
    final solution = Map<String, dynamic>.from(
      (map['solution'] as Map?) ?? const <String, dynamic>{},
    );
    final entitlement = Map<String, dynamic>.from(
      (map['entitlement'] as Map?) ?? const <String, dynamic>{},
    );

    return AiSolution(
      requestId: (map['requestId'] ?? '').toString(),
      recognizedQuestion: (solution['recognizedQuestion'] ?? '').toString(),
      shortAnswer: (solution['shortAnswer'] ?? '').toString(),
      finalAnswer: (solution['finalAnswer'] ?? '').toString(),
      steps: ((solution['steps'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => AiSolutionStep.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      conceptSummary: (solution['conceptSummary'] ?? '').toString(),
      confidence: (solution['confidence'] ?? 'medium').toString(),
      warnings: ((solution['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      subject: (solution['subject'] ?? '').toString(),
      topic: (solution['topic'] ?? '').toString(),
      examScope: (solution['examScope'] ?? '').toString(),
      chargeMode: (entitlement['chargeMode'] ?? 'included').toString(),
      creditCost: (entitlement['creditCost'] as num?)?.toInt() ?? 0,
      remainingCredits: (entitlement['remainingCredits'] as num?)?.toInt() ?? 0,
    );
  }

  factory AiSolution.fromHistoryDoc(String id, Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(
      (map['result'] as Map?) ?? const <String, dynamic>{},
    );
    final created = map['createdAt'];

    return AiSolution(
      requestId: id,
      recognizedQuestion: (result['recognizedQuestion'] ?? '').toString(),
      shortAnswer: (result['shortAnswer'] ?? '').toString(),
      finalAnswer: (result['finalAnswer'] ?? '').toString(),
      steps: ((result['steps'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => AiSolutionStep.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      conceptSummary: (result['conceptSummary'] ?? '').toString(),
      confidence: (result['confidence'] ?? 'medium').toString(),
      warnings: ((result['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      subject: (map['subject'] ?? result['subject'] ?? '').toString(),
      topic: (map['topic'] ?? result['topic'] ?? '').toString(),
      examScope: (map['examScope'] ?? result['examScope'] ?? '').toString(),
      chargeMode: (map['chargeMode'] ?? 'included').toString(),
      creditCost: (map['creditCost'] as num?)?.toInt() ?? 0,
      remainingCredits: (map['remainingCredits'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
