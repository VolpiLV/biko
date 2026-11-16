import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/repositories/auth_repository.dart';
import 'session_view_model.dart';

class LoginViewModel extends BaseViewModel {
  LoginViewModel(this._repository, this._session);

  final AuthRepository _repository;
  final SessionViewModel _session;

  bool _loading = false;
  String? _errorMessage;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> submit({required String email, required String password}) async {
    if (_loading) return;
    _loading = true;
    _errorMessage = null;
    notify();
    try {
      final user = await _repository.login(
        email: email.trim().toLowerCase(),
        password: password,
      );
      _session.signIn(user);
    } on AppException catch (e) {
      _errorMessage = e.message;
    } finally {
      _loading = false;
      notify();
    }
  }
}
