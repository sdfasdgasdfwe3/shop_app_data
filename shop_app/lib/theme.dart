import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand / Deep Navy & Slate ──────────────────────────────────────────────
  static const Color primary          = Color(0xFF0F172A); // Deep Slate 900 (Corporate, modern)
  static const Color primaryBlue      = Color(0xFF2563EB); // Vibrant Royal Sapphire 600
  static const Color primaryNavy      = Color(0xFF1E293B); // Slate 800
  static const Color accentBlue       = Color(0xFF38BDF8); // Sky 400 for dark mode highlights
  static const Color accentIndigo     = Color(0xFF4F46E5); // Indigo 600

  // ── Backgrounds ─────────────────────────────────────────────────────────────
  static const Color bgLight          = Color(0xFFF8FAFC); // Slate 50 crisp clean canvas
  static const Color bgDark           = Color(0xFF090D16); // Deep Midnight Obsidian (true dark navy)

  // ── Cards & Surfaces ────────────────────────────────────────────────────────
  static const Color cardLight        = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color cardDark         = Color(0xFF111827); // Rich Midnight Slate
  static const Color accentDark       = Color(0xFF1E293B); // Slate 800
  static const Color surfaceMutedLight= Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceMutedDark = Color(0xFF1F2937); // Gray 800 subtle

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF0F172A); // Deep Slate 900
  static const Color textPrimaryDark    = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textSecondaryDark  = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedLight     = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedDark      = Color(0xFF64748B); // Slate 500

  // ── Status ───────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error   = Color(0xFFEF4444); // Rose 500

  // ── Borders ──────────────────────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200 hairline border
  static const Color borderDark  = Color(0xFF1F2937); // Gray 800 / Slate 800

  // ── Shape & Radii Design Tokens ──────────────────────────────────────────────
  static const double radiusSm   = 8.0;   // Chips, badges, small buttons
  static const double radiusMd   = 12.0;  // Input fields, standard buttons, steppers
  static const double radiusLg   = 16.0;  // Product cards, containers, dialogs
  static const double radiusXl   = 24.0;  // Bottom sheets, large modals
  static const double radiusPill = 999.0; // Category pills, status pills

  static final BorderRadius roundedSm   = BorderRadius.circular(radiusSm);
  static final BorderRadius roundedMd   = BorderRadius.circular(radiusMd);
  static final BorderRadius roundedLg   = BorderRadius.circular(radiusLg);
  static final BorderRadius roundedXl   = BorderRadius.circular(radiusXl);
  static final BorderRadius roundedPill = BorderRadius.circular(radiusPill);

  // ── Surface & Border Helpers ────────────────────────────────────────────────
  static Color getBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;

  static Color getCardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : cardLight;

  static Color getMutedSurfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceMutedDark : surfaceMutedLight;

  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;

  static BoxDecoration cardDecoration(BuildContext context, {double? radius}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? cardDark : cardLight,
      borderRadius: BorderRadius.circular(radius ?? radiusLg),
      border: Border.all(color: isDark ? borderDark : borderLight, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  // ── Gradient helpers (Sophisticated Deep Sapphire Shimmer) ──────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration gradientBox({double radius = 12}) => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.12),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.2),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // ── Light Theme ──────────────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primaryBlue,
      onSecondary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: cardLight,
      onSurface: textPrimaryLight,
      surfaceContainerHighest: bgLight,
      outline: borderLight,
    ),
    scaffoldBackgroundColor: bgLight,
    cardColor: cardLight,
    dividerColor: borderLight,
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cardLight,
      foregroundColor: textPrimaryLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimaryLight,
        letterSpacing: 1.2,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: textPrimaryLight, size: 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
      labelStyle: const TextStyle(
        color: textSecondaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        side: const BorderSide(color: borderLight, width: 1),
        backgroundColor: cardLight,
        foregroundColor: textPrimaryLight,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardLight,
      selectedItemColor: primary,
      unselectedItemColor: textSecondaryLight,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardLight,
      indicatorColor: primaryBlue.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          );
        }
        return const TextStyle(
          color: textSecondaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary, size: 22);
        }
        return const IconThemeData(color: textSecondaryLight, size: 22);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceMutedLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: borderLight, width: 1),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimaryLight),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: primary,
      labelColor: primary,
      unselectedLabelColor: textSecondaryLight,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: primary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderLight, width: 1),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimaryLight,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardLight,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  // ── Dark Theme ───────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: primary,
      secondary: accentBlue,
      onSecondary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: cardDark,
      onSurface: textPrimaryDark,
      surfaceContainerHighest: bgDark,
      outline: borderDark,
    ),
    scaffoldBackgroundColor: bgDark,
    cardColor: cardDark,
    dividerColor: borderDark,
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cardDark,
      foregroundColor: textPrimaryDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimaryDark,
        letterSpacing: 1.2,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: textPrimaryDark, size: 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceMutedDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
      labelStyle: const TextStyle(
        color: textSecondaryDark,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderDark, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: primary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        side: const BorderSide(color: borderDark, width: 1),
        backgroundColor: cardDark,
        foregroundColor: textPrimaryDark,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardDark,
      selectedItemColor: Colors.white,
      unselectedItemColor: textSecondaryDark,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardDark,
      indicatorColor: accentBlue.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          );
        }
        return const TextStyle(
          color: textSecondaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 22);
        }
        return const IconThemeData(color: textSecondaryDark, size: 22);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceMutedDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: borderDark, width: 1),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimaryDark),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: textSecondaryDark,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: borderDark,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E293B),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderDark, width: 1),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimaryDark,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cardDark,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
