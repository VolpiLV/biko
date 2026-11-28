import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/order_model.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../client/views/order_screen.dart';
import '../../home/app_navigator.dart';
import '../../orders/order_actions.dart';
import '../../orders/viewmodels/orders_view_model.dart';
import 'service_progress_screen.dart';

/// "Detalhes da Solicitação" (tela "Prest 4"): cliente, serviço, data, local e pagamento.
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => OrderDetailViewModel(context.read<OrderService>(), orderId)..load(),
        child: const _RequestView(),
      );
}

class _RequestView extends StatelessWidget {
  const _RequestView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderDetailViewModel>();
    final o = vm.order;
    final me = context.read<SessionViewModel>().user;
    if (o == null) {
      return Scaffold(
        appBar: bikoAppBar(context, 'Detalhes da Solicitação', left: true),
        body: vm.loadingOrder ? const LoadingView() : ErrorView(message: vm.loadError ?? 'Pedido não encontrado.', onRetry: vm.load),
      );
    }
    // Pedido que não é dele (não deveria acontecer): mostra o detalhe comum.
    if (me?.id != o.provider.id) {
      return Scaffold(appBar: bikoAppBar(context, 'Detalhes do Pedido'), body: OrderDetailBody(order: o, onChanged: vm.load));
    }
    return Scaffold(
      appBar: bikoAppBar(context, 'Detalhes da Solicitação', left: true),
      body: _RequestBody(order: o, onChanged: vm.load),
    );
  }
}

class _RequestBody extends StatelessWidget {
  const _RequestBody({required this.order, required this.onChanged});

  final OrderModel order;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = order;
    final since = o.clientSince;
    final emoji = CategoryStyle.all.where((s) => s.name == o.category).map((s) => '${s.emoji} ').firstOrNull ?? '';

    Future<void> act(OrderAction a) async {
      final updated = await runOrderAction(context, o, a);
      if (updated == null || !context.mounted) return;
      if (a == OrderAction.confirmar) {
        await replaceScreen<void>(context, ServiceProgressScreen(orderId: o.id));
      } else {
        await onChanged();
      }
    }

    final payTag = o.isPaid
        ? const Tag('✓ Garantido pelo Biko', tone: TagTone.green)
        : o.payment?.status == PaymentStatus.estornado
            ? const Tag('Estornado', tone: TagTone.purple)
            : const Tag('Ainda não pago', tone: TagTone.gray);

    return BikoPage(
      onRefresh: onChanged,
      children: [
        const SizedBox(height: 10),
        BikoCard(
          child: Row(
            children: [
              BikoAvatar(name: o.client.name, photoUrl: o.client.photoUrl, size: 60, ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.client.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.ink)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [Text('Pedido #${o.id} ·', style: TextStyle(color: c.muted, fontSize: 12.5)), OrderStatusTag(o)],
                    ),
                    const SizedBox(height: 6),
                    Tag(
                      'Cliente Biko${since != null ? ' desde ${Fmt.months[since.month - 1].substring(0, 3).toLowerCase()}/${since.year}' : ''}',
                      tone: TagTone.green,
                    ),
                  ],
                ),
              ),
              RoundIconButton(icon: Icons.chat_bubble_outline, tooltip: 'Conversar', onPressed: () => openChat(context, o.client.id)),
            ],
          ),
        ),
        BikoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SERVIÇO SOLICITADO',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.muted),
              ),
              const SizedBox(height: 8),
              Text('$emoji${o.serviceTitle}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${o.category} · ${Fmt.duration(o.durationMin)} · '),
                  TextSpan(text: Fmt.brl(o.price), style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
                ]),
                style: TextStyle(color: c.muted, fontSize: 12.5),
              ),
              if (o.notes case final n? when n.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text('“$n”', style: const TextStyle(height: 1.5))),
            ],
          ),
        ),
        if (o.delayMin > 0)
          NoticeBox(
            leading: const Text('⏰'),
            child: Text('Horário adiado: era ${o.originalTime ?? '--'}, agora ${o.time}. Motivo: ${o.delayReason ?? '—'}.'),
          ),
        BikoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconLine(
                Icons.schedule,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data e Horário', style: TextStyle(color: c.muted, fontSize: 12)),
                    Text('${Fmt.fullDay(o.date)} às ${o.time}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              IconLine(
                Icons.location_on_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Localização do Serviço', style: TextStyle(color: c.muted, fontSize: 12)),
                    Text(o.address, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (o.client.phone case final p?) IconLine(Icons.phone_outlined, Text(p)),
              const ThinDivider(),
              Row(children: [Expanded(child: Text('Pagamento', style: TextStyle(color: c.muted, fontSize: 12.5))), payTag]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (o.status == OrderStatus.pendente)
                ButtonPair(
                  left: BikoButton(label: 'Recusar', style: BikoButtonStyle.outline, onPressed: () => act(OrderAction.recusar)),
                  right: BikoButton(label: 'Aceitar', onPressed: () => act(OrderAction.confirmar)),
                ),
              if (o.status == OrderStatus.confirmado)
                BikoButton(
                  label: o.inProgress ? 'Ver atendimento em andamento' : 'Ir para o atendimento',
                  icon: Icons.navigation_outlined,
                  style: BikoButtonStyle.green,
                  onPressed: () async {
                    await pushScreen<void>(context, ServiceProgressScreen(orderId: o.id));
                    await onChanged();
                  },
                ),
              if (o.actions.contains(OrderAction.cancelar)) ...[
                const SizedBox(height: 10),
                BikoButton(
                  label: 'Cancelar pedido',
                  style: BikoButtonStyle.outline,
                  foreground: c.danger,
                  onPressed: () => act(OrderAction.cancelar),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        HistoryCard(order: o),
      ],
    );
  }
}
