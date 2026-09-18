// ignore_for_file: depend_on_referenced_packages
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class OptimizedQuestionImage {
  const OptimizedQuestionImage({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.originalBytes,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final int originalBytes;

  int get optimizedBytes => bytes.lengthInBytes;

  double get savingRatio {
    if (originalBytes <= 0) return 0;
    return 1 - (optimizedBytes / originalBytes);
  }
}

class QuestionImageOptimizer {
  const QuestionImageOptimizer._();

  static const int maxLongEdge = 1400;
  static const int preferredMaxBytes = 550 * 1024;

  static Future<OptimizedQuestionImage> optimize(Uint8List source) async {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const FormatException('Görsel okunamadı.');
    }

    var working = decoded;
    final longEdge = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longEdge > maxLongEdge) {
      if (decoded.width >= decoded.height) {
        working = img.copyResize(decoded, width: maxLongEdge);
      } else {
        working = img.copyResize(decoded, height: maxLongEdge);
      }
    }

    Uint8List encode(int quality) =>
        Uint8List.fromList(img.encodeJpg(working, quality: quality));

    var output = encode(80);
    if (output.lengthInBytes > preferredMaxBytes) output = encode(68);
    if (output.lengthInBytes > preferredMaxBytes) output = encode(58);

    return OptimizedQuestionImage(
      bytes: output,
      mimeType: 'image/jpeg',
      width: working.width,
      height: working.height,
      originalBytes: source.lengthInBytes,
    );
  }
}
