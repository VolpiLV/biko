import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../data/local/token_storage.dart';
import '../config/env.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import 'auth_interceptor.dart';

typedef JsonParser<T> = T Function(Map<String, dynamic> json);

/// Único ponto do app que faz HTTP. Devolve objetos tipados ou lança [AppException].
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, Dio? dio})
      : _dio = dio ?? Dio(_defaultOptions()) {
    _dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        onUnauthorized: () => _unauthorized.add(null),
      ),
    );
  }

  final Dio _dio;
  final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();

  /// Emite quando o servidor recusa o token salvo (sessão expirada ou revogada).
  Stream<void> get onUnauthorized => _unauthorized.stream;

  static BaseOptions _defaultOptions() => BaseOptions(
        baseUrl: Env.apiBaseUrl,
        // Folgado de propósito: no plano gratuito do Render o servidor "dorme" e leva ~50 s para acordar.
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: const {'Accept': 'application/json'},
      );

  Future<T> get<T>(
    String path,
    JsonParser<T> parse, {
    Map<String, Object?>? query,
  }) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query), parse);

  Future<T> post<T>(String path, JsonParser<T> parse, {Object? body}) =>
      _send(() => _dio.post<Object?>(path, data: body), parse);

  Future<T> patch<T>(String path, JsonParser<T> parse, {Object? body}) =>
      _send(() => _dio.patch<Object?>(path, data: body), parse);

  Future<T> put<T>(String path, JsonParser<T> parse, {Object? body}) =>
      _send(() => _dio.put<Object?>(path, data: body), parse);

  Future<T> delete<T>(String path, JsonParser<T> parse) =>
      _send(() => _dio.delete<Object?>(path), parse);

  /// Baixa um arquivo binário autenticado (ex.: foto de perfil em /api/photo/:id).
  Future<Uint8List> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        throw const AppException(
          AppErrorKind.invalidResponse,
          'Arquivo vazio.',
        );
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<T> _send<T>(
    Future<Response<Object?>> Function() request,
    JsonParser<T> parse,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('A resposta não é um objeto JSON.');
      }
      return parse(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on FormatException {
      throw const AppException(
        AppErrorKind.invalidResponse,
        'Recebemos uma resposta inesperada do servidor. Tente novamente.',
      );
    }
  }
}
