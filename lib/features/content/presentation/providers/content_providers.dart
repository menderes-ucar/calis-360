import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/content_repository.dart';
import '../../domain/content_models.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return HybridContentRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

final subjectsProvider = FutureProvider<List<StudySubject>>((ref) {
  return ref.watch(contentRepositoryProvider).getSubjects();
});

final unitsProvider = FutureProvider.family<List<StudyUnit>, String>((
  ref,
  subjectId,
) {
  return ref.watch(contentRepositoryProvider).getUnits(subjectId);
});

class TopicListArgs {
  const TopicListArgs({required this.subjectId, required this.unitId});

  final String subjectId;
  final String unitId;

  @override
  bool operator ==(Object other) {
    return other is TopicListArgs &&
        other.subjectId == subjectId &&
        other.unitId == unitId;
  }

  @override
  int get hashCode => Object.hash(subjectId, unitId);
}

final topicsProvider = FutureProvider.family<List<StudyTopic>, TopicListArgs>((
  ref,
  args,
) {
  return ref
      .watch(contentRepositoryProvider)
      .getTopics(args.subjectId, args.unitId);
});

class TopicDetailArgs {
  const TopicDetailArgs({
    required this.subjectId,
    required this.unitId,
    required this.topicId,
  });

  final String subjectId;
  final String unitId;
  final String topicId;

  @override
  bool operator ==(Object other) {
    return other is TopicDetailArgs &&
        other.subjectId == subjectId &&
        other.unitId == unitId &&
        other.topicId == topicId;
  }

  @override
  int get hashCode => Object.hash(subjectId, unitId, topicId);
}

final topicDetailProvider = FutureProvider.family<StudyTopic?, TopicDetailArgs>(
  (ref, args) {
    return ref
        .watch(contentRepositoryProvider)
        .getTopic(args.subjectId, args.unitId, args.topicId);
  },
);

class PersonalSummaryArgs {
  const PersonalSummaryArgs({
    required this.subjectId,
    required this.unitId,
    required this.topicId,
  });

  final String subjectId;
  final String unitId;
  final String topicId;

  @override
  bool operator ==(Object other) =>
      other is PersonalSummaryArgs &&
      other.subjectId == subjectId &&
      other.unitId == unitId &&
      other.topicId == topicId;

  @override
  int get hashCode => Object.hash(subjectId, unitId, topicId);
}

final personalSummaryProvider =
    FutureProvider.family<String?, PersonalSummaryArgs>((ref, args) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      return ref
          .watch(contentRepositoryProvider)
          .getPersonalSummary(
            uid: uid,
            subjectId: args.subjectId,
            unitId: args.unitId,
            topicId: args.topicId,
          );
    });
