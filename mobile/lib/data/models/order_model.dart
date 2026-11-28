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
  confirmar('confirmar', 'Aceitar pedido', 'Pedido aceito. O cliente foi avisado.'),
  recusar('recusar', 'Recusar', 'Pedido recusado.'),
  atrasar('atrasar', 'Avisar atraso / imprevisto', 'Cliente avisado. O horário foi adiado.'),
  iniciar('iniciar', 'Cheguei ao local / Iniciar', 'Atendimento iniciado. O cliente foi avisado.'),
  estender('estender', 'Preciso de mais tempo', 'Tempo prorrogado. A agenda foi ajustada.'),
  concluir('concluir', 'Concluir serviço', 'Serviço concluído!'),
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

/// Rótulo de um item do histórico: status do pedido ou evento da agenda elástica.
String orderEventLabel(String kind) {
  const extra = {
    'atrasado': 'Aviso de atraso',
    'iniciado': 'Atendimento iniciado',
    'prorrogado': 'Tempo prorrogado',
    'remarcado': 'Horário remarcado',
    'pago': 'Pagamento aprovado',
    'estornado': 'Pagamento estornado',
  };
  for (final s in OrderStatus.values) {
    if (s.apiValue == kind) return s.label;
  }
  return extra[kind] ?? kind; // evento novo no backend: mostra o código em vez de quebrar
}

/// Item do histórico de mudanças de status.
class OrderEvent {
  const OrderEvent({required this.kind, required this.createdAt, this.note, this.actorName});

  /// "pendente", "confirmado"... ou "iniciado", "prorrogado", "remarcado".
  final String kind;

  String get label => orderEventLabel(kind);
  final DateTime createdAt;
  final String? note;
  final String? actorName;

  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
        kind: readString(json, 'status'),
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
    this.inProgress = false,
    this.startedTime,
    this.plannedEndTime,
    this.extendedMin = 0,
    this.delayMin = 0,
    this.originalTime,
    this.delayReason,
    this.realDurationMin,
    this.payment,
    this.canPay = false,
    this.protectionFee = 0,
    double? total,
    this.canReview = false,
    this.review,
    this.clientSince,
  }) : total = total ?? price + protectionFee;

  /// Taxa de Proteção Biko cobrada do cliente (R$ 5,00 no Figma).
  final double protectionFee;

  /// Serviço + taxa de proteção: o que o cliente paga.
  final double total;

  /// Cliente pode avaliar (serviço concluído e ainda sem avaliação).
  final bool canReview;
  final OrderReview? review;

  /// Desde quando o cliente usa o Biko ("Cliente Biko desde nov/2026").
  final DateTime? clientSince;

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

  // ---- agenda elástica ----
  /// Prestador já apertou "Iniciar atendimento" e ainda não concluiu.
  final bool inProgress;
  final String? startedTime;
  final String? plannedEndTime;

  /// Minutos que o prestador prorrogou (imprevisto).
  final int extendedMin;

  /// Minutos que este pedido foi adiado (aviso de atraso do prestador ou
  /// atraso do atendimento anterior).
  final int delayMin;
  final String? originalTime;

  /// Motivo do atraso que o cliente vê (ex.: "Falta de luz").
  final String? delayReason;

  // ---- pagamento (simulado) ----
  /// null = ainda não houve tentativa de pagamento.
  final OrderPayment? payment;

  /// O usuário logado é o cliente e o pedido está pronto para pagar.
  final bool canPay;

  bool get isPaid => payment?.status == PaymentStatus.pago;
  bool get awaitingPix => payment?.status == PaymentStatus.aguardando;
  final int? realDurationMin;

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
      inProgress: json['in_progress'] == true,
      startedTime: readStringOrNull(json, 'started_time'),
      plannedEndTime: readStringOrNull(json, 'planned_end_time'),
      extendedMin: readNumOrNull(json, 'extended_min')?.round() ?? 0,
      delayMin: readNumOrNull(json, 'delay_min')?.round() ?? 0,
      originalTime: readStringOrNull(json, 'original_time'),
      delayReason: readStringOrNull(json, 'delay_reason'),
      realDurationMin: readNumOrNull(json, 'real_duration_min')?.round(),
      payment: json['payment'] is Map<String, dynamic> ? OrderPayment.fromJson(readMap(json, 'payment')) : null,
      canPay: json['can_pay'] == true,
      protectionFee: readNumOrNull(json, 'protection_fee') ?? 0,
      total: readNumOrNull(json, 'total'),
      canReview: json['can_review'] == true,
      review: json['review'] is Map<String, dynamic> ? OrderReview.fromJson(readMap(json, 'review')) : null,
      clientSince: readDateFlexibleOrNull(json, 'client_since'),
    );
  }

  bool get isActive => status == OrderStatus.pendente || status == OrderStatus.confirmado;

  /// Data e hora de início no fuso do aparelho.
  DateTime get startsAt {
    final p = date.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2], int.parse(time.substring(0, 2)), int.parse(time.substring(3, 5)));
  }

  /// "Iniciar" mais de 30 min antes do horário é uma antecipação (pede confirmação).
  bool isEarlyStart(DateTime now) => startsAt.difference(now) > const Duration(minutes: 30);
}

/// Avaliação que o cliente deu depois do serviço.
class OrderReview {
  const OrderReview({required this.stars, this.comment});

  final int stars;
  final String? comment;

  factory OrderReview.fromJson(Map<String, dynamic> json) =>
      OrderReview(stars: readInt(json, 'stars'), comment: readStringOrNull(json, 'comment'));
}

/// Situação do pagamento guardada no pedido (o detalhe completo fica no microsserviço).
enum PaymentStatus {
  aguardando('aguardando', 'Aguardando Pix'),
  pago('pago', 'Pago'),
  recusado('recusado', 'Recusado'),
  expirado('expirado', 'Expirado'),
  estornoPendente('estorno_pendente', 'Estorno em andamento'),
  estornado('estornado', 'Estornado'),
  outro('', 'Pagamento');

  const PaymentStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Valor novo no backend não quebra o app: vira [outro].
  static PaymentStatus fromApi(Object? value) {
    for (final s in PaymentStatus.values) {
      if (s.apiValue == value) return s;
    }
    return outro;
  }
}

class OrderPayment {
  const OrderPayment({required this.status, this.code});

  final PaymentStatus status;

  /// Código da transação (ex.: BKP-7F3A9C21).
  final String? code;

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        status: PaymentStatus.fromApi(json['status']),
        code: readStringOrNull(json, 'code'),
      );
}
