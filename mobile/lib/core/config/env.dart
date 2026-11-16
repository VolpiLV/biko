/// Configuração por ambiente, passada na hora de rodar:
///   flutter run --dart-define=API_URL=http://192.168.0.10:3000
/// O padrão 10.0.2.2 é o "localhost do computador" visto de dentro do emulador Android.
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
