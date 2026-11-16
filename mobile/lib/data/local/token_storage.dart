import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Onde o token de sessão fica guardado. É uma interface para os testes usarem memória.
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> save(String token);
  Future<void> clear();
}

/// Token no Keystore (Android) / Keychain (iOS), nunca em SharedPreferences.
/// Mantém uma cópia em memória para não ir ao armazenamento seguro a cada requisição.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'biko_session_token';

  final FlutterSecureStorage _storage;
  String? _cached;
  bool _loaded = false;

  @override
  Future<String?> read() async {
    if (_loaded) return _cached;
    try {
      _cached = await _storage.read(key: _key);
    } on PlatformException {
      // Chave corrompida (ex.: backup restaurado em outro aparelho): começa sem sessão.
      _cached = null;
      await _deleteQuietly();
    }
    _loaded = true;
    return _cached;
  }

  @override
  Future<void> save(String token) async {
    await _storage.write(key: _key, value: token);
    _cached = token;
    _loaded = true;
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _deleteQuietly();
  }

  Future<void> _deleteQuietly() async {
    try {
      await _storage.delete(key: _key);
    } on PlatformException {
      // Nada a fazer: o token em memória já foi descartado.
    }
  }
}
