import 'package:flutter/material.dart';

class AppTheme {
  // --- COLORS ---
  static const Color hyperBlue = Color(0xFF007AFF);
  static const Color charcoal = Color(0xFF101010);
  static const Color lightGreyBorder = Color(0xFFE5E5E5);
  static const Color darkGreyBorder = Color(0xFF262626);

  // --- LIGHT THEME ---
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: Colors.black,
      scaffoldBackgroundColor: Colors.white,
      cardColor: const Color(0xFFF9F9F9),
      dividerColor: lightGreyBorder,
      colorScheme: ColorScheme.fromSeed(
        seedColor: hyperBlue,
        brightness: Brightness.light,
        primary: Colors.black,
        secondary: hyperBlue,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: lightGreyBorder),
        backgroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // --- DARK THEME ---
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Colors.white,
      scaffoldBackgroundColor: charcoal,
      cardColor: const Color(0xFF181818),
      dividerColor: darkGreyBorder,
      colorScheme: ColorScheme.fromSeed(
        seedColor: hyperBlue,
        brightness: Brightness.dark,
        primary: Colors.white,
        secondary: hyperBlue,
        surface: charcoal,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: charcoal,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: darkGreyBorder),
        backgroundColor: const Color(0xFF181818),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}