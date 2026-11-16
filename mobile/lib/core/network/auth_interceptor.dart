import 'package:dio/dio.dart';

import '../../data/local/token_storage.dart';

/// Coloca o token Bearer em toda requisição e avisa quando a API recusa o token (401).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required void Function() onUnauthorized,
  })  : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized;

  final TokenStorage _tokenStorage;
  final void Function() _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Faz o backend devolver o token no corpo (em vez de cookie) no login/cadastro.
    options.headers['X-Client'] = 'mobile';
    final token = await _tokenStorage.read();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && sentToken) _onUnauthorized();
    handler.next(err);
  }
}
