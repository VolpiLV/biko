import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/notifications/system_notifications.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/remote/notification_service.dart';

/// Sino de notificações: contador de não lidas (atualiza sozinho) e o histórico.
/// Se o microsserviço estiver fora do ar, o sino só fica sem número; o resto do app segue normal.
/// Com [notifier], o que chegar de novo também aparece como pop-up do celular.
class NotificationsViewModel extends BaseViewModel {
  NotificationsViewModel(this._service, {Duration pollEvery = const Duration(seconds: 20), SystemNotifier? notifier})
    : _notifier = notifier {
    unawaited(refreshCount());
    if (pollEvery > Duration.zero) {
      _timer = Timer.periodic(pollEvery, (_) => refreshCount());
    }
  }

  final NotificationService _service;
  final SystemNotifier? _notifier;
  Timer? _timer;

  /// Maior id já visto. null = ainda não consultou (a 1ª consulta só marca o ponto de partida,
  /// para não estourar pop-ups de coisas antigas ao abrir o app).
  int? _lastSeenId;

  final _arrivals = StreamController<List<AppNotification>>.broadcast();

  /// Chegaram notificações novas (ex.: "Novo pedido"): as telas recarregam o que mostram.
  Stream<List<AppNotification>> get arrivals => _arrivals.stream;

  int _unread = 0;
  List<AppNotification> _items = const [];
  bool _loading = false;
  String? _error;

  int get unread => _unread;
  List<AppNotification> get items => _items;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> refreshCount() async {
    try {
      final notifier = _notifier;
      if (notifier == null) {
        _unread = await _service.unreadCount();
      } else {
        // Com pop-ups: busca as últimas para saber QUAIS são novas (não só quantas).
        final page = await _service.list(limit: 10);
        _unread = page.unread;
        final fresh = _takeNew(page.items);
        for (final n in fresh) {
          unawaited(notifier.show(n));
        }
        if (fresh.isNotEmpty) _arrivals.add(fresh);
      }
    } on AppException {
      _unread = 0;
    }
    notify();
  }

  /// Não lidas com id maior que o último visto, da mais antiga para a mais nova.
  List<AppNotification> _takeNew(List<AppNotification> items) {
    final last = _lastSeenId;
    final maxId = items.fold<int>(last ?? 0, (m, n) => n.id > m ? n.id : m);
    _lastSeenId = maxId;
    if (last == null) return const [];
    return [
      for (final n in items.reversed)
        if (!n.read && n.id > last) n,
    ];
  }

  /// Carrega o histórico (abre o sino).
  Future<void> load() async {
    _loading = true;
    _error = null;
    notify();
    try {
      final page = await _service.list();
      _items = page.items;
      _unread = page.unread;
      _takeNew(page.items); // já estão na tela: não viram pop-up depois
    } on AppException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notify();
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    _items = [for (final i in _items) i.id == n.id ? i.copyWith(read: true) : i];
    if (_unread > 0) _unread--;
    notify();
    try {
      _unread = await _service.markRead(n.id);
      notify();
    } on AppException {
      // a marcação local já resolve para a tela; na próxima atualização o número se acerta
    }
  }

  /// Tocou no pop-up do celular: aquela notificação foi vista.
  Future<void> markReadById(int id) async {
    try {
      _unread = await _service.markRead(id);
      _items = [for (final i in _items) i.id == id ? i.copyWith(read: true) : i];
      notify();
    } on AppException {
      // de outra conta ou já apagada: só segue
    }
  }

  Future<void> markAllRead() async {
    final oldItems = _items, oldUnread = _unread;
    _items = [for (final i in _items) i.copyWith(read: true)];
    _unread = 0;
    notify();
    try {
      await _service.markAllRead();
    } on AppException catch (e) {
      _items = oldItems;
      _unread = oldUnread;
      _error = e.message;
      notify();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_arrivals.close());
    super.dispose();
  }
}
