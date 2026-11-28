// Testes das partes novas que vieram das telas do Figma.
import 'package:biko_mobile/core/utils/formatters.dart';
import 'package:biko_mobile/core/utils/validators.dart';
import 'package:biko_mobile/data/models/chat_models.dart';
import 'package:biko_mobile/data/models/order_model.dart';
import 'package:biko_mobile/data/models/paged.dart';
import 'package:biko_mobile/data/remote/order_service.dart';
import 'package:biko_mobile/features/provider/viewmodels/provider_view_models.dart';
import 'package:biko_mobile/data/models/provider_models.dart';
import 'package:biko_mobile/data/models/user_model.dart';
import 'package:biko_mobile/data/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> orderJson({String date = '2026-11-30', String time = '10:00', String status = 'confirmado', String end = '11:00'}) => {
      'id': 7,
      'status': status,
      'service_title': 'Troca de torneira',
      'category': 'Encanador',
      'price': 120,
      'date': date,
      'time': time,
      'end_time': end,
      'duration_min': 60,
      'address': 'Rua A, 10',
      'client': {'id': 2, 'name': 'Maria Cliente'},
      'provider': {'id': 3, 'name': 'Carlos Prestador'},
      'actions': ['cancelar'],
      'protection_fee': 5,
      'total': 125,
      'can_review': true,
      'review': {'stars': 4, 'comment': 'Bom'},
      'client_since': '2026-11-16 19:42:00',
    };

