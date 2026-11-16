import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'biko_colors.dart';

/// Temas claro e escuro. As telas nunca definem cores fixas: sempre leem daqui.
abstract final class AppTheme {
  static final ThemeData light = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
    ).copyWith(
      primary: AppColors.brandBlueDark,
      onPrimary: Colors.white,
      secondary: AppColors.brandOrange,
      onSecondary: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
    ),
    scaffoldBackground: AppColors.background,
    brandColors: BikoColors.light,
  );

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.brandBlueLight,
      onPrimary: AppColors.brandBlueDeep,
      secondary: AppColors.brandOrange,
      onSecondary: AppColors.ink,
    ),
    brandColors: BikoColors.dark,
  );

  static ThemeData _build(
    ColorScheme scheme, {
    Color? scaffoldBackground,
    required BikoColors brandColors,
  }) {
    final radius = BorderRadius.circular(AppRadius.md);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    final buttonShape = RoundedRectangleBorder(borderRadius: radius);
    const buttonSize = Size(64, AppSizes.buttonHeight);

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground ?? scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [brandColors],
    );
  }
}
