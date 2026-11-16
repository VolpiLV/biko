import 'dart:async';

import 'package:biko_mobile/core/errors/app_exception.dart';
import 'package:biko_mobile/core/router/app_router.dart';
import 'package:biko_mobile/core/router/app_routes.dart';
import 'package:biko_mobile/data/models/user_role.dart';
import 'package:biko_mobile/data/repositories/auth_repository.dart';
import 'package:biko_mobile/features/auth/viewmodels/login_view_model.dart';
import 'package:biko_mobile/features/auth/viewmodels/register_view_model.dart';
import 'package:biko_mobile/features/auth/viewmodels/session_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const _offline = AppException(AppErrorKind.network, 'Sem conexão.');
const _expired = AppException(AppErrorKind.unauthorized, 'Sessão expirada.');

void main() {
  late FakeAuthService service;
  late InMemoryTokenStorage tokens;
  late AuthRepository repository;
  late StreamController<void> unauthorized;
  late SessionViewModel session;

  setUp(() {
    service = FakeAuthService();
    tokens = InMemoryTokenStorage();
    repository = AuthRepository(service: service, tokens: tokens);
    unauthorized = StreamController<void>.broadcast();
    session = SessionViewModel(repository, unauthorized.stream);
  });

  tearDown(() async {
    session.dispose();
    await unauthorized.close();
  });

  group('AuthRepository', () {
    test('login salva o token no armazenamento seguro', () async {
      final user = await repository.login(email: 'a@b.com', password: 'x');
      expect(user.email, 'cliente@biko.com');
      expect(tokens.token, validToken);
    });

    test('login com erro não salva token', () async {
      service.loginError = _expired;
      await expectLater(
        repository.login(email: 'a@b.com', password: 'x'),
        throwsA(isA<AppException>()),
      );
      expect(tokens.token, isNull);
    });

    test('logout limpa o token mesmo sem internet', () async {
      tokens.token = validToken;
      service.logoutError = _offline;
      await repository.logout();
      expect(service.logoutCalls, 1);
      expect(tokens.token, isNull);
    });
  });

  group('SessionViewModel (sessão persistida)', () {
    test('sem token salvo -> não autenticado, sem chamar a API', () async {
      service.meError = _offline; // se chamasse a API, viraria "failed"
      await session.restore();
      expect(session.status, SessionStatus.unauthenticated);
    });

    test('token válido -> autenticado com o usuário da API', () async {
      tokens.token = validToken;
      await session.restore();
      expect(session.status, SessionStatus.authenticated);
      expect(session.user?.email, 'cliente@biko.com');
    });

    test('token recusado (401) -> apaga o token e vai para o login', () async {
      tokens.token = validToken;
      service.meError = _expired;
      await session.restore();
      expect(session.status, SessionStatus.unauthenticated);
      expect(tokens.token, isNull);
    });

    test('sem internet -> erro com retry e o token é mantido', () async {
      tokens.token = validToken;
      service.meError = _offline;
      await session.restore();
      expect(session.status, SessionStatus.failed);
      expect(session.errorMessage, 'Sem conexão.');
      expect(tokens.token, validToken);
    });

    test('401 no meio do uso derruba a sessão e deixa um aviso', () async {
      tokens.token = validToken;
      await session.restore();
      unauthorized.add(null);
      await Future<void>.delayed(Duration.zero); // entrega o evento do stream
      expect(session.status, SessionStatus.unauthenticated);
      expect(tokens.token, isNull);
      expect(session.takeNotice(), contains('expirou'));
      expect(session.takeNotice(), isNull); // aparece uma vez só
    });

    test('signOut chama a API e limpa o estado', () async {
      tokens.token = validToken;
      await session.restore();
      await session.signOut();
      expect(service.logoutCalls, 1);
      expect(session.user, isNull);
      expect(session.status, SessionStatus.unauthenticated);
    });
  });

  group('LoginViewModel / RegisterViewModel', () {
    test('login normaliza o e-mail e autentica a sessão', () async {
      final vm = LoginViewModel(repository, session);
      await vm.submit(email: '  Cliente@Biko.com ', password: 'Cliente@123');
      expect(service.lastLoginEmail, 'cliente@biko.com');
      expect(session.status, SessionStatus.authenticated);
      expect(vm.loading, isFalse);
      vm.dispose();
    });

    test('login com erro mostra a mensagem e não autentica', () async {
      service.loginError =
          const AppException(AppErrorKind.unauthorized, 'E-mail ou senha inválidos.');
      final vm = LoginViewModel(repository, session);
      await vm.submit(email: 'a@b.com', password: 'errada');
      expect(vm.errorMessage, 'E-mail ou senha inválidos.');
      expect(session.status, isNot(SessionStatus.authenticated));
      vm.dispose();
    });

    test('cadastro com e-mail repetido expõe o erro do campo até ser editado', () async {
      service.registerError = const AppException(
        AppErrorKind.conflict,
        'Este e-mail já está cadastrado.',
        fields: {'email': 'E-mail já cadastrado.'},
      );
      final vm = RegisterViewModel(repository, session);
      final created = await vm.submit(
        const RegisterInput(
          name: 'Ana Souza',
          email: 'cliente@biko.com',
          phone: '',
          password: 'Senha1234',
          role: UserRole.prestador,
        ),
      );
      expect(created, isFalse);
      expect(vm.fieldError('email'), 'E-mail já cadastrado.');
      vm.clearFieldError('email');
      expect(vm.fieldError('email'), isNull);
      vm.dispose();
    });
  });

  group('Guard de rotas (resolveRedirect)', () {
    test('não autenticado só acessa login/cadastro', () {
      const s = SessionStatus.unauthenticated;
      expect(resolveRedirect(s, AppRoutes.home), AppRoutes.login);
      expect(resolveRedirect(s, AppRoutes.splash), AppRoutes.login);
      expect(resolveRedirect(s, AppRoutes.login), isNull);
      expect(resolveRedirect(s, AppRoutes.register), isNull);
    });

    test('autenticado não volta para login/cadastro/splash', () {
      const s = SessionStatus.authenticated;
      expect(resolveRedirect(s, AppRoutes.login), AppRoutes.home);
      expect(resolveRedirect(s, AppRoutes.register), AppRoutes.home);
      expect(resolveRedirect(s, AppRoutes.splash), AppRoutes.home);
      expect(resolveRedirect(s, AppRoutes.home), isNull);
    });

    test('verificando ou sem conexão: fica na splash', () {
      for (final s in [SessionStatus.checking, SessionStatus.failed]) {
        expect(resolveRedirect(s, AppRoutes.home), AppRoutes.splash);
        expect(resolveRedirect(s, AppRoutes.splash), isNull);
      }
    });

    test('rota parecida com login não é pública', () {
      expect(AppRoutes.isPublic('/loginx'), isFalse);
    });
  });
}
