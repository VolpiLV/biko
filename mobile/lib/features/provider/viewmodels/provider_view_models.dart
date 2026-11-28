import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/provider_models.dart';
import '../../../data/remote/order_service.dart';
import '../../../data/remote/provider_service.dart';
import '../../auth/viewmodels/session_view_model.dart';

/// Perfil do prestador: o público (cliente abre pela busca) ou o "Meu Perfil Profissional".
class ProviderProfileViewModel extends BaseViewModel {
  /// [providerId] null = o perfil do próprio prestador logado (pode editar).
  ProviderProfileViewModel(this._service, {this.providerId, SessionViewModel? session}) : _session = session;

  final ProviderService _service;
  final int? providerId;
  final SessionViewModel? _session;

  bool get mine => providerId == null;

  ProviderProfile? _profile;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  ProviderProfile? get profile => _profile;
  bool get loading => _loading;

  /// Salvando alguma alteração (foto, categoria...).
  bool get busy => _busy;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notify();
    try {
      final id = providerId;
      _profile = id == null ? await _service.myProfile() : await _service.publicProfile(id);
    } on AppException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notify();
  }

  /// Retorna null se salvou, ou a mensagem de erro (com o erro do campo quando houver).
  Future<String?> update({String? specialty, String? visitPrice, bool? online, List<String>? categories}) =>
      _run(() async {
        final r = await _service.update(specialty: specialty, visitPrice: visitPrice, online: online, categories: categories);
        _profile = r.profile;
        _session?.updateUser(r.user);
      });

  Future<String?> toggleCategory(String name, bool on) {
    final p = _profile;
    if (p == null) return Future.value(null);
    final current = p.categories ?? [for (final c in _allCategories) c];
    final next = on ? {...current, name}.toList() : current.where((c) => c != name).toList();
    return update(categories: next);
  }

  Future<String?> addPhoto(Uint8List bytes) => _run(() async {
        await _service.addPortfolioPhoto(bytes);
        _profile = await _service.myProfile();
      });

  Future<String?> removePhoto(int id) => _run(() async {
        await _service.removePortfolioPhoto(id);
        _profile = await _service.myProfile();
      });

  Future<String?> _run(Future<void> Function() action) async {
    if (_busy) return null;
    _busy = true;
    notify();
    try {
      await action();
      return null;
    } on AppException catch (e) {
      return e.fields.values.firstOrNull ?? e.message;
    } finally {
      _busy = false;
      notify();
    }
  }

  static const List<String> _allCategories = [
    'Telhado & Reparador', 'Encanador', 'Eletricista', 'Pintor', 'Limpeza', 'Jardinagem',
  ];
}

/// "Ganhos e Carteira" (SIMULADO).
class WalletViewModel extends BaseViewModel {
  WalletViewModel(this._service);

  final ProviderService _service;

  Wallet? _wallet;
  bool _loading = false;
  String? _error;

  Wallet? get wallet => _wallet;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notify();
    try {
      _wallet = await _service.wallet();
    } on AppException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notify();
  }

  /// Retorna (mensagem de sucesso, null) ou (null, erro).
  Future<(String?, String?)> withdraw(String amount) async {
    try {
      final r = await _service.withdraw(amount);
      _wallet = r.wallet;
      notify();
      return (r.message, null);
    } on AppException catch (e) {
      return (null, e.fields['valor'] ?? e.message);
    }
  }
}

/// Lista com todos os pedidos do usuário (até 100), para as agendas e o "Ver todas".
class OrdersAgendaViewModel extends BaseViewModel {
  OrdersAgendaViewModel(this._service, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final OrderService _service;
  final DateTime Function() _now;

  List<OrderModel> _orders = const [];
  int _total = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  OrderStatus? _filter;
  late DateTime _day = _today;

  List<OrderModel> get orders => _orders;
  int get total => _total;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  OrderStatus? get filter => _filter;

  DateTime get _today {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Dia escolhido na agenda do prestador.
  DateTime get day => _day;
  List<DateTime> get days => [for (var i = 0; i < 14; i++) _today.add(Duration(days: i))];

  Future<void> load() async {
    _loading = true;
    _error = null;
    notify();
    try {
      final page = await _service.list(status: _filter, limit: 100);
      _orders = page.items;
      _total = page.total;
      _loaded = true;
    } on AppException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notify();
  }

  void setFilter(OrderStatus? status) {
    _filter = status;
    load();
  }

  void selectDay(DateTime d) {
    _day = DateTime(d.year, d.month, d.day);
    notify();
  }

  // ---- agenda do cliente ----
  List<OrderModel> get upcoming =>
      _orders.where((o) => o.isActive).toList()..sort((a, b) => '${a.date}${a.time}'.compareTo('${b.date}${b.time}'));
  List<OrderModel> get past => _orders.where((o) => !o.isActive).toList();

  // ---- agenda do prestador ----
  List<OrderModel> get _agenda =>
      _orders.where((o) => o.isActive || o.status == OrderStatus.concluido).toList();

  /// Dias com compromisso ativo (bolinha na faixa de dias).
  Set<String> get markedDays => {for (final o in _orders) if (o.isActive) o.date};

  List<OrderModel> get ofDay =>
      _agenda.where((o) => o.date == Fmt.ymd(_day)).toList()..sort((a, b) => a.time.compareTo(b.time));

  /// Horários livres de pelo menos 1 h entre 07:00 e 20:00 (contando só o que ainda não passou).
  List<(String, String)> get freeSlots {
    const open = 7 * 60, close = 20 * 60;
    final busy = [
      for (final o in ofDay)
        if (o.status != OrderStatus.concluido) (Fmt.toMinutes(o.time), Fmt.toMinutes(o.endTime)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var cursor = open;
    final now = _now();
    if (Fmt.ymd(_day) == Fmt.ymd(now)) {
      final m = ((now.hour * 60 + now.minute) / 30).ceil() * 30;
      if (m > cursor) cursor = m;
    }
    final out = <(String, String)>[];
    for (final (s, e) in busy) {
      if (s - cursor >= 60) out.add((Fmt.hhmm(cursor), Fmt.hhmm(s)));
      if (e > cursor) cursor = e;
    }
    if (close - cursor >= 60) out.add((Fmt.hhmm(cursor), Fmt.hhmm(close)));
    return out;
  }
}
