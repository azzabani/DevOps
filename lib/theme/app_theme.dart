// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class AppColors {
  // Brand primaire — bleu saphir
  static const primary      = Color(0xFF1A56DB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primaryDark  = Color(0xFF1239A6);
  static const primarySurface = Color(0xFFEBF2FF);

  // Brand secondaire — violet indigo
  static const secondary        = Color(0xFF6C3AED);
  static const secondaryLight   = Color(0xFF9B72F8);
  static const secondarySurface = Color(0xFFF3EEFF);

  // Accent — cyan électrique
  static const accent        = Color(0xFF0EA5E9);
  static const accentSurface = Color(0xFFE0F5FF);

  // Sémantiques
  static const success        = Color(0xFF059669);
  static const successSurface = Color(0xFFECFDF5);
  static const warning        = Color(0xFFD97706);
  static const warningSurface = Color(0xFFFFFBEB);
  static const error          = Color(0xFFDC2626);
  static const errorSurface   = Color(0xFFFEF2F2);

  // Neutres
  static const background    = Color(0xFFF7F9FC);
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F4F8);
  static const border        = Color(0xFFDDE3ED);
  static const borderLight   = Color(0xFFEEF2F7);

  // Texte
  static const textPrimary   = Color(0xFF0D1B2A);
  static const textSecondary = Color(0xFF4A5568);
  static const textTertiary  = Color(0xFF8FA3BF);
  static const textOnPrimary = Colors.white;

  // Catégories ressources
  static const salle      = Color(0xFF1A56DB);
  static const vehicule   = Color(0xFF059669);
  static const ordinateur = Color(0xFF6C3AED);
  static const materiel   = Color(0xFFD97706);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1239A6), Color(0xFF1A56DB), Color(0xFF3B82F6)],
  );
  static const gradientSecondary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C3AED), Color(0xFF1A56DB)],
  );
  static const gradientSuccess = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF047857), Color(0xFF059669)],
  );
  static const gradientWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB45309), Color(0xFFD97706)],
  );
  static const gradientHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1B2A), Color(0xFF1239A6), Color(0xFF6C3AED)],
  );
}

// ─── Thème ────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light {
    const fontFamily = 'Poppins';

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // AppBar
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Color(0x141A56DB),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14, fontFamily: fontFamily),
        hintStyle: const TextStyle(
            color: AppColors.textTertiary, fontSize: 14, fontFamily: fontFamily),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIconColor: AppColors.primary,
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(fontSize: 12, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySurface,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: AppColors.primary, fontSize: 11,
                fontWeight: FontWeight.w700, fontFamily: fontFamily);
          }
          return const TextStyle(
              color: AppColors.textTertiary, fontSize: 11, fontFamily: fontFamily);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 22);
        }),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 1),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontFamily: fontFamily, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        contentTextStyle: const TextStyle(
            fontFamily: fontFamily, fontSize: 14, color: AppColors.textSecondary),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: StadiumBorder(),
      ),
    );
  }
}
