import 'package:flutter/material.dart';

/// Paleta clinica: superficies de papel, azul de sello (marca), grises de
/// acero para estructura y semanticos para estado. Un solo acento de color.
abstract final class AppColors {
  // Marca (tinta de sello).
  static const primary = Color(0xFF135BEC);
  static const primaryDark = Color(0xFF0B3FA8);
  static const primarySoft = Color(0xFFE8F0FE);

  // Superficies: lienzo, tarjeta y receso (inputs).
  static const background = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F4F9);

  // Texto en cuatro niveles.
  static const ink = Color(0xFF0E1726);
  static const slate = Color(0xFF47546B);
  static const hint = Color(0xFF94A0B4);
  static const disabled = Color(0xFFB4BECF);

  // Bordes: separacion estandar y enfasis.
  static const border = Color(0xFFE3E7EF);
  static const borderStrong = Color(0xFFC9D2E0);
  static const inputBackground = Color(0xFFF1F4F9);

  // Semanticos.
  static const success = Color(0xFF0E9F6E);
  static const successSoft = Color(0xFFE4F5EE);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFBF1DF);
  static const danger = Color(0xFFD92D20);
  static const dangerSoft = Color(0xFFFCEAE8);
}

/// Tipografia con intencion: etiquetas tipo rotulo (mayusculas, tracking) y
/// cifras tabulares para documentos, lotes y fechas (deben alinear).
abstract final class AppTextStyles {
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    height: 1.2,
  );

  static const figure = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: .3,
    fontWeight: FontWeight.w600,
  );

  static const figureMuted = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: .3,
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.border,
          error: AppColors.danger,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 13, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        labelSmall: AppTextStyles.overline,
      ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger, width: 1.6),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
        labelStyle: const TextStyle(color: AppColors.slate),
        helperStyle: const TextStyle(color: AppColors.hint, fontSize: 12),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
