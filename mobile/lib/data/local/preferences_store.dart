import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do usuário que não são sensíveis (tema etc.).
class PreferencesStore {
  PreferencesStore(this._prefs);

  static const String _themeModeKey = 'theme_mode';

  final SharedPreferences _prefs;

  ThemeMode get themeMode {
    final saved = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }
}
