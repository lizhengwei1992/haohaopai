import 'package:flutter/material.dart';

class AppTheme {
  // 主色调
  static const Color primaryColor = Color(0xFF3F51B5);
  static const Color accentColor = Color(0xFF4CAF50);

  // 背景色
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkBackground = Color(0xFF121212);

  // 文本颜色
  static const Color lightTextColor = Color(0xFF212121);
  static const Color darkTextColor = Color(0xFFEEEEEE);

  // 浅色主题
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      background: lightBackground,
    ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: lightTextColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: lightTextColor, fontSize: 16),
      bodyMedium: TextStyle(color: lightTextColor, fontSize: 14),
    ),
  );

  // 深色主题
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      background: darkBackground,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: darkTextColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: darkTextColor, fontSize: 16),
      bodyMedium: TextStyle(color: darkTextColor, fontSize: 14),
    ),
  );
}
