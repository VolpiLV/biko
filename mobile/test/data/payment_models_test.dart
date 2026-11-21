import 'package:biko_mobile/data/models/notification_model.dart';
import 'package:biko_mobile/data/models/order_model.dart';
import 'package:biko_mobile/data/models/payment_models.dart';
import 'package:biko_mobile/features/payments/viewmodels/payment_view_model.dart';
import 'package:biko_mobile/features/payments/widgets/payment_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> chargeJson({String status = 'aprovado', String metodo = 'cartao'}) => {
      'id': 7,
      'codigo': 'BKP-7F3A9C21',
      'pedido_id': 10,
      'descricao': 'Reparo de vazamentos',
      'pagador': {'id': 2, 'nome': 'Maria Cliente'},
      'recebedor': {'id': 3, 'nome': 'Carlos Silva'},
      'valor': 120,
      'taxa': 12,
      'liquido': 108,
      'metodo': metodo,
      'parcelas': 3,
      'cartao': metodo == 'cartao' ? {'final': '4242', 'bandeira': 'Visa'} : null,
      'pix_copia_cola': metodo == 'pix' ? '000201...BR.GOV.BCB.PIX' : null,
      'autorizacao': '123456',
      'status': status,
      'motivo': null,
      'criada_em': 1763700000000,
      'expira_em': null,
      'pago_em': 1763700060000,
      'estornado_em': null,
    };

void main() {
  group('Charge', () {
    test('lê a cobrança do microsserviço de pagamentos', () {
      final c = Charge.fromJson(chargeJson());
      expect(c.code, 'BKP-7F3A9C21');
      expect(c.status, ChargeStatus.aprovado);
      expect(c.method, PaymentMethod.cartao);
      expect([c.amount, c.fee, c.net], [120, 12, 108]);
      expect(c.methodLabel, 'Visa •••• 4242 · 3x');
      expect(c.paidAt, DateTime.fromMillisecondsSinceEpoch(1763700060000));
    });

    test('Pix sem cartão e status novo não quebra', () {
      final c = Charge.fromJson(chargeJson(status: 'qualquer', metodo: 'pix'));
      expect(c.method, PaymentMethod.pix);
      expect(c.cardLast4, isNull);
      expect(c.status, ChargeStatus.outro);
      expect(c.methodLabel, 'Pix');
    });

    test('SalesPage lê lista + resumo', () {
      final p = SalesPage.fromJson({
        'cobrancas': [chargeJson()],
        'total': 1,
        'limit': 20,
        'offset': 0,
        'has_more': false,
        'resumo': {'vendas': 1, 'bruto': 120, 'taxa': 12, 'liquido': 108, 'pix': 0, 'cartao': 1, 'estornos': 0},
      });
      expect(p.page.items.single.id, 7);
      expect(p.summary.net, 108);
    });
  });

  group('OrderPayment', () {
    test('status do pagamento no pedido', () {
      expect(PaymentStatus.fromApi('pago'), PaymentStatus.pago);
      expect(PaymentStatus.fromApi('estorno_pendente'), PaymentStatus.estornoPendente);
      expect(PaymentStatus.fromApi('novo'), PaymentStatus.outro);
      expect(OrderPayment.fromJson({'status': 'aguardando', 'code': 'BKP-1'}).code, 'BKP-1');
    });
  });

  group('AppNotification', () {
    test('título é o nome da ação, sem data', () {
      final page = NotificationPage.fromJson({
        'notificacoes': [
          {'id': 1, 'acao': 'pago', 'titulo': 'Pagamento recebido', 'mensagem': 'Maria pagou.', 'pedido_id': 10, 'lida': false},
        ],
        'nao_lidas': 1,
        'total': 1,
        'has_more': false,
      });
      final n = page.items.single;
      expect(n.title, 'Pagamento recebido');
      expect(n.orderId, 10);
      expect(n.read, isFalse);
      expect(n.copyWith(read: true).read, isTrue);
      expect(page.unread, 1);
    });
  });

  group('cartão', () {
    test('bandeira pelo número', () {
      expect(cardBrandOf('4242424242424242'), 'Visa');
      expect(cardBrandOf('5555444433332222'), 'Mastercard');
      expect(cardBrandOf('6362970000457013'), 'Elo');
      expect(cardBrandOf('9999'), 'Cartão');
    });

    test('máscaras de número e validade', () {
      TextEditingValue f(TextInputFormatter fmt, String t) =>
          fmt.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t));
      expect(f(CardNumberFormatter(), '42424242424242429999').text, '4242 4242 4242 4242');
      expect(f(CardNumberFormatter(), '4242a42').text, '4242 42');
      expect(f(CardExpiryFormatter(), '1230').text, '12/30');
      expect(f(CardExpiryFormatter(), '1').text, '1');
    });
  });
}
