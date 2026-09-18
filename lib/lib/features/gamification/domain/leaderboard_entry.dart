import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.score,
    required this.currentStreak,
    required this.longestStreak,
    required this.correctCount,
    required this.solvedCount,
    required this.examCount,
    required this.completedStudyCount,
    required this.completedGoalCount,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final int score;
  final int currentStreak;
  final int longestStreak;
  final int correctCount;
  final int solvedCount;
  final int examCount;
  final int completedStudyCount;
  final int completedGoalCount;
  final DateTime? updatedAt;

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final name = (map['displayName'] ?? '').toString().trim();
    return LeaderboardEntry(
      uid: uid,
      displayName: name.isEmpty ? 'Çalış 360 Öğrencisi' : name,
      score: (map['score'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      solvedCount: (map['solvedCount'] as num?)?.toInt() ?? 0,
      examCount: (map['examCount'] as num?)?.toInt() ?? 0,
      completedStudyCount: (map['completedStudyCount'] as num?)?.toInt() ?? 0,
      completedGoalCount: (map['completedGoalCount'] as num?)?.toInt() ?? 0,
      updatedAt: readDate(map['updatedAt']),
    );
  }
}
