import 'package:flutter/material.dart';

import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/local/preferences_store.dart';

/// Tema escolhido pelo usuário (Claro / Escuro / Sistema), salvo no aparelho.
class ThemeViewModel extends BaseViewModel {
  ThemeViewModel(this._preferences) : _mode = _preferences.themeMode;

  final PreferencesStore _preferences;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notify();
    await _preferences.setThemeMode(mode);
  }
}
