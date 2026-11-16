import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/auth/viewmodels/login_view_model.dart';
import '../../features/auth/viewmodels/register_view_model.dart';
import '../../features/auth/viewmodels/session_view_model.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/auth/views/splash_screen.dart';
import '../../features/home/views/home_screen.dart';
import 'app_routes.dart';

/// Regra de proteção das rotas (guard). Função pura para poder ser testada sozinha.
String? resolveRedirect(SessionStatus status, String location) {
  final isPublic = AppRoutes.isPublic(location);
  final isSplash = location == AppRoutes.splash;
  return switch (status) {
    // Ainda verificando o token (ou falhou por falta de rede): fica na splash.
    SessionStatus.checking || SessionStatus.failed =>
      isSplash ? null : AppRoutes.splash,
    // Sem login: só telas públicas.
    SessionStatus.unauthenticated => isPublic ? null : AppRoutes.login,
    // Logado: não volta para login/cadastro/splash.
    SessionStatus.authenticated =>
      (isPublic || isSplash) ? AppRoutes.home : null,
  };
}

/// O roteador escuta a sessão: login, logout e sessão expirada mudam a tela sozinhos.
GoRouter buildRouter(SessionViewModel session) => GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: session,
      redirect: (context, state) =>
          resolveRedirect(session.status, state.matchedLocation),
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => LoginViewModel(
              context.read<AuthRepository>(),
              context.read<SessionViewModel>(),
            ),
            child: const LoginScreen(),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.registerSegment,
              builder: (context, state) => ChangeNotifierProvider(
                create: (context) => RegisterViewModel(
                  context.read<AuthRepository>(),
                  context.read<SessionViewModel>(),
                ),
                child: const RegisterScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
