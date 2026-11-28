import 'package:flutter/material.dart';

/// Tokens do Design System do Biko: os mesmos do protótipo do Figma e do site
/// (public/style.css). Cores que mudam no tema escuro ficam em [BikoColors].
abstract final class AppColors {
  static const Color brandBlue = Color(0xFF0A84FF);
  static const Color brandBlue2 = Color(0xFF0066E0);
  static const Color brandBlueDark = Color(0xFF0052CC);
  static const Color brandBlueLight = Color(0xFF6CB4FF);
  static const Color brandOrange = Color(0xFFFF9500);
  static const Color orangeText = Color(0xFFE07A00);
  static const Color green = Color(0xFF12A150);
  static const Color greenPay = Color(0xFF0E8F62);
  static const Color danger = Color(0xFFE5484D);
  static const Color purple = Color(0xFF6A3FD1);
  static const Color star = Color(0xFFF5A623);
  static const Color online = Color(0xFF22C55E);
  static const Color ink = Color(0xFF0F172A);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color muted2 = Color(0xFF9AA3B2);
  static const Color background = Color(0xFFF2F5FA);
  static const Color line = Color(0xFFE4E9F0);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Margem lateral das telas (20 px como no Figma).
  static const double page = 20;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
}

abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double formMaxWidth = 480;
  static const double pageMaxWidth = 560;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
}
