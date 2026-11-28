import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../shared/utils/launchers.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../home/app_navigator.dart';
import '../viewmodels/provider_view_models.dart';
import 'my_services_screen.dart';

/// "Sua Agenda" do prestador (tela "Prest 5"): dias, compromissos e horários livres.
class ProviderAgendaTab extends StatefulWidget {
  const ProviderAgendaTab({super.key});

  @override
  State<ProviderAgendaTab> createState() => _ProviderAgendaTabState();
}

class _ProviderAgendaTabState extends State<ProviderAgendaTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OrdersAgendaViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersAgendaViewModel>();
    final c = context.bikoColors;
    final day = vm.day;
    final label = Fmt.dayLabel(Fmt.ymd(day));
    void services() => pushScreen<void>(context, const MyServicesScreen());

    return BikoPage(
      onRefresh: vm.load,
      children: [
        PageTitle(
          'Sua Agenda',
          trailing: IconButton(tooltip: 'Meus serviços', onPressed: services, icon: Icon(Icons.tune, color: c.blue)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${Fmt.months[day.month - 1]} ${day.year}', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                  ),
                  LinkText('Gerenciar Serviços', onTap: services),
                ],
              ),
              const SizedBox(height: 12),
              DayStrip(days: vm.days, selected: day, onSelect: vm.selectDay, marked: vm.markedDays, numberFirst: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Text(
            'COMPROMISSOS DE ${label == 'Hoje' ? 'HOJE' : label.toUpperCase()}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.muted),
          ),
        ),
        if (vm.loading && !vm.loaded)
          const SizedBox(height: 200, child: LoadingView())
        else if (vm.error case final msg? when !vm.loaded)
          SizedBox(height: 240, child: ErrorView(message: msg, onRetry: vm.load))
        else ...[
          if (vm.ofDay.isEmpty) const EmptyText('Nenhum compromisso neste dia.'),
          for (final o in vm.ofDay) _AppointmentCard(order: o, onChanged: vm.load),
          for (final (from, to) in vm.freeSlots.take(3))
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.muted2.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 18, color: c.muted),
                  const SizedBox(width: 8),
                  Text('Horário Livre das $from às $to', style: TextStyle(color: c.muted, fontSize: 13.5)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.order, required this.onChanged});

  final OrderModel order;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = order;
    final (accent, label, color) = o.inProgress
        ? (c.blue, 'EM ANDAMENTO', c.blue)
        : switch (o.status) {
            OrderStatus.confirmado => (c.green, 'CONFIRMADO', c.green),
            OrderStatus.pendente => (c.orange, 'AGUARDANDO VOCÊ', c.orangeText),
            _ => (c.muted2, 'CONCLUÍDO', c.muted),
          };
    return BikoCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${o.time} - $label',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.3),
                ),
              ),
              IconButton(
                tooltip: 'Detalhes',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await openOrder(context, o.id);
                  await onChanged();
                },
                icon: Icon(Icons.more_vert, color: c.muted),
              ),
            ],
          ),
          Text(o.serviceTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
          Text('Cliente: ${o.client.name}', style: TextStyle(color: c.muted, fontSize: 12.5)),
          if (o.status != OrderStatus.concluido) ...[
            const SizedBox(height: 12),
            ButtonPair(
              left: BikoButton(label: 'Ver Rota', icon: Icons.navigation_outlined, small: true, onPressed: () => openRoute(context, o.address)),
              right: BikoButton(
                label: 'Chat',
                icon: Icons.chat_bubble_outline,
                small: true,
                style: BikoButtonStyle.outline,
                onPressed: () => openChat(context, o.client.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
