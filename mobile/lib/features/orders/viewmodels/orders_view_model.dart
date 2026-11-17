import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/form_view_model.dart';
import '../../../core/viewmodel/paged_list_view_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/paged.dart';
import '../../../data/remote/order_service.dart';

/// Aba "Pedidos": lista paginada com filtro por status.
/// Cada perfil recebe do backend só os pedidos que pode ver.
class OrdersViewModel extends PagedListViewModel<OrderModel> {
  OrdersViewModel(this._service);

  final OrderService _service;
  OrderStatus? _filter;

  OrderStatus? get filter => _filter;

  /// Troca o filtro. Com [reload] false só guarda (a aba recarrega ao abrir).
  void setFilter(OrderStatus? status, {bool reload = true}) {
    _filter = status;
    if (reload) {
      refresh();
    } else {
      notify();
    }
  }

  @override
  Future<Paged<OrderModel>> fetchPage(int offset) => _service.list(status: _filter, offset: offset);
}

/// Detalhe de um pedido com o histórico e as ações permitidas.
class OrderDetailViewModel extends FormViewModel {
  OrderDetailViewModel(this._service, this.orderId);

  final OrderService _service;
  final int orderId;

  OrderModel? _order;
  bool _loadingOrder = true;
  String? _loadError;

  OrderModel? get order => _order;
  bool get loadingOrder => _loadingOrder;
  String? get loadError => _loadError;

  Future<void> load() async {
    _loadingOrder = true;
    _loadError = null;
    notify();
    try {
      _order = await _service.detail(orderId);
    } on AppException catch (e) {
      _loadError = e.message;
    }
    _loadingOrder = false;
    notify();
  }

  /// Ação que exige (ou aceita) um motivo antes de enviar.
  bool asksReason(OrderAction action) =>
      action == OrderAction.recusar || action == OrderAction.cancelar;

  /// Cancelar é com motivo opcional só para o cliente do pedido;
  /// recusar (prestador) e cancelar como prestador/admin exigem motivo.
  bool reasonRequired(OrderAction action, int userId) =>
      action == OrderAction.recusar || (action == OrderAction.cancelar && _order?.client.id != userId);

  /// Retorna true se deu certo.
  Future<bool> run(OrderAction action, {String? reason}) async {
    final updated = await submit(() => _service.changeStatus(orderId, action, reason: reason));
    return updated != null;
  }
}
