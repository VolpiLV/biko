import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/repositories/auth_repository.dart';
import 'session_view_model.dart';

/// Dados digitados no formulário de cadastro.
class RegisterInput {
  const RegisterInput({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });

  final String name;
  final String email;
  final String phone;
  final String password;
  final UserRole role;
}

class RegisterViewModel extends BaseViewModel {
  RegisterViewModel(this._repository, this._session);

  final AuthRepository _repository;
  final SessionViewModel _session;

  bool _loading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  /// Erro de um campo vindo do servidor (ex.: e-mail já cadastrado).
  String? fieldError(String field) => _fieldErrors[field];

  /// Chamado quando o usuário edita o campo: o erro do servidor deixa de valer.
  void clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
  }

  /// Retorna true se a conta foi criada (o roteador leva para a home).
  Future<bool> submit(RegisterInput input) async {
    if (_loading) return false;
    _loading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notify();
    try {
      final user = await _repository.register(
        name: input.name.trim(),
        email: input.email.trim().toLowerCase(),
        phone: input.phone.trim(),
        password: input.password,
        role: input.role,
      );
      _session.signIn(user);
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _fieldErrors = e.fields;
      return false;
    } finally {
      _loading = false;
      notify();
    }
  }
}
