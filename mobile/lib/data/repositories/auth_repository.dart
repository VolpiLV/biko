import '../../core/errors/app_exception.dart';
import '../local/token_storage.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../remote/auth_service.dart';

/// Junta a API (AuthService) com o armazenamento seguro do token.
class AuthRepository {
  AuthRepository({required AuthService service, required TokenStorage tokens})
      : _service = service,
        _tokens = tokens;

  final AuthService _service;
  final TokenStorage _tokens;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final result = await _service.login(email: email, password: password);
    await _tokens.save(result.token);
    return result.user;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    ProfessionalCheck? professional,
  }) async {
    final result = await _service.register(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
      professional: professional,
    );
    await _tokens.save(result.token);
    return result.user;
  }

  /// Ao abrir o app: devolve o usuário se o token salvo ainda vale, ou null.
  /// Erros de rede são repassados (o token é mantido para tentar de novo).
  Future<UserModel?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await _service.me();
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.unauthorized ||
          e.kind == AppErrorKind.forbidden) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Sai mesmo sem internet: o token local é apagado de qualquer forma.
  Future<void> logout() async {
    try {
      await _service.logout();
    } on AppException {
      // Sessão já inválida no servidor ou sem conexão: segue com a limpeza local.
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> clearLocalSession() => _tokens.clear();
}
