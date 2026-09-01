import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Çalış 360 premium palette
  static const Color burgundy = Color(0xFF4A1F2C);
  static const Color forest = Color(0xFF1F4A3D);
  static const Color ivory = Color(0xFFF2E6DC);

  // Supporting tones are derived from the same three-color visual language.
  static const Color background = ivory;
  static const Color surface = Color(0xFFF8F0EA);
  static const Color surfaceStrong = Color(0xFFE7D7CC);
  static const Color surfaceForest = Color(0xFFD8E2DD);
  static const Color surfaceBurgundy = Color(0xFFE7D7DC);
  static const Color ink = Color(0xFF2B2022);
  static const Color inkSoft = Color(0xFF74676A);
  static const Color border = Color(0xFFD6C5BB);

  static const Color primary = burgundy;
  static const Color secondary = forest;
  static const Color success = forest;
  static const Color warning = burgundy;

  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: burgundy,
      onPrimary: ivory,
      secondary: forest,
      onSecondary: ivory,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: surfaceStrong,
      onSurfaceVariant: inkSoft,
      outline: border,
      outlineVariant: border,
      error: Color(0xFF8E3548),
      onError: ivory,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: null,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.42),
          ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        foregroundColor: burgundy,
        iconTheme: IconThemeData(color: burgundy),
        actionsIconTheme: IconThemeData(color: burgundy),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: border, width: 1.25),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: forest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ivory,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? burgundy : ivory.withValues(alpha: .78),
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? burgundy : ivory.withValues(alpha: .84),
            size: selected ? 24 : 22,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: const TextStyle(color: inkSoft, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: inkSoft.withValues(alpha: .72)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: forest, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: forest,
          foregroundColor: ivory,
          disabledBackgroundColor: surfaceStrong,
          disabledForegroundColor: inkSoft,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: burgundy,
          foregroundColor: ivory,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: burgundy,
          side: const BorderSide(color: burgundy, width: 1.35),
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: burgundy,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceStrong,
        selectedColor: surfaceForest,
        secondarySelectedColor: surfaceForest,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: forest,
        foregroundColor: ivory,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: forest,
        linearTrackColor: surfaceStrong,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? ivory : surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? forest : surfaceStrong;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: burgundy,
        contentTextStyle: const TextStyle(color: ivory, fontWeight: FontWeight.w700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
