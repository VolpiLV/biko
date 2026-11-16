import 'package:dio/dio.dart';

import 'app_exception.dart';

const String _networkMessage =
    'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
const String _serverMessage =
    'Ocorreu um erro no servidor. Tente novamente em instantes.';
const String _invalidResponseMessage =
    'Recebemos uma resposta inesperada do servidor. Tente novamente.';

/// Converte qualquer falha do Dio em [AppException] com mensagem amigável.
AppException mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const AppException(
        AppErrorKind.timeout,
        'O servidor demorou para responder. Tente novamente.',
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const AppException(AppErrorKind.network, _networkMessage);
    case DioExceptionType.cancel:
      return const AppException(AppErrorKind.unknown, 'Operação cancelada.');
    case DioExceptionType.badResponse:
      return _fromResponse(error.response);
    case DioExceptionType.unknown:
      if (error.error is FormatException) {
        return const AppException(
          AppErrorKind.invalidResponse,
          _invalidResponseMessage,
        );
      }
      return const AppException(AppErrorKind.network, _networkMessage);
  }
}

AppException _fromResponse(Response<Object?>? response) {
  final status = response?.statusCode ?? 0;
  final data = response?.data;
  String? serverMessage;
  var fields = const <String, String>{};
  if (data is Map<String, dynamic>) {
    final message = data['error'];
    if (message is String && message.isNotEmpty) serverMessage = message;
    final rawFields = data['fields'];
    if (rawFields is Map<String, dynamic>) {
      fields = {
        for (final entry in rawFields.entries)
          if (entry.value is String) entry.key: entry.value as String,
      };
    }
  }

  final kind = switch (status) {
    400 || 413 => AppErrorKind.validation,
    401 => AppErrorKind.unauthorized,
    403 => AppErrorKind.forbidden,
    404 => AppErrorKind.notFound,
    409 => AppErrorKind.conflict,
    429 => AppErrorKind.tooManyRequests,
    >= 500 => AppErrorKind.server,
    _ => AppErrorKind.unknown,
  };

  // Mensagens 4xx da API já são escritas para o usuário final; 5xx nunca são exibidas.
  final message = kind == AppErrorKind.server
      ? _serverMessage
      : serverMessage ?? 'Não foi possível concluir a operação.';
  return AppException(kind, message, fields: fields, statusCode: status);
}
