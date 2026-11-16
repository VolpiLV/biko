import 'package:flutter/foundation.dart';

/// Configuração por ambiente. Para apontar para outro servidor:
///   flutter run --dart-define=API_URL=http://192.168.0.10:3000
abstract final class Env {
  static const String _apiUrlOverride = String.fromEnvironment('API_URL');

  /// Sem API_URL: no Chrome usa o localhost; no emulador Android, 10.0.2.2
  /// (que é o "localhost do computador" visto de dentro do emulador).
  static String get apiBaseUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
  }
}
