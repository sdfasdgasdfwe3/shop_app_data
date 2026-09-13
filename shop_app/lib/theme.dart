import 'package:flutter/material.dart';

class AppTheme {
  // Brand & Accent Colors (shadcn Slate/Zinc Palette)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color zinc950 = Color(0xFF09090B);
  static const Color zinc900 = Color(0xFF121215);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc700 = Color(0xFF3F3F46);

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color emeraldSuccess = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseDestructive = Color(0xFFEF4444);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: slate900,
      onPrimary: Colors.white,
      secondary: slate800,
      onSecondary: Colors.white,
      error: roseDestructive,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: slate900,
      surfaceContainerHighest: slate100,
      outline: slate200,
    ),
    scaffoldBackgroundColor: slate50,
    cardColor: Colors.white,
    dividerColor: slate200,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: slate200, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: slate900,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: slate900,
        letterSpacing: -0.015,
      ),
      iconTheme: IconThemeData(color: slate800, size: 22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: slate400, fontSize: 14),
      labelStyle: const TextStyle(color: slate600, fontSize: 14, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: slate300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: slate300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: slate900, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: roseDestructive, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: slate900,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        side: const BorderSide(color: slate200, width: 1),
        foregroundColor: slate900,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: slate900,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: slate200, width: 1),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: slate900,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: slate900,
      labelColor: slate900,
      unselectedLabelColor: slate500,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: slate200,
      thickness: 1,
      space: 1,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: zinc950,
      secondary: Colors.white70,
      onSecondary: zinc950,
      error: roseDestructive,
      onError: Colors.white,
      surface: zinc900,
      onSurface: Colors.white,
      surfaceContainerHighest: zinc800,
      outline: zinc800,
    ),
    scaffoldBackgroundColor: zinc950,
    cardColor: zinc900,
    dividerColor: zinc800,
    cardTheme: CardThemeData(
      color: zinc900,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: zinc800, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: zinc900,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.015,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: zinc900,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: zinc700, fontSize: 14),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: zinc800, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: zinc800, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: roseDestructive, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: zinc950,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        side: const BorderSide(color: zinc800, width: 1),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: zinc800,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: zinc900,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: zinc800, width: 1),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: zinc900,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: zinc800,
      thickness: 1,
      space: 1,
    ),
  );
}
