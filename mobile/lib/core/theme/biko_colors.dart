import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Paleta do Figma que o Material não tem (fundos suaves, laranja, verde do Pix...).
/// Tem versão clara e escura. Uso: `context.bikoColors`.
@immutable
class BikoColors extends ThemeExtension<BikoColors> {
  const BikoColors({
    required this.background,
    required this.card,
    required this.line,
    required this.ink,
    required this.text,
    required this.muted,
    required this.muted2,
    required this.blue,
    required this.blueSoft,
    required this.orange,
    required this.orangeText,
    required this.orangeSoft,
    required this.green,
    required this.greenPay,
    required this.greenSoft,
    required this.danger,
    required this.dangerSoft,
    required this.purple,
    required this.purpleSoft,
    required this.field,
    required this.neutralSoft,
    required this.warnBg,
    required this.warnBorder,
    required this.warnText,
  });

  final Color background;
  final Color card;
  final Color line;
  final Color ink;
  final Color text;
  final Color muted;
  final Color muted2;
  final Color blue;
  final Color blueSoft;
  final Color orange;
  final Color orangeText;
  final Color orangeSoft;
  final Color green;
  final Color greenPay;
  final Color greenSoft;
  final Color danger;
  final Color dangerSoft;
  final Color purple;
  final Color purpleSoft;

  /// Fundo dos campos de texto.
  final Color field;

  /// Cinza dos botões "light" e chips neutros.
  final Color neutralSoft;
  final Color warnBg;
  final Color warnBorder;
  final Color warnText;

  // Nomes antigos (usados por telas que já existiam).
  Color get highlight => orange;
  Color get onHighlight => AppColors.ink;
  Color get success => green;
  Color get onSuccess => Colors.white;

  static const BikoColors light = BikoColors(
    background: AppColors.background,
    card: Colors.white,
    line: AppColors.line,
    ink: AppColors.ink,
    text: AppColors.text,
    muted: AppColors.muted,
    muted2: AppColors.muted2,
    blue: AppColors.brandBlue,
    blueSoft: Color(0xFFE6F1FF),
    orange: AppColors.brandOrange,
    orangeText: AppColors.orangeText,
    orangeSoft: Color(0xFFFFF4E5),
    green: AppColors.green,
    greenPay: AppColors.greenPay,
    greenSoft: Color(0xFFE3F7EC),
    danger: AppColors.danger,
    dangerSoft: Color(0xFFFDECEC),
    purple: AppColors.purple,
    purpleSoft: Color(0xFFEFE7FE),
    field: Color(0xFFF7F9FC),
    neutralSoft: Color(0xFFEEF2F7),
    warnBg: Color(0xFFFFF7EB),
    warnBorder: Color(0xFFFDE2B8),
    warnText: Color(0xFF92400E),
  );

  static const BikoColors dark = BikoColors(
    background: Color(0xFF0E131C),
    card: Color(0xFF171E2A),
    line: Color(0xFF2A3342),
    ink: Color(0xFFF1F5F9),
    text: Color(0xFFE5E9F0),
    muted: Color(0xFF9AA3B2),
    muted2: Color(0xFF6B7585),
    blue: AppColors.brandBlueLight,
    blueSoft: Color(0xFF16304F),
    orange: AppColors.brandOrange,
    orangeText: Color(0xFFFFB454),
    orangeSoft: Color(0xFF3A2A12),
    green: Color(0xFF4ADE80),
    greenPay: Color(0xFF15A673),
    greenSoft: Color(0xFF123323),
    danger: Color(0xFFFF7A7E),
    dangerSoft: Color(0xFF3B1C1E),
    purple: Color(0xFFB79CFF),
    purpleSoft: Color(0xFF2A2145),
    field: Color(0xFF111824),
    neutralSoft: Color(0xFF232C3A),
    warnBg: Color(0xFF33260F),
    warnBorder: Color(0xFF5A4316),
    warnText: Color(0xFFFCD9A0),
  );

  @override
  BikoColors copyWith() => this;

  @override
  BikoColors lerp(ThemeExtension<BikoColors>? other, double t) {
    if (other is! BikoColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return BikoColors(
      background: l(background, other.background),
      card: l(card, other.card),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      muted2: l(muted2, other.muted2),
      blue: l(blue, other.blue),
      blueSoft: l(blueSoft, other.blueSoft),
      orange: l(orange, other.orange),
      orangeText: l(orangeText, other.orangeText),
      orangeSoft: l(orangeSoft, other.orangeSoft),
      green: l(green, other.green),
      greenPay: l(greenPay, other.greenPay),
      greenSoft: l(greenSoft, other.greenSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      purple: l(purple, other.purple),
      purpleSoft: l(purpleSoft, other.purpleSoft),
      field: l(field, other.field),
      neutralSoft: l(neutralSoft, other.neutralSoft),
      warnBg: l(warnBg, other.warnBg),
      warnBorder: l(warnBorder, other.warnBorder),
      warnText: l(warnText, other.warnText),
    );
  }
}

extension BikoThemeContext on BuildContext {
  BikoColors get bikoColors => Theme.of(this).extension<BikoColors>() ?? BikoColors.light;
}
