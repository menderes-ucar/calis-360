import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _auth = auth,
       _firestore = firestore,
       _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Stream<AppUser?> watchCurrentAppUser() {
    return authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<AppUser?>.value(null);
      return watchAppUser(user);
    });
  }

  Stream<AppUser?> watchAppUser(User authUser) async* {
    final ref = _firestore.collection('users').doc(authUser.uid);

    try {
      await for (final snapshot in ref.snapshots()) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          yield AppUser.fromFirebaseUser(authUser);
          continue;
        }
        yield AppUser.fromMap(snapshot.id, data);
      }
    } on FirebaseException {
      // Auth başarılıysa profil dokümanı geçici olarak okunamasa bile kullanıcıyı
      // login ekranına geri atmayız. Profil varsayılan free değerlerle açılır ve
      // AuthBootstrap arka planda tekrar senkronizasyon dener.
      yield AppUser.fromFirebaseUser(authUser);
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await syncUserProfileBestEffort(user);
    }

    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await syncUserProfileBestEffort(user);
    }

    return credential;
  }

  Future<bool> syncUserProfileBestEffort(User user) async {
    try {
      await ensureUserProfile(user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureUserProfile(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    final baseData = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName,
      'emailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      await ref.set({
        ...baseData,
        'plan': 'free',
        'creditBalance': 0,
        'subscriptionStatus': 'inactive',
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await ref.set(baseData, SetOptions(merge: true));
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Veriyi ve Auth kullanıcısını tek sunucu işleminde siler. Böylece istemci
    // önce Auth'u silip Firestore verisini erişilemez/orphan bırakmaz.
    final callable = _functions.httpsCallable('deleteCurrentAccount');
    await callable.call();
    await _auth.signOut();
  }
}
