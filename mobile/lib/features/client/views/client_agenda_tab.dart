import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../payments/views/sales_tab.dart';
import '../../provider/viewmodels/provider_view_models.dart';

/// Agenda do cliente: próximos serviços, histórico e atalho para os pagamentos.
class ClientAgendaTab extends StatefulWidget {
  const ClientAgendaTab({super.key});

  @override
  State<ClientAgendaTab> createState() => _ClientAgendaTabState();
}

class _ClientAgendaTabState extends State<ClientAgendaTab> {
  bool _history = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OrdersAgendaViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersAgendaViewModel>();
    final list = _history ? vm.past : vm.upcoming;
    return BikoPage(
      onRefresh: vm.load,
      children: [
        const PageTitle('Sua Agenda', trailing: NotificationBell()),
        ChipRow(
          children: [
            BikoChip(label: 'Próximos (${vm.upcoming.length})', selected: !_history, onTap: () => setState(() => _history = false)),
            BikoChip(label: 'Histórico (${vm.past.length})', selected: _history, onTap: () => setState(() => _history = true)),
            BikoChip(
              label: 'Pagamentos',
              icon: Icons.receipt_long_outlined,
              onTap: () => pushScreen<void>(context, const PaymentsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (vm.loading && !vm.loaded)
          const SizedBox(height: 240, child: LoadingView())
        else if (vm.error case final msg? when !vm.loaded)
          SizedBox(height: 280, child: ErrorView(message: msg, onRetry: vm.load))
        else if (list.isEmpty)
          EmptyText(_history ? 'Nada no histórico ainda.' : 'Nenhum serviço agendado.\nUse a aba Buscar para encontrar um profissional.')
        else
          for (final o in list)
            AgendaOrderCard(
              order: o,
              onTap: () async {
                await openOrder(context, o.id);
                await vm.load();
              },
            ),
      ],
    );
  }
}

/// Cartão de pedido com faixa colorida (`.agenda-card`): quando, status, serviço e a outra pessoa.
class AgendaOrderCard extends StatelessWidget {
  const AgendaOrderCard({super.key, required this.order, required this.onTap, this.adminView = false});

  final OrderModel order;
  final VoidCallback onTap;

  /// Admin vê "Cliente → Profissional".
  final bool adminView;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = order;
    final role = context.select<SessionViewModel, UserRole?>((s) => s.user?.role);
    final (accent, label, labelColor) = o.inProgress
        ? (c.blue, 'EM ANDAMENTO', c.blue)
        : switch (o.status) {
            OrderStatus.confirmado => (c.green, 'CONFIRMADO', c.green),
            OrderStatus.pendente => (c.orange, 'AGUARDANDO', c.orangeText),
            _ => (c.muted2, o.status.label.toUpperCase(), c.muted),
          };
    final who = adminView
        ? '${o.client.name} → ${o.provider.name}'
        : role == UserRole.cliente
            ? 'Profissional: ${o.provider.name}'
            : 'Cliente: ${o.client.name}';
    return BikoCard(
      accent: accent,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Fmt.dayLabel(o.date).toUpperCase()} · ${o.time} - $label',
                  style: TextStyle(color: labelColor, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.3),
                ),
              ),
              if (o.isPaid)
                const Tag('✓ Pago', tone: TagTone.green)
              else if (o.canPay)
                const Tag('A pagar', tone: TagTone.orange),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.serviceTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 2),
          Text(who, style: TextStyle(color: c.muted, fontSize: 12.5)),
          if (o.delayMin > 0 && o.originalTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('⏰ Horário mudou: era ${o.originalTime}', style: const TextStyle(color: Color(0xFFC2410C), fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
