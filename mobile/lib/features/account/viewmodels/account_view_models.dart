import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../core/viewmodel/form_view_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/remote/profile_service.dart';
import '../../auth/viewmodels/session_view_model.dart';

/// "Meus dados": nome, e-mail e telefone. Trocar o e-mail pede a senha atual.
class ProfileFormViewModel extends FormViewModel {
  ProfileFormViewModel(this._service, this._session);

  final ProfileService _service;
  final SessionViewModel _session;

  bool emailChanged(String email) =>
      email.trim().toLowerCase() != (_session.user?.email ?? '').toLowerCase();

  Future<bool> save({
    required String name,
    required String email,
    required String phone,
    required String currentPassword,
  }) async {
    final user = await submit(
      () => _service.updateMe(
        name: name,
        email: email,
        phone: phone,
        currentPassword: emailChanged(email) ? currentPassword : null,
      ),
    );
    if (user == null) return false;
    _session.updateUser(user);
    return true;
  }
}

/// "Alterar senha". Retorna a mensagem de sucesso ou null.
class PasswordFormViewModel extends FormViewModel {
  PasswordFormViewModel(this._service);

  final ProfileService _service;

  Future<String?> change({required String current, required String next}) =>
      submit(() => _service.changePassword(current: current, next: next));
}

/// Foto de perfil: enviar e remover.
class PhotoViewModel extends BaseViewModel {
  PhotoViewModel(this._service, this._session);

  final ProfileService _service;
  final SessionViewModel _session;

  bool _busy = false;
  bool get busy => _busy;

  /// Retorna null se deu certo, ou a mensagem de erro.
  Future<String?> upload(Uint8List bytes) => _run(() => _service.uploadPhoto(bytes));

  Future<String?> remove() => _run(_service.removePhoto);

  Future<String?> _run(Future<UserModel> Function() action) async {
    if (_busy) return null;
    _busy = true;
    notify();
    try {
      _session.updateUser(await action());
      return null;
    } on AppException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      notify();
    }
  }
}
