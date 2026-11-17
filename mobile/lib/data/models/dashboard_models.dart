import '../../core/utils/json_reader.dart';
import 'order_model.dart';

/// Painel do prestador (/api/prestador/painel).
class ProviderPanel {
  const ProviderPanel({
    required this.newOrders,
    required this.monthEarnings,
    required this.upcoming,
    this.rating,
  });

  final int newOrders;
  final double? rating;
  final double monthEarnings;
  final List<OrderModel> upcoming;

  factory ProviderPanel.fromJson(Map<String, dynamic> json) {
    final r = readMap(json, 'resumo');
    return ProviderPanel(
      newOrders: readInt(r, 'pedidosNovos'),
      rating: readNumOrNull(r, 'avaliacao'),
      monthEarnings: readNum(r, 'ganhosMes'),
      upcoming: readList(json, 'proximos', OrderModel.fromJson),
    );
  }
}

/// Números do painel do admin (/api/admin/resumo).
class AdminSummary {
  const AdminSummary({
    required this.clients,
    required this.providers,
    required this.disabled,
    required this.orders,
    required this.pending,
    required this.completed,
  });

  final int clients;
  final int providers;
  final int disabled;
  final int orders;
  final int pending;
  final int completed;

  factory AdminSummary.fromJson(Map<String, dynamic> json) => AdminSummary(
        clients: readInt(json, 'clientes'),
        providers: readInt(json, 'prestadores'),
        disabled: readInt(json, 'desativados'),
        orders: readInt(json, 'pedidos'),
        pending: readInt(json, 'pendentes'),
        completed: readInt(json, 'concluidos'),
      );
}
