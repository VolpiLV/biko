import 'dart:convert';
import 'dart:typed_data';

import 'package:biko_mobile/core/errors/app_exception.dart';
import 'package:biko_mobile/core/network/api_client.dart';
import 'package:biko_mobile/core/utils/json_reader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// Servidor falso: devolve a resposta configurada e guarda a última requisição.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Simula "sem internet".
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );

  @override
  void close({bool force = false}) {}
}

({ApiClient client, _FakeAdapter adapter}) _clientReturning(
  int status,
  Object body, {
  String? token,
}) {
  final adapter = _FakeAdapter(status, body is String ? body : jsonEncode(body));
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
  final client = ApiClient(
    tokenStorage: InMemoryTokenStorage(token),
    dio: dio,
  );
  return (client: client, adapter: adapter);
}

Map<String, dynamic> _identity(Map<String, dynamic> json) => json;

void main() {
  test('envia X-Client: mobile e o token Bearer salvo', () async {
    final (:client, :adapter) =
        _clientReturning(200, {'ok': true}, token: validToken);
    await client.get('/api/auth/me', _identity);
    final headers = adapter.lastRequest!.headers;
    expect(headers['X-Client'], 'mobile');
    expect(headers['Authorization'], 'Bearer $validToken');
  });

  test('sem token salvo não envia Authorization', () async {
    final (:client, :adapter) = _clientReturning(200, {'ok': true});
    await client.post('/api/auth/login', _identity, body: {'email': 'a'});
    expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
  });

  test('401 com token avisa que a sessão expirou', () async {
    final (:client, adapter: _) = _clientReturning(
      401,
      {'error': 'Sessão expirada. Faça login novamente.'},
      token: validToken,
    );
    var notified = 0;
    final sub = client.onUnauthorized.listen((_) => notified++);
    await expectLater(
      client.get('/api/auth/me', _identity),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.unauthorized),
      ),
    );
    await sub.cancel();
    expect(notified, 1);
  });

  test('409 traz a mensagem e os erros por campo do servidor', () async {
    final (:client, adapter: _) = _clientReturning(409, {
      'error': 'Este e-mail já está cadastrado.',
      'fields': {'email': 'E-mail já cadastrado.'},
    });
    await expectLater(
      client.post('/api/auth/register', _identity),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.conflict)
            .having((e) => e.message, 'message', 'Este e-mail já está cadastrado.')
            .having((e) => e.fields['email'], 'fields', 'E-mail já cadastrado.'),
      ),
    );
  });

  test('500 nunca mostra detalhe técnico', () async {
    final (:client, adapter: _) =
        _clientReturning(500, {'error': 'SQLITE_BUSY: database is locked'});
    await expectLater(
      client.get('/api/x', _identity),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.server)
            .having((e) => e.message, 'message', isNot(contains('SQLITE'))),
      ),
    );
  });

  test('JSON inválido vira erro amigável', () async {
    final (:client, adapter: _) = _clientReturning(200, '{isso não é json');
    await expectLater(
      client.get('/api/x', _identity),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.invalidResponse),
      ),
    );
  });

  test('parser que encontra campo com tipo errado vira erro amigável', () async {
    final (:client, adapter: _) = _clientReturning(200, {'user': 'texto'});
    await expectLater(
      client.get('/api/x', (json) => readMap(json, 'user')),
      throwsA(
        isA<AppException>()
            .having((e) => e.kind, 'kind', AppErrorKind.invalidResponse),
      ),
    );
  });

  test('sem internet -> AppErrorKind.network', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = _OfflineAdapter();
    final client = ApiClient(tokenStorage: InMemoryTokenStorage(), dio: dio);
    await expectLater(
      client.get('/api/x', _identity),
      throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.network)),
    );
  });
}
