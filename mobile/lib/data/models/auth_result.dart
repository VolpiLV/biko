import '../../core/utils/json_reader.dart';
import 'user_model.dart';

/// Resposta de login/cadastro quando o app manda "X-Client: mobile".
class AuthResult {
  const AuthResult({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  final UserModel user;
  final String token;
  final DateTime expiresAt;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    if (readString(json, 'token_type') != 'Bearer') {
      throw const FormatException('Tipo de token inesperado.');
    }
    return AuthResult(
      user: UserModel.fromJson(readMap(json, 'user')),
      token: readString(json, 'token'),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        readInt(json, 'expires_at'),
        isUtc: true,
      ),
    );
  }
}
