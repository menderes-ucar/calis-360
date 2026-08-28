import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/app_user.dart';
import '../../../notifications/application/notification_service.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentAppUser();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(
        ref.watch(authRepositoryProvider),
        ref.watch(notificationServiceProvider),
      );
    });

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repository, this._notificationService)
    : super(const AsyncData(null));

  final AuthRepository _repository;
  final NotificationService _notificationService;

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await _repository.signIn(email: email, password: password);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.register(email: email, password: password);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    try {
      await _repository.sendPasswordResetEmail(email);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> signOut() async {
    state = const AsyncLoading();
    try {
      final uid = _repository.currentUser?.uid;
      if (uid != null) {
        try {
          await _notificationService.disableForUser(uid);
        } catch (_) {
          // Token cleanup ağ hatası yüzünden logout'u engellememeli.
        }
      }
      await _repository.signOut();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> deleteCurrentAccount() async {
    state = const AsyncLoading();
    try {
      final uid = _repository.currentUser?.uid;
      if (uid != null) {
        try {
          await _notificationService.disableForUser(uid);
        } catch (_) {
          // Token cleanup hesap silme akışını engellememeli.
        }
      }
      await _repository.deleteCurrentAccount();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
