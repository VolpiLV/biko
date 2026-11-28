import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

/// Verificação do Profissional (só no cadastro de prestador): CPF válido,
/// maior de 18 anos e aceite dos Termos do Prestador. O servidor confere de novo.
class ProfessionalCheck {
  const ProfessionalCheck({required this.cpf, required this.birthDate, required this.terms});

  final String cpf;

  /// "DD/MM/AAAA"
  final String birthDate;
  final bool terms;

  Map<String, Object> toJson() => {'cpf': cpf.replaceAll(RegExp(r'\D'), ''), 'birth_date': birthDate, 'terms': terms};
}

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
    ProfessionalCheck? professional,
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
          ...?professional?.toJson(),
        },
      );

  Future<UserModel> me() => _api.get(
        '/api/auth/me',
        (json) => UserModel.fromJson(readMap(json, 'user')),
      );

  Future<void> logout() => _api.post<void>('/api/auth/logout', (_) {});
}
