import 'package:flutter/material.dart';

class AppTheme {
AppTheme._();

static ThemeData lightTheme =ThemeData(
    colorScheme: ColorScheme.light(
    primary:Color(0xFF142BD9),
    error: Colors.redAccent,
      secondary: Color(0xFF28CB50),
      onSurface: Color(0xFF466660),
      secondaryContainer: Color(0XFF173A3B),
    ),
);
}
