// Widget tests das telas de autenticação.
// (O nome widget_test.dart também impede o `flutter create .` de gerar o teste de exemplo.)
import 'package:biko_mobile/core/errors/app_exception.dart';
import 'package:biko_mobile/core/theme/app_theme.dart';
import 'package:biko_mobile/data/repositories/auth_repository.dart';
import 'package:biko_mobile/features/auth/viewmodels/login_view_model.dart';
import 'package:biko_mobile/features/auth/viewmodels/register_view_model.dart';
import 'package:biko_mobile/features/auth/viewmodels/session_view_model.dart';
import 'package:biko_mobile/features/auth/views/login_screen.dart';
import 'package:biko_mobile/features/auth/views/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fakes.dart';

class _Harness {
  _Harness() {
    repository = AuthRepository(service: service, tokens: tokens);
    session = SessionViewModel(repository, const Stream<void>.empty());
  }

  final service = FakeAuthService();
  final tokens = InMemoryTokenStorage();
  late final AuthRepository repository;
  late final SessionViewModel session;

  Widget login({ThemeData? theme}) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider(
            create: (_) => LoginViewModel(repository, session),
          ),
        ],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: const LoginScreen()),
      );

  /// Cadastro empilhado sobre uma tela inicial, para testar o botão "voltar".
  Widget register() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider(
            create: (_) => RegisterViewModel(repository, session),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('abrir cadastro'),
                ),
              ),
            ),
          ),
        ),
      );
}

void main() {
  group('LoginScreen', () {
    testWidgets('valida campos vazios sem chamar a API', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.login());
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(find.text('Informe o e-mail.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
      expect(h.service.lastLoginEmail, isNull);
    });

    testWidgets('credencial inválida mostra a mensagem do servidor', (tester) async {
      final h = _Harness()
        ..service.loginError = const AppException(
          AppErrorKind.unauthorized,
          'E-mail ou senha inválidos.',
        );
      await tester.pumpWidget(h.login());
      await tester.enterText(find.byType(TextFormField).at(0), 'cliente@biko.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'errada123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
      expect(h.session.status, isNot(SessionStatus.authenticated));
    });

    testWidgets('login válido autentica e guarda o token', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.login());
      await tester.enterText(find.byType(TextFormField).at(0), 'cliente@biko.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Cliente@123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(h.session.status, SessionStatus.authenticated);
      expect(h.tokens.token, validToken);
    });

    testWidgets('não estoura em tela pequena, tema escuro e fonte 1.5x', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final h = _Harness();
      await tester.pumpWidget(h.login(theme: AppTheme.dark));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('RegisterScreen (proteção do formulário)', () {
    Future<void> openRegister(WidgetTester tester, _Harness h) async {
      await tester.pumpWidget(h.register());
      await tester.tap(find.text('abrir cadastro'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
    }

    testWidgets('formulário vazio: voltar sai direto', (tester) async {
      final h = _Harness();
      await openRegister(tester, h);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
    });

    testWidgets('com dados digitados: pede confirmação antes de sair', (tester) async {
      final h = _Harness();
      await openRegister(tester, h);
      await tester.enterText(find.byType(TextFormField).first, 'Ana');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Descartar cadastro?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
    });

    testWidgets('e-mail já cadastrado aparece no próprio campo', (tester) async {
      final h = _Harness()
        ..service.registerError = const AppException(
          AppErrorKind.conflict,
          'Este e-mail já está cadastrado.',
          fields: {'email': 'E-mail já cadastrado.'},
        );
      await openRegister(tester, h);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana Souza');
      await tester.enterText(fields.at(1), 'cliente@biko.com');
      await tester.enterText(fields.at(3), 'Senha1234');
      await tester.enterText(fields.at(4), 'Senha1234');
      final submit = find.widgetWithText(FilledButton, 'Criar conta');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('E-mail já cadastrado.'), findsOneWidget);
      expect(find.text('Este e-mail já está cadastrado.'), findsOneWidget);
    });
  });
}
