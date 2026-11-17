import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/dashboard_models.dart';
import '../models/order_model.dart';
import '../models/paged.dart';

/// Pedidos/agendamentos e painel do prestador.
class OrderService {
  const OrderService(this._api);

  final ApiClient _api;

  Future<Paged<OrderModel>> list({OrderStatus? status, int offset = 0}) => _api.get(
        '/api/orders',
        (json) => Paged.fromJson(json, 'orders', OrderModel.fromJson),
        query: {
          if (status != null) 'status': status.apiValue,
          if (offset > 0) 'offset': offset,
        },
      );

  /// Pedido com o histórico de status.
  Future<OrderModel> detail(int id) => _api.get(
        '/api/orders/$id',
        (json) => OrderModel.fromJson(readMap(json, 'order')),
      );

  Future<OrderModel> create({
    required int serviceId,
    required String date,
    required String time,
    required String address,
    required String notes,
  }) =>
      _api.post(
        '/api/orders',
        (json) => OrderModel.fromJson(readMap(json, 'order')),
        body: {
          'service_id': serviceId,
          'date': date,
          'time': time,
          'address': address.trim(),
          'notes': notes.trim(),
        },
      );

  Future<OrderModel> changeStatus(int id, OrderAction action, {String? reason}) => _api.post(
        '/api/orders/$id/status',
        (json) => OrderModel.fromJson(readMap(json, 'order')),
        body: {
          'action': action.apiValue,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );

  Future<ProviderPanel> providerPanel() =>
      _api.get('/api/prestador/painel', ProviderPanel.fromJson);
}
