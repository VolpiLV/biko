import '../../core/network/api_client.dart';
import '../models/chat_models.dart';

/// Conversas entre cliente e prestador (/api/conversas).
class ChatService {
  const ChatService(this._api);

  final ApiClient _api;

  Future<ConversationList> list() => _api.get('/api/conversas', ConversationList.fromJson);

  /// Abre a conversa com a pessoa [userId] (e marca as mensagens dela como lidas).
  Future<ChatThread> thread(int userId) => _api.get('/api/conversas/$userId', ChatThread.fromJson);

  Future<void> send(int userId, String text) =>
      _api.post<void>('/api/conversas/$userId', (_) {}, body: {'texto': text.trim()});
}
