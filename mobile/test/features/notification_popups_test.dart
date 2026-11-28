// Pop-ups de notificação no celular: quais notificações viram pop-up e o que o toque abre.
import 'package:biko_mobile/core/notifications/system_notifications.dart';
import 'package:biko_mobile/data/models/notification_model.dart';
import 'package:biko_mobile/data/remote/notification_service.dart';
import 'package:biko_mobile/features/notifications/viewmodels/notifications_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(int id, {bool read = false, int? order}) => AppNotification(
      id: id,
      action: 'confirmado',
      title: 'Pedido confirmado',
      message: 'Carlos confirmou o pedido $id.',
      read: read,
      orderId: order ?? id * 10,
    );

/// Servidor de mentira: a lista vem do mais novo para o mais antigo, como a API real.
class _FakeService implements NotificationService {
  List<AppNotification> items = [];
  final marked = <int>[];

  @override
  Future<NotificationPage> list({int limit = 30, int offset = 0}) async {
    final sorted = [...items]..sort((a, b) => b.id.compareTo(a.id));
    return NotificationPage(
      items: sorted.take(limit).toList(),
      unread: items.where((n) => !n.read).length,
      total: items.length,
      hasMore: items.length > limit,
    );
  }

  @override
  Future<int> unreadCount() async => items.where((n) => !n.read).length;

  @override
  Future<int> markRead(int id) async {
    marked.add(id);
    items = [for (final n in items) n.id == id ? n.copyWith(read: true) : n];
    return unreadCount();
  }

  @override
  Future<void> markAllRead() async {}

  @override
  Future<bool> registerDevice(String token) async => true;
}

class _FakeNotifier implements SystemNotifier {
  final shown = <int>[];

  @override
  Future<void> show(AppNotification n) async => shown.add(n.id);
}

void main() {
  group('NotificationsViewModel com pop-ups', () {
    late _FakeService service;
    late _FakeNotifier notifier;

    NotificationsViewModel make() => NotificationsViewModel(service, pollEvery: Duration.zero, notifier: notifier);

    setUp(() {
      service = _FakeService();
      notifier = _FakeNotifier();
    });

    test('ao abrir o app, as antigas NÃO viram pop-up (só o número do sino)', () async {
      service.items = [_n(1), _n(2)];
      final vm = make();
      await vm.refreshCount();
      expect(notifier.shown, isEmpty);
      expect(vm.unread, 2);
    });

    test('notificação nova vira pop-up uma vez só', () async {
      service.items = [_n(1)];
      final vm = make();
      await vm.refreshCount();
      service.items = [_n(1), _n(2)];
      await vm.refreshCount();
      expect(notifier.shown, [2]);
      await vm.refreshCount();
      expect(notifier.shown, [2], reason: 'a mesma não aparece de novo');
    });

    test('várias novas: da mais antiga para a mais nova; lidas em outro aparelho não aparecem', () async {
      final vm = make();
      await vm.refreshCount(); // sem nenhuma ainda
      service.items = [_n(3), _n(4, read: true), _n(5)];
      await vm.refreshCount();
      expect(notifier.shown, [3, 5]);
    });

    test('avisa as telas quando chega algo novo (para recarregar a Início/agenda)', () async {
      final vm = make();
      await vm.refreshCount();
      final got = <List<int>>[];
      final sub = vm.arrivals.listen((l) => got.add([for (final n in l) n.id]));
      service.items = [_n(8)];
      await vm.refreshCount();
      await vm.refreshCount(); // nada novo: não avisa de novo
      await Future<void>.delayed(Duration.zero);
      expect(got, [
        [8],
      ]);
      await sub.cancel();
    });

    test('as que já apareceram no sino aberto não viram pop-up depois', () async {
      final vm = make();
      await vm.refreshCount();
      service.items = [_n(7)];
      await vm.load(); // a pessoa abriu o sino e viu
      await vm.refreshCount();
      expect(notifier.shown, isEmpty);
    });

    test('sem notifier (web/testes antigos): só conta, nada de pop-up', () async {
      service.items = [_n(1)];
      final vm = NotificationsViewModel(service, pollEvery: Duration.zero);
      await vm.refreshCount();
      expect(vm.unread, 1);
    });

    test('tocar no pop-up marca aquela notificação como lida', () async {
      service.items = [_n(1), _n(2)];
      final vm = make();
      await vm.refreshCount();
      await vm.markReadById(2);
      expect(service.marked, [2]);
      expect(vm.unread, 1);
    });
  });

  group('NotificationTap (o que o toque no pop-up abre)', () {
    test('payload do pop-up local leva notificação e pedido', () {
      final p = NotificationTap.payloadOf(15, 42);
      final t = NotificationTap.fromPayload(p);
      expect(t.notificationId, 15);
      expect(t.orderId, 42);
    });

    test('sem pedido: abre o sino', () {
      final t = NotificationTap.fromPayload(NotificationTap.payloadOf(15, null));
      expect(t.notificationId, 15);
      expect(t.orderId, isNull);
    });

    test('payload vazio ou estranho não quebra', () {
      expect(NotificationTap.fromPayload(null).orderId, isNull);
      expect(NotificationTap.fromPayload('lixo').notificationId, isNull);
    });

    test('dados do push do Firebase (strings, como o microsserviço manda)', () {
      final t = NotificationTap.fromData({'notificacao_id': '9', 'pedido_id': '77', 'acao': 'pago'});
      expect(t.notificationId, 9);
      expect(t.orderId, 77);
      expect(NotificationTap.fromData({'notificacao_id': '9', 'pedido_id': ''}).orderId, isNull);
    });
  });
}