void main() {
  group('Verificação do Profissional', () {
    test('CPF com dígitos verificadores', () {
      expect(Validators.cpfValid('529.982.247-25'), isTrue);
      expect(Validators.cpfValid('52998224725'), isTrue);
      expect(Validators.cpfValid('529.982.247-24'), isFalse);
      expect(Validators.cpfValid('111.111.111-11'), isFalse);
      expect(Validators.cpfValid('123'), isFalse);
    });

    test('idade e maioridade', () {
      final today = DateTime(2026, 11, 27);
      expect(Validators.ageOf('27/11/2008', today: today), 18);
      expect(Validators.ageOf('28/11/2008', today: today), 17);
      expect(Validators.ageOf('31/02/2000', today: today), isNull); // data que não existe
      expect(Validators.ageOf('01/01/2030', today: today), isNull); // futuro
      expect(Validators.birthDate('2000'), 'Informe a data no formato DD/MM/AAAA.');
    });

    test('máscaras de CPF e data', () {
      expect(Fmt.cpf('52998224725'), '529.982.247-25');
      expect(Fmt.cpf('5299'), '529.9');
      expect(Fmt.birth('01022000'), '01/02/2000');
      expect(Fmt.birth('0102'), '01/02');
    });
  });

  test('login aceita e-mail ou telefone', () {
    expect(Validators.loginId(''), 'Informe o e-mail ou telefone.');
    expect(Validators.loginId('cliente@biko.com'), isNull);
    expect(Validators.loginId('(47) 99999-0002'), isNull);
    expect(Validators.loginId('4799'), 'Informe um e-mail ou telefone válido.');
  });

  test('"Hoje", "Amanhã", "Ontem" e "Qua, 26/11"', () {
    final now = DateTime(2026, 11, 27, 15);
    expect(Fmt.dayLabel('2026-11-27', now: now), 'Hoje');
    expect(Fmt.dayLabel('2026-11-28', now: now), 'Amanhã');
    expect(Fmt.dayLabel('2026-11-26', now: now), 'Ontem');
    expect(Fmt.dayLabel('2026-11-25', now: now), 'Qua, 25/11');
    expect(Fmt.rating(4.8), '4,8');
  });

  group('modelos', () {
    test('pedido com taxa de proteção, avaliação e "cliente desde"', () {
      final o = OrderModel.fromJson(orderJson());
      expect(o.protectionFee, 5);
      expect(o.total, 125);
      expect(o.canReview, isTrue);
      expect(o.review?.stars, 4);
      expect(o.clientSince?.year, 2026);
    });

    test('total cai para preço + taxa quando a API não manda', () {
      final o = OrderModel.fromJson(orderJson()..remove('total'));
      expect(o.total, 125);
    });

    test('iniciar mais de 30 min antes é antecipação', () {
      final o = OrderModel.fromJson(orderJson(date: '2026-11-30', time: '10:00'));
      expect(o.isEarlyStart(DateTime(2026, 11, 30, 9, 40)), isFalse);
      expect(o.isEarlyStart(DateTime(2026, 11, 30, 9, 0)), isTrue);
    });

    test('prestador com perfil profissional', () {
      final u = UserModel.fromJson({
        'id': 3,
        'name': 'Carlos',
        'email': 'prestador@biko.com',
        'role': 'prestador',
        'active': true,
        'specialty': 'Encanador',
        'visit_price': 50,
        'online': false,
        'categories': ['Encanador'],
        'verified': true,
      });
      expect(u.online, isFalse);
      expect(u.visitPrice, 50);
      expect(u.categories, ['Encanador']);
      expect(u.verified, isTrue);
    });

    test('conversas e mensagens', () {
      final list = ConversationList.fromJson({
        'nao_lidas': 2,
        'conversas': [
          {
            'user': {'id': 3, 'name': 'Carlos', 'role': 'prestador', 'online': true},
            'unread': 2,
            'last': {'text': 'Oi!', 'mine': false, 'created_at': 1764000000000},
          },
        ],
      });
      expect(list.unread, 2);
      expect(list.items.single.person.role, UserRole.prestador);
      final t = ChatThread.fromJson({
        'other': {'id': 3, 'name': 'Carlos', 'role': 'prestador', 'phone': '(47) 9999-0000'},
        'next_order': {'id': 7, 'date': '2026-11-30', 'time': '10:00', 'status': 'confirmado', 'title': 'Torneira'},
        'messages': [
          {'id': 1, 'text': 'Oi', 'mine': true, 'created_at': 1764000000000},
        ],
      });
      expect(t.nextOrder?.status, OrderStatus.confirmado);
      expect(t.messages.single.mine, isTrue);
      expect(t.other.phone, isNotNull);
    });

    test('perfil público e carteira', () {
      final p = ProviderProfile.fromJson({
        'id': 3,
        'name': 'Carlos',
        'rating': 4.5,
        'reviews_count': 2,
        'categories': ['Encanador'],
        'reviews': [
          {'stars': 5, 'comment': 'Ótimo', 'client_name': 'Maria Cliente'},
        ],
        'services': [
          {'id': 1, 'title': 'Torneira', 'category': 'Encanador', 'price': 120, 'duration_min': 60},
        ],
        'portfolio': [
          {'id': 9, 'url': '/api/portfolio/9/foto'},
        ],
      });
      expect(p.services.single.providerName, 'Carlos'); // serviço já vem pronto para agendar
      expect(p.categoryOn('Encanador'), isTrue);
      expect(p.categoryOn('Pintor'), isFalse);
      final w = Wallet.fromJson({
        'disponivel': 108,
        'pendente': 0,
        'este_mes': 108,
        'chave_pix': 'prestador@biko.com',
        'historico': [
          {'tipo': 'saque', 'titulo': 'Saque Pix efetuado', 'valor': 10, 'quando': 1764000000000},
          {'tipo': 'entrada', 'titulo': 'Torneira', 'valor': 108, 'quando': 1764000000000, 'liberado': false},
        ],
      });
      expect(w.history.first.isWithdrawal, isTrue);
      expect(w.history.last.released, isFalse);
    });
  });

  test('agenda do prestador: compromissos do dia e horários livres de 1 h ou mais', () async {
    final service = _FakeOrders([
      OrderModel.fromJson(orderJson(date: '2026-11-30', time: '09:00', end: '10:00')),
      OrderModel.fromJson(orderJson(date: '2026-11-30', time: '10:30', end: '12:00', status: 'pendente')),
      OrderModel.fromJson(orderJson(date: '2026-12-01', time: '14:00', end: '15:00')),
    ]);
    final vm = OrdersAgendaViewModel(service, clock: () => DateTime(2026, 11, 29, 8));
    await vm.load();
    vm.selectDay(DateTime(2026, 11, 30));
    expect(vm.ofDay.map((o) => o.time), ['09:00', '10:30']);
    // 07:00-09:00 livre; 10:00-10:30 é curto demais; 12:00-20:00 livre.
    expect(vm.freeSlots, [('07:00', '09:00'), ('12:00', '20:00')]);
    expect(vm.markedDays, {'2026-11-30', '2026-12-01'});
    vm.dispose();
  });
}

class _FakeOrders implements OrderService {
  _FakeOrders(this.orders);

  final List<OrderModel> orders;

  @override
  Future<Paged<OrderModel>> list({OrderStatus? status, int offset = 0, int? limit}) async =>
      Paged(items: orders, total: orders.length, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
