import '../../core/utils/json_reader.dart';
import 'order_model.dart';

/// Painel do prestador (/api/prestador/painel).
class ProviderPanel {
  const ProviderPanel({
    required this.newOrders,
    required this.monthEarnings,
    required this.upcoming,
    this.rating,
    this.pending = const [],
    this.weekEarnings = 0,
    this.weekServices = 0,
  });

  final int newOrders;
  final double? rating;
  final double monthEarnings;

  /// Confirmados (próximos atendimentos).
  final List<OrderModel> upcoming;

  /// Solicitações novas, esperando Aceitar/Recusar.
  final List<OrderModel> pending;
  final double weekEarnings;
  final int weekServices;

  factory ProviderPanel.fromJson(Map<String, dynamic> json) {
    final r = readMap(json, 'resumo');
    return ProviderPanel(
      newOrders: readInt(r, 'pedidosNovos'),
      rating: readNumOrNull(r, 'avaliacao'),
      monthEarnings: readNum(r, 'ganhosMes'),
      upcoming: readList(json, 'proximos', OrderModel.fromJson),
      pending: json['pendentes'] is List ? readList(json, 'pendentes', OrderModel.fromJson) : const [],
      weekEarnings: readNumOrNull(r, 'ganhosSemana') ?? 0,
      weekServices: readNumOrNull(r, 'servicosSemana')?.round() ?? 0,
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
