/// Caminhos de todas as rotas do app (nenhuma tela usa string solta).
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String registerSegment = 'cadastro';
  static const String register = '$login/$registerSegment';
  static const String home = '/home';

  /// Rotas que não exigem login.
  static bool isPublic(String location) =>
      location == login || location.startsWith('$login/');
}
