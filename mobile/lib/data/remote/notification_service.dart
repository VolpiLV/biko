import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/notification_model.dart';

/// Notificações (a API principal repassa para o microsserviço de notificações).
class NotificationService {
  const NotificationService(this._api);

  final ApiClient _api;

  Future<NotificationPage> list({int limit = 30, int offset = 0}) => _api.get(
        '/api/notificacoes',
        NotificationPage.fromJson,
        query: {'limit': limit, if (offset > 0) 'offset': offset},
      );

  /// Só o número de não lidas (para o sino).
  Future<int> unreadCount() =>
      _api.get('/api/notificacoes/contagem', (json) => readInt(json, 'nao_lidas'));

  /// Marca uma como lida. Devolve quantas continuam não lidas.
  Future<int> markRead(int id) =>
      _api.post('/api/notificacoes/$id/lida', (json) => readInt(json, 'nao_lidas'));

  Future<void> markAllRead() => _api.post<void>('/api/notificacoes/lidas', (_) {});

  /// Registra o token deste aparelho para receber push com o app fechado.
  /// Devolve se o servidor está com o push ligado (tem a chave do Firebase).
  Future<bool> registerDevice(String token) => _api.post(
        '/api/dispositivos',
        (json) => readBool(json, 'push_ligado'),
        body: {'token': token, 'plataforma': 'android'},
      );
}
