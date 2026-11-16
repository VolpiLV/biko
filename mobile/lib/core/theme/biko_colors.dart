import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Cores da marca que não existem no ColorScheme do Material.
/// Uso: `Theme.of(context).extension<BikoColors>()!` ou `context.bikoColors`.
@immutable
class BikoColors extends ThemeExtension<BikoColors> {
  const BikoColors({
    required this.highlight,
    required this.onHighlight,
    required this.success,
    required this.onSuccess,
  });

  /// Laranja Biko: destaques e selo de prestador.
  final Color highlight;
  final Color onHighlight;
  final Color success;
  final Color onSuccess;

  static const BikoColors light = BikoColors(
    highlight: AppColors.brandOrange,
    onHighlight: AppColors.ink,
    success: AppColors.success,
    onSuccess: Colors.white,
  );

  static const BikoColors dark = BikoColors(
    highlight: AppColors.brandOrange,
    onHighlight: AppColors.ink,
    success: Color(0xFF5FD38D),
    onSuccess: Color(0xFF00391A),
  );

  @override
  BikoColors copyWith({
    Color? highlight,
    Color? onHighlight,
    Color? success,
    Color? onSuccess,
  }) =>
      BikoColors(
        highlight: highlight ?? this.highlight,
        onHighlight: onHighlight ?? this.onHighlight,
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
      );

  @override
  BikoColors lerp(ThemeExtension<BikoColors>? other, double t) {
    if (other is! BikoColors) return this;
    return BikoColors(
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      onHighlight: Color.lerp(onHighlight, other.onHighlight, t) ?? onHighlight,
      success: Color.lerp(success, other.success, t) ?? success,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
    );
  }
}

extension BikoThemeContext on BuildContext {
  BikoColors get bikoColors =>
      Theme.of(this).extension<BikoColors>() ?? BikoColors.light;
}
