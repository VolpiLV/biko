import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';

enum SessionStatus { checking, authenticated, unauthenticated, failed }

/// Estado global da sessão. O roteador escuta este objeto para proteger as rotas.
class SessionViewModel extends BaseViewModel {
  SessionViewModel(this._repository, Stream<void> unauthorizedEvents) {
    _subscription = unauthorizedEvents.listen((_) => _expire());
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _subscription;

  SessionStatus _status = SessionStatus.checking;
  UserModel? _user;
  String? _errorMessage;
  String? _pendingNotice;

  SessionStatus get status => _status;
  UserModel? get user => _user;

  /// Mensagem quando não deu para verificar a sessão (ex.: sem internet).
  String? get errorMessage => _errorMessage;

  /// Verifica o token salvo ao abrir o app (sessão persistida).
  Future<void> restore() async {
    _status = SessionStatus.checking;
    _errorMessage = null;
    notify();
    try {
      final user = await _repository.restoreSession();
      _user = user;
      _status =
          user == null ? SessionStatus.unauthenticated : SessionStatus.authenticated;
    } on AppException catch (e) {
      _status = SessionStatus.failed;
      _errorMessage = e.message;
    }
    notify();
  }

  void signIn(UserModel user) {
    _user = user;
    _status = SessionStatus.authenticated;
    notify();
  }

  /// Dados da conta mudaram (perfil, foto): atualiza quem estiver mostrando o usuário.
  void updateUser(UserModel user) {
    if (_status != SessionStatus.authenticated) return;
    _user = user;
    notify();
  }

  Future<void> signOut() async {
    await _repository.logout();
    _user = null;
    _status = SessionStatus.unauthenticated;
    notify();
  }

  /// Aviso para a tela de login mostrar uma única vez.
  String? takeNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  Future<void> _expire() async {
    if (_status != SessionStatus.authenticated) return;
    _user = null;
    _status = SessionStatus.unauthenticated;
    _pendingNotice = 'Sua sessão expirou. Entre novamente.';
    notify();
    await _repository.clearLocalSession();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
