import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../models/dersProgrami.dart';
import '../../../../models/hedef.dart';
import '../../../../models/home_hedef_ekle.dart';
import '../../../../models/sinav.dart';
import '../../../../models/sinav_takvimi.dart';
import '../../../../models/soru.dart';
import '../../../../repositories/dersProgrami_repo.dart';
import '../../../../repositories/hedef_repo.dart';
import '../../../../repositories/home_hedef_repo.dart';
import '../../../../repositories/sinav_repo.dart';
import '../../../../repositories/sinav_takvimi_repo.dart';
import '../../../../repositories/soru_repo.dart';
import '../../../question_media/data/question_media_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';

final dersProgramiRepositoryProvider = Provider<DersProgramiRepository>((ref) {
  return DersProgramiRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final hedefRepositoryProvider = Provider<HedefRepository>((ref) {
  return HedefRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final homeHedefRepositoryProvider = Provider<HomeHedefRepository>((ref) {
  return HomeHedefRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final sinavRepositoryProvider = Provider<SinavRepository>((ref) {
  return SinavRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final sinavTakvimiRepositoryProvider = Provider<SinavTakvimiRepository>((ref) {
  return SinavTakvimiRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final soruRepositoryProvider = Provider<SoruRepository>((ref) {
  return SoruRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final questionMediaRepositoryProvider = Provider<QuestionMediaRepository>((
  ref,
) {
  return QuestionMediaRepository(
    auth: ref.watch(firebaseAuthProvider),
    storage: FirebaseStorage.instance,
  );
});

final dersProgramiProvider = StreamProvider.autoDispose<List<DersProgram>>((
  ref,
) {
  return ref.watch(dersProgramiRepositoryProvider).getDersProgram();
});

final hedeflerProvider = StreamProvider.autoDispose<List<Hedef>>((ref) {
  return ref.watch(hedefRepositoryProvider).getHedef();
});

final homeHedefProvider = StreamProvider.autoDispose<HomeHedef?>((ref) {
  return ref.watch(homeHedefRepositoryProvider).getHomeHedefForCurrentUser();
});

final sinavlarProvider = StreamProvider.autoDispose<List<Sinav>>((ref) {
  return ref.watch(sinavRepositoryProvider).getSinavlar();
});

final sinavTakvimiProvider = StreamProvider.autoDispose<List<SinavTakvimi>>((
  ref,
) {
  return ref.watch(sinavTakvimiRepositoryProvider).getDers();
});

final sorularProvider = StreamProvider.autoDispose<List<Soru>>((ref) {
  return ref.watch(soruRepositoryProvider).getSorular();
});
