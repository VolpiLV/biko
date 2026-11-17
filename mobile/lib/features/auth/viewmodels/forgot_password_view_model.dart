import '../../../core/viewmodel/form_view_model.dart';
import '../../../data/remote/profile_service.dart';

enum ForgotStep { email, reset }

/// Recuperação de senha em 2 passos: pedir o código e definir a nova senha.
/// Em desenvolvimento o servidor devolve o código na resposta (em produção iria por e-mail).
class ForgotPasswordViewModel extends FormViewModel {
  ForgotPasswordViewModel(this._service);

  final ProfileService _service;

  ForgotStep _step = ForgotStep.email;
  String? _info;
  String? _devToken;

  ForgotStep get step => _step;
  String? get info => _info;
  String? get devToken => _devToken;

  void goToReset() {
    _step = ForgotStep.reset;
    clearErrors();
  }

  void backToEmail() {
    _step = ForgotStep.email;
    clearErrors();
  }

  Future<void> requestCode(String email) async {
    final r = await submit(() => _service.forgotPassword(email));
    if (r == null) return;
    _info = r.message;
    _devToken = r.devToken;
    notify();
  }

  /// Retorna a mensagem de sucesso, ou null se deu erro.
  Future<String?> reset({required String token, required String password}) =>
      submit(() => _service.resetPassword(token: token, password: password));
}
