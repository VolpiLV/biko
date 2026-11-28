import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/utils/launchers.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../home/app_navigator.dart';
import '../../orders/order_actions.dart';
import '../../orders/viewmodels/orders_view_model.dart';

/// "Serviço em Andamento" (tela "Prest 6"): linha do tempo, mapa ilustrativo e as ações
/// da agenda elástica (iniciar/antecipar, avisar atraso, prorrogar, concluir).
class ServiceProgressScreen extends StatelessWidget {
  const ServiceProgressScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => OrderDetailViewModel(context.read<OrderService>(), orderId)..load(),
        child: const _ProgressView(),
      );
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderDetailViewModel>();
    final o = vm.order;
    return Scaffold(
      appBar: bikoAppBar(context, 'Serviço em Andamento', left: true),
      body: o == null
          ? (vm.loadingOrder ? const LoadingView() : ErrorView(message: vm.loadError ?? 'Pedido não encontrado.', onRetry: vm.load))
          : _ProgressBody(order: o, onChanged: vm.load),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.order, required this.onChanged});

  final OrderModel order;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = order;
    OrderEvent? last(String kind) => o.history.where((h) => h.kind == kind).lastOrNull;
    final conf = last('confirmado'), ini = last('iniciado'), fim = last('concluido');
    final step = o.status == OrderStatus.concluido ? 5 : o.inProgress ? 3 : o.status == OrderStatus.confirmado ? 2 : 1;
    final paid = o.isPaid;

    Future<void> act(OrderAction a) async {
      if (await runOrderAction(context, o, a) != null) await onChanged();
    }

    final actions = <Widget>[
      if (o.status == OrderStatus.pendente)
        ButtonPair(
          left: BikoButton(label: 'Recusar', style: BikoButtonStyle.outline, onPressed: () => act(OrderAction.recusar)),
          right: BikoButton(label: 'Aceitar', onPressed: () => act(OrderAction.confirmar)),
        )
      else if (o.status == OrderStatus.confirmado && !o.inProgress) ...[
        BikoButton(
          label: 'Cheguei ao Local / Iniciar',
          icon: Icons.location_on_outlined,
          style: BikoButtonStyle.green,
          onPressed: () => act(OrderAction.iniciar),
        ),
        if (o.actions.contains(OrderAction.atrasar))
          BikoButton(label: '⏰ Avisar atraso / imprevisto', style: BikoButtonStyle.light, onPressed: () => act(OrderAction.atrasar)),
      ] else if (o.inProgress) ...[
        BikoButton(
          label: 'Concluir Serviço',
          icon: Icons.check_circle_outline,
          style: BikoButtonStyle.green,
          onPressed: () => act(OrderAction.concluir),
        ),
        if (o.actions.contains(OrderAction.estender))
          BikoButton(label: '⏳ Preciso de mais tempo', style: BikoButtonStyle.light, onPressed: () => act(OrderAction.estender)),
      ] else
        NoticeBox(
          margin: EdgeInsets.zero,
          tone: o.status == OrderStatus.concluido ? NoticeTone.warn : NoticeTone.off,
          leading: Text(o.status == OrderStatus.concluido ? '🏁' : 'ℹ️'),
          child: Text(
            'Pedido ${o.status.label.toLowerCase()}${o.realDurationMin != null ? ' · tempo real ${Fmt.duration(o.realDurationMin!)}' : ''}.',
          ),
        ),
    ];

    return BikoPage(
      onRefresh: onChanged,
      children: [
        const SizedBox(height: 10),
        BikoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardTitle('Status do Atendimento'),
              _Step(
                n: 1,
                step: step,
                title: 'Chamado Aceito',
                sub: conf != null ? '${Fmt.time(conf.createdAt)} - ${Fmt.dayOf(conf.createdAt)}' : 'Aguardando você aceitar',
              ),
              _Step(
                n: 2,
                step: step,
                title: o.status == OrderStatus.confirmado && !o.inProgress ? 'A Caminho do Cliente' : 'Horário agendado',
                sub: '${Fmt.dayLabel(o.date)} às ${o.time}${o.delayMin > 0 ? ' (adiado +${o.delayMin} min)' : ''}',
              ),
              _Step(
                n: 3,
                step: step,
                title: 'Serviço em Realização',
                sub: ini != null
                    ? 'Iniciado às ${Fmt.time(ini.createdAt)} · término previsto ${o.endTime}${o.extendedMin > 0 ? ' (+${o.extendedMin} min)' : ''}'
                    : null,
              ),
              _Step(
                n: 4,
                step: step,
                last: true,
                title: 'Concluído & Pagamento',
                sub: fim != null
                    ? '${Fmt.time(fim.createdAt)}${paid ? ' · pagamento liberado' : ''}'
                    : paid
                        ? 'Pagamento já garantido'
                        : null,
              ),
            ],
          ),
        ),
        BikoCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 150,
                color: c.neutralSoft,
                child: Stack(
                  children: [
                    Center(child: Icon(Icons.location_on, size: 54, color: c.blue)),
                    const Positioned(right: 12, bottom: 12, child: Tag('Mapa ilustrativo')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.address, style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${o.serviceTitle} · ${Fmt.duration(o.durationMin)}',
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ),
                        LinkText('Ver rota ↗', onTap: () => openRoute(context, o.address)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                    Text(
                      paid ? 'Pagamento Garantido pelo Biko' : 'Pagamento ainda não feito',
                      style: TextStyle(color: paid ? c.green : c.muted, fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (o.client.phone case final p?) ...[
                RoundIconButton(icon: Icons.phone_outlined, tooltip: 'Ligar ($p)', onPressed: () => callPhone(context, p)),
                const SizedBox(width: 6),
              ],
              RoundIconButton(icon: Icons.chat_bubble_outline, tooltip: 'Chat', onPressed: () => openChat(context, o.client.id)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 10), actions[i]],
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.step, required this.title, this.sub, this.last = false});

  final int n;
  final int step;
  final String title;
  final String? sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final done = step > n, now = step == n;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? c.green : now ? c.blue : c.line,
                    boxShadow: now ? [BoxShadow(color: c.blueSoft, spreadRadius: 4)] : null,
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: c.line)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: done ? c.ink : now ? c.blue : c.muted2),
                  ),
                  if (sub case final s?) Text(s, style: TextStyle(color: c.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
