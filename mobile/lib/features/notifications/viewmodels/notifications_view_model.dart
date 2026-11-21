import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/remote/notification_service.dart';

/// Sino de notificações: contador de não lidas (atualiza sozinho) e o histórico.
/// Se o microsserviço estiver fora do ar, o sino só fica sem número; o resto do app segue normal.
class NotificationsViewModel extends BaseViewModel {
  NotificationsViewModel(this._service, {Duration pollEvery = const Duration(seconds: 20)}) {
    unawaited(refreshCount());
    if (pollEvery > Duration.zero) {
      _timer = Timer.periodic(pollEvery, (_) => refreshCount());
    }
  }

  final NotificationService _service;
  Timer? _timer;

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
      _unread = await _service.unreadCount();
    } on AppException {
      _unread = 0;
    }
    notify();
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
    super.dispose();
  }
}
