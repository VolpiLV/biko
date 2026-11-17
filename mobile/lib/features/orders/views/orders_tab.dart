import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../viewmodels/orders_view_model.dart';
import '../widgets/order_card.dart';
import 'order_detail_sheet.dart';

/// Aba "Pedidos" (cliente, prestador e admin).
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key, required this.role});

  final UserRole role;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  @override
  void initState() {
    super.initState();
    // Sempre recarrega ao abrir a aba (pode ter pedido novo).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrdersViewModel>().refresh();
    });
  }

  String get _emptyMessage => switch (widget.role) {
        UserRole.cliente => 'Você ainda não fez nenhum pedido.\nUse a aba Buscar para encontrar um profissional.',
        UserRole.prestador => 'Você ainda não tem pedidos.\nQuando um cliente agendar, ele aparecerá aqui.',
        UserRole.admin => 'Nenhum pedido registrado.',
      };

  Future<void> _open(OrderModel order) async {
    final vm = context.read<OrdersViewModel>();
    final changed = await showOrderDetail(context, order.id);
    if (changed) await vm.refresh();
  }

  Future<void> _loadMore() async {
    final vm = context.read<OrdersViewModel>();
    await vm.loadMore();
    if (!mounted) return;
    if (vm.takeLoadMoreError() case final msg?) showAppSnackBar(context, msg, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersViewModel>();
    return TabPage(
      onRefresh: vm.refresh,
      children: [
        DropdownButtonFormField<OrderStatus?>(
          key: ValueKey(vm.filter), // filtro pode vir de outro atalho (ex.: painel do prestador)
          initialValue: vm.filter,
          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.filter_list)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os status')),
            for (final s in OrderStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: vm.setFilter,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vm.loading && !vm.loaded)
          const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ErrorView(message: msg, onRetry: vm.refresh),
          )
        else ...[
          if (vm.loading) const LinearProgressIndicator(),
          CountLabel('${vm.total} pedido(s)'),
          if (vm.items.isEmpty)
            EmptyView(
              icon: Icons.event_busy_outlined,
              message: vm.filter != null ? 'Nenhum pedido com esse status.' : _emptyMessage,
            )
          else
            for (final order in vm.items)
              OrderCard(order: order, viewerRole: widget.role, onTap: () => _open(order)),
          LoadMoreButton(visible: vm.hasMore, loading: vm.loadingMore, onPressed: _loadMore),
        ],
      ],
    );
  }
}
