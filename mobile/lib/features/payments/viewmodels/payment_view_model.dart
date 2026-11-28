import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/form_view_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/payment_models.dart';
import '../../../data/remote/payment_service.dart';

/// Tela de pagamento de um pedido (SIMULADO para a apresentação do TCC).
///  - Pix: gera o código e espera o "Simular pagamento recebido".
///  - Cartão: aprova na hora (cartão terminado em 0002 é recusado, de propósito).
class PaymentViewModel extends FormViewModel {
  PaymentViewModel(this._service, this.order);

  final PaymentService _service;
  final OrderModel order;

  // Como no site: nenhuma forma vem escolhida; o QR do Pix só aparece depois de tocar em Pix.
  PaymentMethod? _method;
  Charge? _pix;
  Charge? _approved;
  String? _cardDeclined;
  bool _resuming = false;

  PaymentMethod? get method => _method;

  /// Tocar na forma já aberta fecha ela de novo.
  void toggleMethod(PaymentMethod m) {
    _method = _method == m ? null : m;
    _cardDeclined = null;
    clearErrors();
    if (_method == PaymentMethod.pix && _pix == null) generatePix();
  }

  /// Pix gerado e aguardando pagamento.
  Charge? get pix => _pix;

  /// Preenchido quando o pagamento foi aprovado (a tela fecha e mostra o comprovante).
  Charge? get approved => _approved;

  /// Motivo da recusa do cartão (simulada).
  String? get cardDeclined => _cardDeclined;
  bool get resuming => _resuming;

  void setMethod(PaymentMethod m) {
    if (m == _method) return;
    _method = m;
    _cardDeclined = null;
    clearErrors();
  }

  /// O pedido já tem um Pix aguardando? Continua dele em vez de gerar outro.
  Future<void> resume() async {
    if (!order.awaitingPix) return;
    _resuming = true;
    notify();
    try {
      final c = await _service.ofOrder(order.id);
      if (c != null && c.status == ChargeStatus.aguardando && c.pixCode != null) _pix = c;
    } on AppException {
      // sem problema: a pessoa gera um Pix novo
    }
    _resuming = false;
    notify();
  }

  Future<void> generatePix() async {
    // Reaproveita um Pix que já esteja aguardando; senão gera um novo.
    if (order.awaitingPix) {
      try {
        final c = await _service.ofOrder(order.id);
        if (c != null && c.status == ChargeStatus.aguardando && c.pixCode != null) {
          _pix = c;
          notify();
          return;
        }
      } on AppException {
        // gera um novo abaixo
      }
    }
    final c = await submit(() => _service.payWithPix(order.id));
    if (c == null) return;
    _pix = c;
    notify();
  }

  /// Retorna true se o pagamento foi aprovado.
  Future<bool> confirmPix() async {
    // pequena pausa só para dar a sensação de "confirmando com o banco"
    final c = await submit(() async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return _service.confirmPix(order.id);
    });
    if (c == null) return false;
    if (c.status == ChargeStatus.aprovado) _approved = c;
    notify();
    return _approved != null;
  }

  /// Retorna true se aprovado. Recusado: [cardDeclined] fica com o motivo.
  Future<bool> payCard({required String last4, required String brand, required int installments}) async {
    _cardDeclined = null;
    final c = await submit(
      () => _service.payWithCard(order.id, last4: last4, brand: brand, installments: installments),
    );
    if (c == null) return false;
    if (c.status == ChargeStatus.aprovado) {
      _approved = c;
    } else {
      _cardDeclined = c.reason ?? 'Pagamento recusado.';
    }
    notify();
    return _approved != null;
  }
}

/// Bandeira pelo começo do número (só para enfeitar o cartão desenhado).
String cardBrandOf(String digits) {
  if (RegExp(r'^(4011|4312|4389|5041|5066|5067|6277|6362|6363|6504|6505|6516)').hasMatch(digits)) return 'Elo';
  if (digits.startsWith('4')) return 'Visa';
  if (RegExp(r'^5[1-5]').hasMatch(digits)) return 'Mastercard';
  return 'Cartão';
}
