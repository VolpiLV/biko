import '../../core/utils/json_reader.dart';

/// Status de um pedido (mesmos valores do backend).
enum OrderStatus {
  pendente('pendente', 'Pendente'),
  confirmado('confirmado', 'Confirmado'),
  recusado('recusado', 'Recusado'),
  concluido('concluido', 'Concluído'),
  cancelado('cancelado', 'Cancelado');

  const OrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OrderStatus fromApi(Object? value) {
    for (final s in OrderStatus.values) {
      if (s.apiValue == value) return s;
    }
    throw FormatException('Status de pedido desconhecido: $value');
  }
}

/// Ações que o usuário pode fazer num pedido (a API diz quais valem em `actions`).
enum OrderAction {
  confirmar('confirmar', 'Confirmar pedido', 'Pedido confirmado.'),
  recusar('recusar', 'Recusar', 'Pedido recusado.'),
  concluir('concluir', 'Marcar como concluído', 'Pedido concluído.'),
  cancelar('cancelar', 'Cancelar pedido', 'Pedido cancelado.');

  const OrderAction(this.apiValue, this.label, this.doneMessage);

  final String apiValue;
  final String label;
  final String doneMessage;

  bool get destructive => this == recusar || this == cancelar;

  static OrderAction? fromApi(Object? value) {
    for (final a in OrderAction.values) {
      if (a.apiValue == value) return a;
    }
    return null; // ação nova no backend que o app ainda não conhece: ignora
  }
}

/// Cliente ou prestador de um pedido. O telefone só vem depois de confirmado.
class OrderParty {
  const OrderParty({required this.id, required this.name, this.phone, this.photoUrl});

  final int id;
  final String name;
  final String? phone;
  final String? photoUrl;

  factory OrderParty.fromJson(Map<String, dynamic> json) => OrderParty(
        id: readInt(json, 'id'),
        name: readString(json, 'name'),
        phone: readStringOrNull(json, 'phone'),
        photoUrl: readStringOrNull(json, 'photo_url'),
      );
}

/// Item do histórico de mudanças de status.
class OrderEvent {
  const OrderEvent({required this.status, required this.createdAt, this.note, this.actorName});

  final OrderStatus status;
  final DateTime createdAt;
  final String? note;
  final String? actorName;

  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
        status: OrderStatus.fromApi(json['status']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(readInt(json, 'created_at')),
        note: readStringOrNull(json, 'note'),
        actorName: readStringOrNull(json, 'actor_name'),
      );
}

/// Pedido / agendamento (`orderView` no server.js).
class OrderModel {
  const OrderModel({
    required this.id,
    required this.status,
    required this.serviceTitle,
    required this.category,
    required this.price,
    required this.date,
    required this.time,
    required this.endTime,
    required this.durationMin,
    required this.address,
    required this.client,
    required this.provider,
    required this.actions,
    this.notes,
    this.statusReason,
    this.history = const [],
  });

  final int id;
  final OrderStatus status;
  final String? statusReason;
  final String serviceTitle;
  final String category;
  final double price;

  /// "AAAA-MM-DD"
  final String date;

  /// "HH:MM"
  final String time;
  final String endTime;
  final int durationMin;
  final String address;
  final String? notes;
  final OrderParty client;
  final OrderParty provider;
  final List<OrderAction> actions;

  /// Só vem preenchido em GET /api/orders/:id.
  final List<OrderEvent> history;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    return OrderModel(
      id: readInt(json, 'id'),
      status: OrderStatus.fromApi(json['status']),
      statusReason: readStringOrNull(json, 'status_reason'),
      serviceTitle: readString(json, 'service_title'),
      category: readString(json, 'category'),
      price: readNum(json, 'price'),
      date: readString(json, 'date'),
      time: readString(json, 'time'),
      endTime: readString(json, 'end_time'),
      durationMin: readInt(json, 'duration_min'),
      address: readString(json, 'address'),
      notes: readStringOrNull(json, 'notes'),
      client: OrderParty.fromJson(readMap(json, 'client')),
      provider: OrderParty.fromJson(readMap(json, 'provider')),
      actions: [
        if (rawActions is List)
          for (final a in rawActions) ?OrderAction.fromApi(a),
      ],
      history: json['history'] is List ? readList(json, 'history', OrderEvent.fromJson) : const [],
    );
  }
}
