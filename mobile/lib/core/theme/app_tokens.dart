import 'package:flutter/material.dart';

/// Tokens do Design System do Biko (mesma identidade do sistema web: public/style.css).
abstract final class AppColors {
  static const Color brandBlue = Color(0xFF1677F2);
  // Azul mais escuro como "primary" no tema claro: texto branco sobre ele tem
  // contraste 5,9:1 (o azul da marca dá 4,2:1, abaixo do mínimo de 4,5:1).
  static const Color brandBlueDark = Color(0xFF0F5FD0);
  static const Color brandBlueLight = Color(0xFF8AB8FF);
  static const Color brandBlueDeep = Color(0xFF00316F);
  static const Color brandOrange = Color(0xFFFF8A1F);
  static const Color ink = Color(0xFF1C2430);
  static const Color muted = Color(0xFF5E6878);
  static const Color background = Color(0xFFF4F6FA);
  static const Color success = Color(0xFF1F9D55);
  static const Color danger = Color(0xFFD93A3A);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}

abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double formMaxWidth = 480;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
}
