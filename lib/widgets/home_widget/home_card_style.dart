import 'package:flutter/material.dart';

class HomeCardStyle {
  HomeCardStyle._();

  static const borderColor = Color(0xFFD4DEE8);
  static const double borderWidth = 1.75;
  static const double radius = 20;

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
          color: const Color(0xFF172033).withValues(alpha: 0.085),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        if (accent != null)
          BoxShadow(
            color: accent.withValues(alpha: 0.065),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
      ];
}
