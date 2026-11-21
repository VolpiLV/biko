import '../../core/utils/json_reader.dart';

/// Notificação vinda do microsserviço de notificações (via /api/notificacoes).
/// O título é o NOME DA AÇÃO ("Pedido confirmado", "Aviso de atraso"...). Não traz data.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.action,
    required this.title,
    required this.message,
    required this.read,
    this.orderId,
  });

  final int id;

  /// Código da ação: pendente, confirmado, atrasado, pago...
  final String action;
  final String title;
  final String message;
  final int? orderId;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        action: action,
        title: title,
        message: message,
        orderId: orderId,
        read: read ?? this.read,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: readInt(json, 'id'),
        action: readString(json, 'acao'),
        title: readString(json, 'titulo'),
        message: readString(json, 'mensagem'),
        orderId: readNumOrNull(json, 'pedido_id')?.round(),
        read: readBool(json, 'lida'),
      );
}

/// Resposta de GET /api/notificacoes.
class NotificationPage {
  const NotificationPage({required this.items, required this.unread, required this.total, required this.hasMore});

  final List<AppNotification> items;
  final int unread;
  final int total;
  final bool hasMore;

  factory NotificationPage.fromJson(Map<String, dynamic> json) => NotificationPage(
        items: readList(json, 'notificacoes', AppNotification.fromJson),
        unread: readInt(json, 'nao_lidas'),
        total: readInt(json, 'total'),
        hasMore: readBool(json, 'has_more'),
      );
}
