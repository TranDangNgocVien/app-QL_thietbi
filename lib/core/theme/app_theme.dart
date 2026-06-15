import 'package:flutter/material.dart';

class AppTheme {

  static const Color primaryColor = Color(0xFF2F8ED8);
  static const Color backgroundColor = Color(0xFFE6F2F8);
  static const Color inputFillColor = Color(0xFF1E2F3A);

  /// Màu nền splash screen (gradient)
  static const Color splashGradientTop = Color(0xFF00BCD4);
  static const Color splashGradientBottom = Color(0xFF2196F3);

  /// Màu nền login screen
  static const Color loginBackgroundColor = Color(0xFFA8E0F5);

  static ThemeData lightTheme = ThemeData(

    useMaterial3: true,

    primaryColor: primaryColor,

    scaffoldBackgroundColor: backgroundColor,

    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      surface: backgroundColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 2,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,

      hintStyle: const TextStyle(color: Colors.white54),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    ),

    textTheme: const TextTheme(

      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),

      bodyMedium: TextStyle(
        fontSize: 16,
      ),

      labelLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
