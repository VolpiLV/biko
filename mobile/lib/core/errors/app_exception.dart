/// Categorias de falha que a interface sabe tratar.
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  tooManyRequests,
  server,
  invalidResponse,
  unknown,
}

/// Exceção de domínio: a UI só conhece este tipo, nunca DioException,
/// SocketException ou FormatException. [message] já é amigável para o usuário.
class AppException implements Exception {
  const AppException(
    this.kind,
    this.message, {
    this.fields = const {},
    this.statusCode,
  });

  final AppErrorKind kind;
  final String message;

  /// Erros por campo devolvidos pela API (ex.: {'email': 'E-mail já cadastrado.'}).
  final Map<String, String> fields;
  final int? statusCode;

  @override
  String toString() => 'AppException($kind, $statusCode): $message';
}
