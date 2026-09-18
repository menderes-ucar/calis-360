import 'package:flutter/material.dart';

class HomeCardStyle {
  HomeCardStyle._();

  static const background = Color(0xFFF2E6DC);
  static const surface = Color(0xFFFFF8F2);
  static const burgundy = Color(0xFF4A1F2C);
  static const forest = Color(0xFF1F4A3D);
  static const ink = Color(0xFF2B2022);
  static const muted = Color(0xFF756A66);
  static const borderColor = Color(0xFFD8C8BC);
  static const double borderWidth = 1.15;
  static const double radius = 24;

  static BorderSide get borderSide => const BorderSide(
        color: borderColor,
        width: borderWidth,
      );

  static RoundedRectangleBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: borderSide,
      );

  static List<BoxShadow> shadows({Color? accent}) => [
        BoxShadow(
          color: burgundy.withValues(alpha: 0.075),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        if (accent != null)
          BoxShadow(
            color: accent.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
      ];
}
