import 'package:cloud_firestore/cloud_firestore.dart';

class DataErrorMapper {
  DataErrorMapper._();

  static String message(Object error) {
    if (error is StateError) {
      return error.message;
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Bu işlem için Firestore izni yok. Firestore güvenlik kurallarını kontrol et.';
        case 'unavailable':
          return 'Sunucuya ulaşılamıyor. İnternet bağlantını kontrol edip tekrar dene.';
        case 'not-found':
          return 'İstenen kayıt bulunamadı.';
        case 'already-exists':
          return 'Bu kayıt zaten mevcut.';
        case 'resource-exhausted':
          return 'Servis geçici olarak yoğun. Biraz sonra tekrar dene.';
        case 'deadline-exceeded':
          return 'İşlem zaman aşımına uğradı. Tekrar dene.';
        case 'cancelled':
          return 'İşlem iptal edildi.';
        default:
          return error.message ??
              'Veri işlemi sırasında Firebase hatası oluştu (${error.code}).';
      }
    }

    return 'Beklenmeyen bir veri hatası oluştu.';
  }
}
