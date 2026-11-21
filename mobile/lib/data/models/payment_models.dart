import '../../core/utils/json_reader.dart';
import 'paged.dart';

/// Forma de pagamento aceita pelo microsserviço de pagamentos (simulado).
enum PaymentMethod {
  pix('pix', 'Pix'),
  cartao('cartao', 'Cartão de crédito');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethod fromApi(Object? value) =>
      value == 'cartao' ? PaymentMethod.cartao : PaymentMethod.pix;
}

/// Situação de uma cobrança no microsserviço.
enum ChargeStatus {
  aguardando('aguardando', 'Aguardando Pix'),
  aprovado('aprovado', 'Aprovado'),
  recusado('recusado', 'Recusado'),
  expirado('expirado', 'Expirado'),
  estornado('estornado', 'Estornado'),
  outro('', 'Pagamento');

  const ChargeStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ChargeStatus fromApi(Object? value) {
    for (final s in ChargeStatus.values) {
      if (s.apiValue == value) return s;
    }
    return outro;
  }
}

class ChargeParty {
  const ChargeParty({required this.id, this.name});

  final int id;
  final String? name;

  factory ChargeParty.fromJson(Map<String, dynamic> json) =>
      ChargeParty(id: readInt(json, 'id'), name: readStringOrNull(json, 'nome'));
}

/// Cobrança / comprovante (`view` em pagamentos/server.js).
class Charge {
  const Charge({
    required this.id,
    required this.code,
    required this.orderId,
    required this.description,
    required this.payer,
    required this.receiver,
    required this.amount,
    required this.fee,
    required this.net,
    required this.method,
    required this.installments,
    required this.status,
    required this.createdAt,
    this.cardLast4,
    this.cardBrand,
    this.pixCode,
    this.authorization,
    this.reason,
    this.expiresAt,
    this.paidAt,
  });

  final int id;

  /// Código da transação, ex.: BKP-7F3A9C21.
  final String code;
  final int orderId;
  final String description;
  final ChargeParty payer;
  final ChargeParty receiver;
  final double amount;

  /// Taxa da plataforma (10%).
  final double fee;

  /// O que o prestador recebe.
  final double net;
  final PaymentMethod method;
  final int installments;
  final String? cardLast4;
  final String? cardBrand;

  /// Código Pix "copia e cola" (só para quem paga e só enquanto aguarda).
  final String? pixCode;
  final String? authorization;
  final ChargeStatus status;
  final String? reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  /// "Pix" ou "Visa •••• 4242 · 3x".
  String get methodLabel => method == PaymentMethod.pix
      ? 'Pix'
      : '${cardBrand ?? 'Cartão'} •••• ${cardLast4 ?? '----'}${installments > 1 ? ' · ${installments}x' : ''}';

  static DateTime? _ms(Map<String, dynamic> json, String key) {
    final v = readNumOrNull(json, key);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v.round());
  }

  factory Charge.fromJson(Map<String, dynamic> json) {
    final card = json['cartao'];
    return Charge(
      id: readInt(json, 'id'),
      code: readString(json, 'codigo'),
      orderId: readInt(json, 'pedido_id'),
      description: readString(json, 'descricao'),
      payer: ChargeParty.fromJson(readMap(json, 'pagador')),
      receiver: ChargeParty.fromJson(readMap(json, 'recebedor')),
      amount: readNum(json, 'valor'),
      fee: readNum(json, 'taxa'),
      net: readNum(json, 'liquido'),
      method: PaymentMethod.fromApi(json['metodo']),
      installments: readInt(json, 'parcelas'),
      cardLast4: card is Map<String, dynamic> ? readStringOrNull(card, 'final') : null,
      cardBrand: card is Map<String, dynamic> ? readStringOrNull(card, 'bandeira') : null,
      pixCode: readStringOrNull(json, 'pix_copia_cola'),
      authorization: readStringOrNull(json, 'autorizacao'),
      status: ChargeStatus.fromApi(json['status']),
      reason: readStringOrNull(json, 'motivo'),
      createdAt: _ms(json, 'criada_em') ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: _ms(json, 'expira_em'),
      paidAt: _ms(json, 'pago_em'),
    );
  }
}

/// Resumo de vendas/pagamentos (só cobranças aprovadas entram nos valores).
class SalesSummary {
  const SalesSummary({
    required this.sales,
    required this.gross,
    required this.fee,
    required this.net,
    required this.pix,
    required this.card,
    required this.refunds,
  });

  static const empty = SalesSummary(sales: 0, gross: 0, fee: 0, net: 0, pix: 0, card: 0, refunds: 0);

  final int sales;
  final double gross;
  final double fee;
  final double net;
  final int pix;
  final int card;
  final int refunds;

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        sales: readInt(json, 'vendas'),
        gross: readNum(json, 'bruto'),
        fee: readNum(json, 'taxa'),
        net: readNum(json, 'liquido'),
        pix: readInt(json, 'pix'),
        card: readInt(json, 'cartao'),
        refunds: readInt(json, 'estornos'),
      );
}

/// Resposta de GET /api/pagamentos: lista paginada + resumo.
class SalesPage {
  const SalesPage({required this.page, required this.summary});

  final Paged<Charge> page;
  final SalesSummary summary;

  factory SalesPage.fromJson(Map<String, dynamic> json) => SalesPage(
        page: Paged.fromJson(json, 'cobrancas', Charge.fromJson),
        summary: SalesSummary.fromJson(readMap(json, 'resumo')),
      );
}

/// Resposta de pagar / confirmar Pix: a cobrança + o pedido atualizado.
class PaymentResult {
  const PaymentResult({required this.charge});

  final Charge charge;

  factory PaymentResult.fromJson(Map<String, dynamic> json) =>
      PaymentResult(charge: Charge.fromJson(readMap(json, 'cobranca')));
}
