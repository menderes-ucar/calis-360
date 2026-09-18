import 'package:cloud_functions/cloud_functions.dart';

class AiSolverErrorMapper {
  AiSolverErrorMapper._();

  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      final reason = details is Map ? details['reason']?.toString() : null;

      switch (reason) {
        case 'insufficient_credits':
          return 'Bugünkü ücretsiz AI çözüm hakkın doldu. Devam etmek için kredi gerekli.';
        case 'rate_limited':
          return 'Çok hızlı istek gönderdin. Birkaç saniye bekleyip tekrar dene.';
        case 'hard_daily_limit':
          return 'Günlük güvenlik limiti doldu. Yarın tekrar deneyebilirsin.';
        case 'image_too_large':
          return 'Soru görseli çok büyük. Daha küçük veya kırpılmış bir fotoğraf seç.';
        case 'unsupported_image_type':
          return 'Bu görsel biçimi desteklenmiyor. JPEG, PNG veya WebP kullan.';
        case 'missing_question':
          return 'Soruyu yaz veya fotoğrafını ekle.';
        case 'ai_provider_error':
          return 'AI çözümü tamamlanamadı. Kullanılan hak/kredi iade edildi.';
      }

      switch (error.code) {
        case 'unauthenticated':
          return 'AI soru çözümü için yeniden giriş yapmalısın.';
        case 'invalid-argument':
          return error.message ?? 'Soru verisi geçersiz.';
        case 'resource-exhausted':
          return error.message ?? 'AI kullanım limitine ulaştın.';
        case 'aborted':
          return 'Bu istek hâlâ işleniyor. Birkaç saniye sonra tekrar dene.';
        case 'deadline-exceeded':
          return 'AI yanıtı zaman aşımına uğradı. Tekrar deneyebilirsin.';
        default:
          return error.message ?? 'AI çözümünde beklenmeyen bir hata oluştu.';
      }
    }

    if (error is StateError) {
      return error.message;
    }

    return 'AI çözümü tamamlanamadı. Lütfen tekrar dene.';
  }
}
