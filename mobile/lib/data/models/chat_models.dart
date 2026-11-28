import '../../core/utils/json_reader.dart';
import 'order_model.dart';
import 'user_role.dart';

/// A outra pessoa da conversa (`otherView` no server.js). O telefone só vem
/// quando existe um pedido confirmado entre os dois.
class ChatPerson {
  const ChatPerson({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
    this.specialty,
    this.online = true,
    this.phone,
  });

  final int id;
  final String name;
  final UserRole role;
  final String? photoUrl;
  final String? specialty;
  final bool online;
  final String? phone;

  bool get isProvider => role == UserRole.prestador;

  factory ChatPerson.fromJson(Map<String, dynamic> json) => ChatPerson(
        id: readInt(json, 'id'),
        name: readString(json, 'name'),
        role: UserRole.fromApi(json['role']),
        photoUrl: readStringOrNull(json, 'photo_url'),
        specialty: readStringOrNull(json, 'specialty'),
        online: json['online'] != false,
        phone: readStringOrNull(json, 'phone'),
      );
}

/// Item da lista "Conversas".
class Conversation {
  const Conversation({
    required this.person,
    required this.unread,
    required this.lastText,
    required this.lastMine,
    required this.lastAt,
  });

  final ChatPerson person;
  final int unread;
  final String lastText;
  final bool lastMine;
  final DateTime lastAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final last = readMap(json, 'last');
    return Conversation(
      person: ChatPerson.fromJson(readMap(json, 'user')),
      unread: readInt(json, 'unread'),
      lastText: readString(last, 'text'),
      lastMine: readBool(last, 'mine'),
      lastAt: DateTime.fromMillisecondsSinceEpoch(readInt(last, 'created_at')),
    );
  }
}

/// Resposta de GET /api/conversas.
class ConversationList {
  const ConversationList({required this.items, required this.unread});

  final List<Conversation> items;
  final int unread;

  factory ConversationList.fromJson(Map<String, dynamic> json) => ConversationList(
        items: readList(json, 'conversas', Conversation.fromJson),
        unread: readInt(json, 'nao_lidas'),
      );
}

class ChatMessage {
  const ChatMessage({required this.id, required this.text, required this.mine, required this.createdAt});

  final int id;
  final String text;
  final bool mine;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: readInt(json, 'id'),
        text: readString(json, 'text'),
        mine: readBool(json, 'mine'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(readInt(json, 'created_at')),
      );
}

/// Próximo pedido ativo entre os dois (atalho no topo do chat).
class ChatNextOrder {
  const ChatNextOrder({required this.id, required this.date, required this.time, required this.status, required this.title});

  final int id;
  final String date;
  final String time;
  final OrderStatus status;
  final String title;

  factory ChatNextOrder.fromJson(Map<String, dynamic> json) => ChatNextOrder(
        id: readInt(json, 'id'),
        date: readString(json, 'date'),
        time: readString(json, 'time'),
        status: OrderStatus.fromApi(json['status']),
        title: readString(json, 'title'),
      );
}

/// Resposta de GET /api/conversas/:id (abrir a conversa marca como lida).
class ChatThread {
  const ChatThread({required this.other, required this.messages, this.nextOrder});

  final ChatPerson other;
  final List<ChatMessage> messages;
  final ChatNextOrder? nextOrder;

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
        other: ChatPerson.fromJson(readMap(json, 'other')),
        messages: readList(json, 'messages', ChatMessage.fromJson),
        nextOrder: json['next_order'] is Map<String, dynamic> ? ChatNextOrder.fromJson(readMap(json, 'next_order')) : null,
      );
}
