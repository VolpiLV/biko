import '../../core/network/api_client.dart';
import '../models/payment_models.dart';

/// Pagamentos e vendas (SIMULADO — a API principal repassa para o microsserviço de pagamentos).
class PaymentService {
  const PaymentService(this._api);

  final ApiClient _api;

  /// Gera um Pix (fica "aguardando" até simular o pagamento).
  Future<Charge> payWithPix(int orderId) => _api.post(
        '/api/orders/$orderId/pagamento',
        (json) => PaymentResult.fromJson(json).charge,
        body: {'metodo': PaymentMethod.pix.apiValue},
      );

  /// Cartão: só vão os 4 últimos dígitos, a bandeira e as parcelas.
  /// O número inteiro e o CVV nunca saem do aparelho.
  Future<Charge> payWithCard(
    int orderId, {
    required String last4,
    required String brand,
    required int installments,
  }) =>
      _api.post(
        '/api/orders/$orderId/pagamento',
        (json) => PaymentResult.fromJson(json).charge,
        body: {
          'metodo': PaymentMethod.cartao.apiValue,
          'cartao': {'final': last4, 'bandeira': brand, 'parcelas': installments},
        },
      );

  /// "Simular pagamento recebido" do Pix (no mundo real quem avisa é o banco).
  Future<Charge> confirmPix(int orderId) => _api.post(
        '/api/orders/$orderId/pagamento/confirmar',
        (json) => PaymentResult.fromJson(json).charge,
      );

  /// Última cobrança do pedido (comprovante). null se ainda não houve pagamento.
  Future<Charge?> ofOrder(int orderId) => _api.get(
        '/api/orders/$orderId/pagamento',
        (json) => json['cobranca'] is Map<String, dynamic>
            ? Charge.fromJson(json['cobranca'] as Map<String, dynamic>)
            : null,
      );

  /// Cliente: o que pagou. Prestador: o que vendeu. Admin: tudo.
  Future<SalesPage> list({int offset = 0}) => _api.get(
        '/api/pagamentos',
        SalesPage.fromJson,
        query: {if (offset > 0) 'offset': offset},
      );
}
