import 'package:cloud_firestore/cloud_firestore.dart';

class Soru {
  const Soru({
    required this.soruId,
    required this.soruAd,
    required this.soruDers,
    required this.soruKonu,
    required this.soruCevap,
    this.soruDurum = 'unresolved',
    this.source = 'manual',
    this.aiRequestId,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String soruId;
  final String soruAd;
  final String soruDers;
  final String soruKonu;
  final String soruCevap;

  /// unresolved | wrong | needs_review | correct
  final String soruDurum;

  /// manual | ai_saved | exam_review | other
  final String source;
  final String? aiRequestId;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCorrect => soruDurum == 'correct';
  bool get isWrong => soruDurum == 'wrong';
  bool get isUnresolved => soruDurum == 'unresolved';
  bool get needsReview => soruDurum == 'needs_review';
  bool get isAiSaved => source == 'ai_saved';

  factory Soru.fromJson(Map<dynamic, dynamic> json, String key) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawStatus = (json['soruDurum'] ?? json['status'] ?? 'unresolved')
        .toString()
        .trim()
        .toLowerCase();
    const allowedStatuses = <String>{
      'unresolved',
      'wrong',
      'needs_review',
      'correct',
    };

    final rawSource = (json['source'] ?? 'manual').toString().trim();

    return Soru(
      soruId: key,
      soruAd: (json['soruAd'] ?? '').toString(),
      soruDers: (json['soruDers'] ?? '').toString(),
      soruKonu: (json['soruKonu'] ?? '').toString(),
      soruCevap: (json['soruCevap'] ?? '').toString(),
      soruDurum: allowedStatuses.contains(rawStatus) ? rawStatus : 'unresolved',
      source: rawSource.isEmpty ? 'manual' : rawSource,
      aiRequestId: json['aiRequestId']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soruAd': soruAd,
      'soruDers': soruDers,
      'soruKonu': soruKonu,
      'soruCevap': soruCevap,
      'soruDurum': soruDurum,
      'source': source,
      if (aiRequestId != null && aiRequestId!.trim().isNotEmpty)
        'aiRequestId': aiRequestId,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl,
    };
  }
}
