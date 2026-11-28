// "Voltar" do Android (botão ou gesto) na área logada: volta de aba em vez de fechar o app.
import 'package:biko_mobile/data/models/user_role.dart';
import 'package:biko_mobile/features/home/viewmodels/home_navigation.dart';
import 'package:biko_mobile/features/home/widgets/tab_back_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Mesma montagem do app: GoRouter com a Home como rota; telas abertas por cima com Navigator.push.
class _App {
  _App(UserRole role) : nav = HomeNavigation(role);

  final HomeNavigation nav;
  int exits = 0;

  Widget build() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChangeNotifierProvider.value(
            value: nav,
            child: TabBackHandler(
              onExit: () async => exits++,
              child: Builder(
                builder: (context) {
                  final current = context.watch<HomeNavigation>().current;
                  return Scaffold(
                    body: Column(
                      children: [
                        Text('aba:${current.name}'),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('tela de detalhe'))),
                          ),
                          child: const Text('abrir detalhe'),
                        ),
                        TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const SizedBox(height: 200, child: Text('folha')),
                          ),
                          child: const Text('abrir folha'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }
}

/// Simula o botão/gesto "voltar" do sistema Android.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('HomeNavigation.back', () {
    test('volta pelas abas visitadas e termina no Início', () {
      final nav = HomeNavigation(UserRole.cliente)
        ..goTo(AppTab.search)
        ..goTo(AppTab.chats)
        ..goTo(AppTab.agenda);
      expect(nav.back(), isTrue);
      expect(nav.current, AppTab.chats);
      expect(nav.back(), isTrue);
      expect(nav.current, AppTab.search);
      expect(nav.back(), isTrue);
      expect(nav.current, AppTab.home);
      expect(nav.back(), isFalse, reason: 'no Início não há mais para onde voltar');
    });

    test('não repete abas (A -> B -> A -> B volta em 2 passos)', () {
      final nav = HomeNavigation(UserRole.prestador)
        ..goTo(AppTab.wallet)
        ..goTo(AppTab.profile)
        ..goTo(AppTab.wallet)
        ..goTo(AppTab.profile);
      nav.back();
      expect(nav.current, AppTab.wallet);
      nav.back();
      expect(nav.current, AppTab.home);
      expect(nav.canGoBack, isFalse);
    });

    test('ir para o Início pelo menu limpa o caminho', () {
      final nav = HomeNavigation(UserRole.cliente)
        ..goTo(AppTab.search)
        ..goTo(AppTab.home);
      expect(nav.canGoBack, isFalse);
      expect(nav.back(), isFalse);
    });

    test('aba de outro perfil é ignorada', () {
      final nav = HomeNavigation(UserRole.cliente)..goTo(AppTab.wallet);
      expect(nav.current, AppTab.home);
      expect(nav.canGoBack, isFalse);
    });
  });

  group('Voltar do sistema na área logada', () {
    testWidgets('volta para a aba anterior em vez de fechar o app', (tester) async {
      final app = _App(UserRole.cliente);
      await tester.pumpWidget(app.build());
      app.nav
        ..goTo(AppTab.search)
        ..goTo(AppTab.chats);
      await tester.pumpAndSettle();
      expect(find.text('aba:chats'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('aba:search'), findsOneWidget);
      await systemBack(tester);
      expect(find.text('aba:home'), findsOneWidget);
      expect(app.exits, 0);
    });

    testWidgets('no Início: 1º toque avisa, 2º toque fecha', (tester) async {
      final app = _App(UserRole.cliente);
      await tester.pumpWidget(app.build());

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(TabBackHandler.exitMessage), findsOneWidget);
      expect(app.exits, 0);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(app.exits, 1);
    });

    testWidgets('depois de 2 s o aviso recomeça (não fecha sem querer)', (tester) async {
      final app = _App(UserRole.cliente);
      await tester.pumpWidget(app.build());
      await systemBack(tester);
      await tester.pump(const Duration(seconds: 3));
      await systemBack(tester);
      expect(app.exits, 0);
    });

    testWidgets('tela aberta por cima fecha primeiro e a aba continua a mesma', (tester) async {
      final app = _App(UserRole.cliente);
      await tester.pumpWidget(app.build());
      app.nav.goTo(AppTab.agenda);
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir detalhe'));
      await tester.pumpAndSettle();
      expect(find.text('tela de detalhe'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('tela de detalhe'), findsNothing);
      expect(find.text('aba:agenda'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('aba:home'), findsOneWidget);
    });

    testWidgets('folha de baixo fecha primeiro', (tester) async {
      final app = _App(UserRole.cliente);
      await tester.pumpWidget(app.build());
      app.nav.goTo(AppTab.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir folha'));
      await tester.pumpAndSettle();
      expect(find.text('folha'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('folha'), findsNothing);
      expect(find.text('aba:search'), findsOneWidget);
    });
  });
}
