import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

/// Endpoints de autenticação da API do Biko (server.js).
class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  Future<AuthResult> login({required String email, required String password}) =>
      _api.post(
        '/api/auth/login',
        AuthResult.fromJson,
        body: {'email': email, 'password': password},
      );

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) =>
      _api.post(
        '/api/auth/register',
        AuthResult.fromJson,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'role': role.apiValue,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );

  Future<UserModel> me() => _api.get(
        '/api/auth/me',
        (json) => UserModel.fromJson(readMap(json, 'user')),
      );

  Future<void> logout() => _api.post<void>('/api/auth/logout', (_) {});
}
