import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/viewmodels/orders_view_model.dart';
import '../../orders/views/order_detail_sheet.dart';
import '../../orders/widgets/order_card.dart';
import '../../search/viewmodels/search_view_model.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../viewmodels/home_navigation.dart';

/// Aba "Início".
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    if (vm.loading && !vm.hasData) return const LoadingView(message: 'Carregando...');
    if (vm.errorMessage case final msg? when !vm.hasData) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorView(message: msg, onRetry: vm.load),
      );
    }
    return TabPage(
      onRefresh: vm.load,
      children: switch (vm.role) {
        UserRole.cliente => _clientHome(context, vm),
        UserRole.prestador => _providerHome(context, vm),
        UserRole.admin => _adminHome(context, vm),
      },
    );
  }

  List<Widget> _clientHome(BuildContext context, DashboardViewModel vm) {
    final categories = vm.categories;
    final theme = Theme.of(context);
    final nav = context.read<HomeNavigation>();
    final search = context.read<SearchViewModel>();
    return [
      if (vm.notices.isNotEmpty) ...[
        const SectionTitle('Avisos'),
        for (final o in vm.notices) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${o.provider.name} avisou um atraso em "${o.serviceTitle}": ${Fmt.dateBR(o.date)}, '
              'era ${o.originalTime ?? '--'} e agora é ${o.time}.\nMotivo: ${o.delayReason ?? 'imprevisto'}.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          OrderCard(
            order: o,
            viewerRole: UserRole.cliente,
            onTap: () async {
              if (await showOrderDetail(context, o.id)) await vm.load();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
      Card(
        color: theme.colorScheme.primary,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => nav.goTo(AppTab.search),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precisa de um profissional?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Encontre prestadores disponíveis e agende em poucos toques.',
                        style: TextStyle(color: theme.colorScheme.onPrimary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimary),
              ],
            ),
          ),
        ),
      ),
      const SectionTitle('Categorias populares'),
      for (final c in categories)
        Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Icon(CategoryModel.iconFor(c.name)),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(c.description),
            trailing: Text('${c.total} serviço(s)', style: theme.textTheme.bodySmall),
            onTap: () {
              search.setCategory(c.name, reload: false);
              nav.goTo(AppTab.search);
            },
          ),
        ),
    ];
  }

  List<Widget> _providerHome(BuildContext context, DashboardViewModel vm) {
    final panel = vm.panel!;
    final nav = context.read<HomeNavigation>();
    final orders = context.read<OrdersViewModel>();
    return [
      StatRow(
        tiles: [
          StatTile(value: '${panel.newOrders}', label: 'Pedidos novos'),
          StatTile(value: panel.rating?.toStringAsFixed(1) ?? '—', label: 'Avaliação'),
          StatTile(value: Fmt.brl(panel.monthEarnings), label: 'Ganhos no mês'),
        ],
      ),
      if (panel.newOrders > 0)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: AppButton(
            label: 'Ver ${panel.newOrders} pedido(s) novo(s)',
            onPressed: () {
              orders.setFilter(OrderStatus.pendente, reload: false);
              nav.goTo(AppTab.orders);
            },
          ),
        ),
      const SectionTitle('Próximos atendimentos'),
      if (panel.upcoming.isEmpty)
        const EmptyView(icon: Icons.event_available_outlined, message: 'Nenhum atendimento confirmado por enquanto.')
      else
        for (final o in panel.upcoming)
          OrderCard(
            order: o,
            viewerRole: UserRole.prestador,
            onTap: () async {
              if (await showOrderDetail(context, o.id)) await vm.load();
            },
          ),
    ];
  }

  List<Widget> _adminHome(BuildContext context, DashboardViewModel vm) {
    final s = vm.summary!;
    return [
      StatRow(
        tiles: [
          StatTile(value: '${s.clients}', label: 'Clientes'),
          StatTile(value: '${s.providers}', label: 'Prestadores'),
          StatTile(value: '${s.disabled}', label: 'Desativados'),
        ],
      ),
      StatRow(
        tiles: [
          StatTile(value: '${s.orders}', label: 'Pedidos'),
          StatTile(value: '${s.pending}', label: 'Pendentes'),
          StatTile(value: '${s.completed}', label: 'Concluídos'),
        ],
      ),
      const EmptyView(
        icon: Icons.admin_panel_settings_outlined,
        message: 'Use a aba Usuários para gerenciar contas e a aba Pedidos para acompanhar os agendamentos.',
      ),
    ];
  }
}
