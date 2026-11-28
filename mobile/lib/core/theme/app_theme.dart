import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'biko_colors.dart';

/// Temas claro e escuro no visual do Figma (Poppins, azul #0A84FF, cartões brancos
/// arredondados). As telas leem as cores daqui ou de `context.bikoColors`.
abstract final class AppTheme {
  static final ThemeData light = _build(
    ColorScheme.fromSeed(seedColor: AppColors.brandBlue).copyWith(
      primary: AppColors.brandBlue,
      onPrimary: Colors.white,
      secondary: AppColors.brandOrange,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    ),
    BikoColors.light,
  );

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(seedColor: AppColors.brandBlue, brightness: Brightness.dark).copyWith(
      primary: AppColors.brandBlueLight,
      onPrimary: const Color(0xFF00213F),
      secondary: AppColors.brandOrange,
      onSecondary: AppColors.ink,
      surface: BikoColors.dark.card,
      onSurface: BikoColors.dark.text,
      onSurfaceVariant: BikoColors.dark.muted,
      outline: BikoColors.dark.line,
      outlineVariant: BikoColors.dark.line,
    ),
    BikoColors.dark,
  );

  static ThemeData _build(ColorScheme scheme, BikoColors c) {
    final radius = BorderRadius.circular(AppRadius.md);
    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: color, width: width));
    const buttonText = TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600);
    final buttonShape = RoundedRectangleBorder(borderRadius: radius);
    const buttonSize = Size(64, AppSizes.buttonHeight);

    final base = ThemeData(brightness: scheme.brightness, useMaterial3: true);
    final textTheme = base.textTheme.apply(fontFamily: 'Poppins', bodyColor: c.text, displayColor: c.ink);

    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'Poppins',
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: c.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 15),
        hintStyle: TextStyle(color: c.muted2, fontSize: 15),
        prefixIconColor: c.muted2,
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(scheme.primary, 1.8),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 1.8),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          backgroundColor: c.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.blue.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: c.text,
          backgroundColor: c.card,
          side: BorderSide(color: c.line, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.blue,
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: c.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.blue,
        side: BorderSide(color: c.line, width: 1.5),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: c.text, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.blueSoft,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.blue : const Color(0xFF8A94A6),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.blue : const Color(0xFF8A94A6), size: 24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.blue : const Color(0xFFCFD6E0)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.blue : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: [c],
    );
  }
}
