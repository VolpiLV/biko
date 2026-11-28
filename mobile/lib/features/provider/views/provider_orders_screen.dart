import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/order_model.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../client/views/client_agenda_tab.dart';
import '../../home/app_navigator.dart';
import '../viewmodels/provider_view_models.dart';

/// "Meus Pedidos" do prestador (atalho "Ver todas" do Início).
class ProviderOrdersScreen extends StatelessWidget {
  const ProviderOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => OrdersAgendaViewModel(context.read<OrderService>())..load(),
        child: Scaffold(appBar: bikoAppBar(context, 'Meus Pedidos'), body: const OrdersFilterList()),
      );
}

/// Lista de pedidos com chips de status. Usada no "Ver todas" do prestador e na aba Pedidos do admin.
class OrdersFilterList extends StatelessWidget {
  const OrdersFilterList({super.key, this.title, this.adminView = false});

  final String? title;
  final bool adminView;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersAgendaViewModel>();
    final f = vm.filter;
    return BikoPage(
      onRefresh: vm.load,
      children: [
        if (title case final t?) PageTitle(t) else const SizedBox(height: 8),
        ChipRow(
          children: [
            BikoChip(label: 'Todos', selected: f == null, onTap: () => vm.setFilter(null)),
            for (final s in OrderStatus.values) BikoChip(label: s.label, selected: f == s, onTap: () => vm.setFilter(s)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text('${vm.total} pedido(s)', style: const TextStyle(fontSize: 12.5)),
        ),
        if (vm.loading && !vm.loaded)
          const SizedBox(height: 240, child: LoadingView())
        else if (vm.error case final msg? when !vm.loaded)
          SizedBox(height: 280, child: ErrorView(message: msg, onRetry: vm.load))
        else if (vm.orders.isEmpty)
          const EmptyText('Nenhum pedido.')
        else
          for (final o in vm.orders)
            AgendaOrderCard(
              order: o,
              adminView: adminView,
              onTap: () async {
                await openOrder(context, o.id);
                await vm.load();
              },
            ),
      ],
    );
  }
}
