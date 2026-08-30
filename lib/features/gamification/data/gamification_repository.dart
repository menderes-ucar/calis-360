import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/gamification_summary.dart';
import '../domain/leaderboard_entry.dart';

class GamificationRepository {
  GamificationRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _activityCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('studyActivityDays');

  CollectionReference<Map<String, dynamic>> get _leaderboard =>
      _firestore.collection('leaderboard');

  Stream<List<DateTime>> watchActivityDays() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <DateTime>[]);

    return _activityCollection(uid).snapshots().map((snapshot) {
      final days = <DateTime>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final key = (data['dateKey'] ?? doc.id).toString();
        final parsed = DateTime.tryParse(key);
        if (parsed != null) {
          days.add(DateTime(parsed.year, parsed.month, parsed.day));
        }
      }
      return days;
    });
  }

  Future<void> recordActivity({required String type}) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    await _activityCollection(uid).doc(dateKey).set({
      'dateKey': dateKey,
      'types': FieldValue.arrayUnion([type]),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncLeaderboard({
    required String displayName,
    required GamificationSummary summary,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final safeName = displayName.trim().isEmpty
        ? 'Çalış 360 Öğrencisi'
        : displayName.trim();

    await _leaderboard.doc(uid).set({
      'uid': uid,
      'displayName': safeName,
      'score': summary.score,
      'currentStreak': summary.currentStreak,
      'longestStreak': summary.longestStreak,
      'correctCount': summary.correctCount,
      'wrongCount': summary.wrongCount,
      'solvedCount': summary.solvedCount,
      'examCount': summary.examCount,
      'completedStudyCount': summary.completedStudyCount,
      'completedGoalCount': summary.completedGoalCount,
      'activeDayCount': summary.activeDayCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> getCurrentUserRank() async {
    final uid = _uid;
    if (uid == null) return 0;

    final mySnapshot = await _leaderboard.doc(uid).get();
    final myData = mySnapshot.data();
    if (myData == null) return 0;

    final me = LeaderboardEntry.fromMap(uid, myData);

    final higherScoreCount = await _leaderboard
        .where('score', isGreaterThan: me.score)
        .count()
        .get();

    final equalScoreSnapshot = await _leaderboard
        .where('score', isEqualTo: me.score)
        .get();

    final equalScoreEntries = equalScoreSnapshot.docs
        .map((doc) => LeaderboardEntry.fromMap(doc.id, doc.data()))
        .toList();

    equalScoreEntries.sort(_compareLeaderboardEntries);

    final equalScoreIndex = equalScoreEntries.indexWhere(
      (entry) => entry.uid == uid,
    );

    return (higherScoreCount.count ?? 0) +
        (equalScoreIndex < 0 ? 0 : equalScoreIndex) +
        1;
  }

  Stream<List<LeaderboardEntry>> watchTopLeaderboard({int limit = 100}) {
    return _leaderboard
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => LeaderboardEntry.fromMap(doc.id, doc.data()))
              .toList(growable: false);

          final sorted = List<LeaderboardEntry>.from(items)
            ..sort(_compareLeaderboardEntries);
          return sorted;
        });
  }
}

int _compareLeaderboardEntries(LeaderboardEntry a, LeaderboardEntry b) {
  final score = b.score.compareTo(a.score);
  if (score != 0) return score;

  final longest = b.longestStreak.compareTo(a.longestStreak);
  if (longest != 0) return longest;

  final correct = b.correctCount.compareTo(a.correctCount);
  if (correct != 0) return correct;

  final updatedA = a.updatedAt?.millisecondsSinceEpoch ?? 0;
  final updatedB = b.updatedAt?.millisecondsSinceEpoch ?? 0;
  final updated = updatedA.compareTo(updatedB);
  if (updated != 0) return updated;

  return a.uid.compareTo(b.uid);
}
