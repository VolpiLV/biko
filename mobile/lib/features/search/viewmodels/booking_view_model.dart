import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/viewmodel/form_view_model.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/order_model.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../data/remote/order_service.dart';

/// Um horário de início possível no dia escolhido.
class TimeSlot {
  const TimeSlot(this.time, {this.busy = false, this.past = false});

  final String time;
  final bool busy;
  final bool past;

  bool get available => !busy && !past;

  String get label => busy ? '$time (ocupado)' : past ? '$time (indisponível)' : time;
}

/// Agendamento de um serviço: escolhe data, vê os horários livres e envia o pedido.
/// As regras de horário são as mesmas do backend (o backend confere de novo).
class BookingViewModel extends FormViewModel {
  BookingViewModel({
    required this.service,
    required CatalogService catalog,
    required OrderService orders,
    DateTime Function()? clock,
  })  : _catalog = catalog,
        _orders = orders,
        _now = clock ?? DateTime.now;

  static const int openMinutes = 7 * 60; // 07:00
  static const int closeMinutes = 20 * 60; // 20:00
  static const int stepMinutes = 30;
  static const Duration minLead = Duration(hours: 1);
  static const int maxDaysAhead = 60;

  final ServiceModel service;
  final CatalogService _catalog;
  final OrderService _orders;
  final DateTime Function() _now;

  DateTime? _date;
  List<TimeSlot> _slots = const [];
  bool _loadingSlots = false;
  String? _slotsError;
  String? _time;

  DateTime? get date => _date;
  List<TimeSlot> get slots => _slots;
  bool get loadingSlots => _loadingSlots;
  String? get slotsError => _slotsError;
  String? get time => _time;
  bool get hasFreeSlot => _slots.any((s) => s.available);

  DateTime get firstDay {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get lastDay => firstDay.add(const Duration(days: maxDaysAhead));

  Future<void> selectDate(DateTime day) async {
    _date = DateTime(day.year, day.month, day.day);
    _time = null;
    clearFieldError('date');
    clearFieldError('time');
    await loadSlots();
  }

  void selectTime(String? time) {
    _time = time;
    clearFieldError('time');
    notify();
  }

  Future<void> loadSlots() async {
    final day = _date;
    if (day == null) return;
    _loadingSlots = true;
    _slotsError = null;
    notify();
    try {
      final busy = await _catalog.providerAgenda(service.providerId, Fmt.ymd(day));
      if (day != _date) return; // trocou de data enquanto carregava
      _slots = buildSlots(day, busy);
      if (_time != null && !_slots.any((s) => s.time == _time && s.available)) _time = null;
    } on AppException catch (e) {
      _slotsError = e.message;
      _slots = const [];
    }
    _loadingSlots = false;
    notify();
  }

  /// Horários de 30 em 30 min dentro do expediente que cabem a duração do serviço.
  List<TimeSlot> buildSlots(DateTime day, List<BusySlot> busy) {
    final earliest = _now().add(minLead);
    final duration = service.durationMin;
    return [
      for (var m = openMinutes; m + duration <= closeMinutes; m += stepMinutes)
        TimeSlot(
          Fmt.hhmm(m),
          busy: busy.any((b) => m < Fmt.toMinutes(b.end) && m + duration > Fmt.toMinutes(b.start)),
          past: DateTime(day.year, day.month, day.day, m ~/ 60, m % 60).isBefore(earliest),
        ),
    ];
  }

  /// Envia o pedido. Retorna o pedido criado ou null (erros ficam nos campos).
  Future<OrderModel?> book({required String address, required String notes}) async {
    final day = _date, time = _time;
    if (day == null || time == null) return null;
    final order = await submit(
      () => _orders.create(
        serviceId: service.id,
        date: Fmt.ymd(day),
        time: time,
        address: address,
        notes: notes,
      ),
    );
    // 409 = alguém ocupou o horário: atualiza a lista para o usuário escolher outro.
    if (order == null && fieldError('time') != null) await loadSlots();
    return order;
  }
}
