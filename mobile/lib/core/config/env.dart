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

  // Push com o app fechado (Firebase Cloud Messaging). Valores do app Android no console do
  // Firebase (os mesmos do google-services.json). Sem eles o push fica desligado e o app
  // mostra os pop-ups só enquanto está aberto. Ex.:
  //   flutter build apk --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=...
  //     --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty && firebaseAppId.isNotEmpty && firebaseSenderId.isNotEmpty && firebaseProjectId.isNotEmpty;
}
