import 'package:biko_mobile/core/errors/app_exception.dart';
import 'package:biko_mobile/data/local/token_storage.dart';
import 'package:biko_mobile/data/models/auth_result.dart';
import 'package:biko_mobile/data/models/user_model.dart';
import 'package:biko_mobile/data/models/user_role.dart';
import 'package:biko_mobile/data/remote/auth_service.dart';

const String validToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> userJson({
  int id = 2,
  String name = 'Maria Cliente',
  String email = 'cliente@biko.com',
  String? phone = '(47) 99999-0002',
  String role = 'cliente',
  bool active = true,
}) =>
    {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'active': active,
      'created_at': '2026-11-16 19:42:00',
      'photo_url': null,
    };

UserModel sampleUser({UserRole role = UserRole.cliente}) =>
    UserModel.fromJson(userJson(role: role.apiValue));

AuthResult sampleAuthResult() => AuthResult(
      user: sampleUser(),
      token: validToken,
      expiresAt: DateTime.utc(2030),
    );

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

/// AuthService controlado pelo teste: define o resultado ou o erro de cada chamada.
class FakeAuthService implements AuthService {
  AuthResult? loginResult;
  AppException? loginError;
  AuthResult? registerResult;
  AppException? registerError;
  UserModel? meResult;
  AppException? meError;
  AppException? logoutError;
  int logoutCalls = 0;
  String? lastLoginEmail;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    final error = loginError;
    if (error != null) throw error;
    return loginResult ?? sampleAuthResult();
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    final error = registerError;
    if (error != null) throw error;
    return registerResult ?? sampleAuthResult();
  }

  @override
  Future<UserModel> me() async {
    final error = meError;
    if (error != null) throw error;
    return meResult ?? sampleUser();
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    final error = logoutError;
    if (error != null) throw error;
  }
}
