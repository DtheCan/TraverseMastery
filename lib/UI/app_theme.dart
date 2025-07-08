import 'package:flutter/material.dart';

class AppTheme {
  // Статические экземпляры тем, чтобы к ним можно было легко обращаться
  static final ThemeData darkTheme = _buildDarkTheme();
  static final ThemeData lightTheme = _buildLightTheme(); // Пример для будущей светлой темы

  // Приватный конструктор, чтобы нельзя было создать экземпляр этого класса
  AppTheme._();

  // ----- ОПРЕДЕЛЕНИЕ ТЁМНОЙ ТЕМЫ -----
  static ThemeData _buildDarkTheme() {
    const primaryBlack = Color(0xFF121212);
    const cardBlack = Color(0xFF1E1E1E);
    const accentBlue = Colors.blueAccent; // Или ваш любимый оттенок синего, например Color(0xFF448AFF)
    const textOnPrimary = Colors.white;
    const textOnSurface = Colors.white70;

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryBlack,
      scaffoldBackgroundColor: primaryBlack,
      colorScheme: ColorScheme.dark(
        primary: accentBlue,
        onPrimary: textOnPrimary,
        secondary: Colors.tealAccent, // Можно заменить на другой оттенок синего или оставить
        onSecondary: primaryBlack,
        surface: cardBlack,
        onSurface: textOnPrimary,
        background: primaryBlack,
        onBackground: textOnPrimary,
        error: Colors.redAccent,
        onError: textOnPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBlack,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textOnPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: accentBlue),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBlack.withOpacity(0.5),
        hintStyle: TextStyle(color: textOnSurface.withOpacity(0.6)),
        labelStyle: const TextStyle(color: accentBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: accentBlue.withOpacity(0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: textOnSurface.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: accentBlue, width: 2.0),
        ),
        prefixIconColor: accentBlue,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: textOnPrimary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textOnPrimary),
        bodyMedium: TextStyle(color: textOnSurface),
        headlineSmall: TextStyle(color: textOnPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textOnPrimary, fontWeight: FontWeight.bold),
      ).apply(
        bodyColor: textOnPrimary,
        displayColor: textOnPrimary,
      ),
      iconTheme: const IconThemeData(
        color: accentBlue,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardBlack,
        contentTextStyle: const TextStyle(color: textOnPrimary),
        actionTextColor: accentBlue,
      ),
      useMaterial3: true,
    );
  }

  // ----- ОПРЕДЕЛЕНИЕ СВЕТЛОЙ ТЕМЫ (ПРИМЕР) -----
  static ThemeData _buildLightTheme() {
    // Определите цвета для светлой темы здесь
    const primaryWhite = Color(0xFFFFFFFF);
    const surfaceWhite = Color(0xFFF5F5F5); // Чуть темнее белого для поверхностей
    const accentBlueLight = Colors.blue; // Может быть другой оттенок синего для светлой темы
    const textOnLight = Colors.black87;
    const textOnLightSurface = Colors.black54;

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryWhite,
      scaffoldBackgroundColor: primaryWhite,
      colorScheme: ColorScheme.light(
        primary: accentBlueLight,
        onPrimary: Colors.white, // Текст на primary кнопках
        secondary: Colors.lightBlueAccent,
        onSecondary: Colors.black,
        surface: surfaceWhite,
        onSurface: textOnLight,
        background: primaryWhite,
        onBackground: textOnLight,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 1, // Можно добавить небольшую тень для светлой темы
        titleTextStyle: TextStyle(
          color: textOnLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: accentBlueLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite.withOpacity(0.7),
        hintStyle: TextStyle(color: textOnLightSurface.withOpacity(0.8)),
        labelStyle: TextStyle(color: accentBlueLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: accentBlueLight.withOpacity(0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: textOnLightSurface.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: accentBlueLight, width: 2.0),
        ),
        prefixIconColor: accentBlueLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlueLight,
          foregroundColor: Colors.white, // Текст на кнопке
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textOnLight),
        bodyMedium: TextStyle(color: textOnLightSurface),
        headlineSmall: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
      ).apply(
        bodyColor: textOnLight,
        displayColor: textOnLight,
      ),
      iconTheme: IconThemeData(
        color: accentBlueLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceWhite,
        contentTextStyle: TextStyle(color: textOnLight),
        actionTextColor: accentBlueLight,
      ),
      useMaterial3: true,
    );
  }
}