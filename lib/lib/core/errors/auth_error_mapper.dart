import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorMapper {
  AuthErrorMapper._();

  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Bu işlem için yeniden giriş yapmanız gerekiyor.';
        case 'failed-precondition':
          return error.message ?? 'İşlem için gerekli koşullar sağlanamadı.';
        case 'unavailable':
          return 'Sunucuya şu anda ulaşılamıyor. Lütfen tekrar deneyin.';
        case 'not-found':
          return 'Sunucu işlemi henüz yayınlanmamış. Cloud Functions dağıtımını kontrol edin.';
        default:
          return error.message ?? 'Sunucu işlemi tamamlanamadı.';
      }
    }

    if (error is FirebaseException && error is! FirebaseAuthException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firebase erişim izni reddedildi. Firestore güvenlik kurallarını kontrol edin.';
        case 'unavailable':
          return 'Firebase servisine şu anda ulaşılamıyor. İnternet bağlantısını kontrol edin.';
        default:
          return error.message ??
              'Firebase işlemi tamamlanamadı. Lütfen tekrar deneyin.';
      }
    }

    if (error is! FirebaseAuthException) {
      return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'Geçerli bir e-posta adresi girin.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresiyle zaten bir hesap bulunuyor.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.';
      case 'operation-not-allowed':
        return 'E-posta/şifre ile giriş Firebase Console üzerinde etkin değil.';
      case 'requires-recent-login':
        return 'Bu işlem için güvenlik nedeniyle yeniden giriş yapmanız gerekiyor.';
      default:
        return error.message ?? 'Kimlik doğrulama işlemi tamamlanamadı.';
    }
  }
}
