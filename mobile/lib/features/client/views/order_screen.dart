import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/order_service.dart';
import '../../../data/remote/payment_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../../orders/order_actions.dart';
import '../../orders/viewmodels/orders_view_model.dart';
import '../../payments/views/receipt_sheet.dart';
import 'payment_screen.dart';

/// Detalhe do pedido para o cliente e o admin: horário, endereço, valores, pagamento,
/// avaliação, histórico e as ações permitidas (pagar, avaliar, cancelar).
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => OrderDetailViewModel(context.read<OrderService>(), orderId)..load(),
        child: const _OrderView(),
      );
}

class _OrderView extends StatelessWidget {
  const _OrderView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderDetailViewModel>();
    final o = vm.order;
    return Scaffold(
      appBar: bikoAppBar(context, 'Detalhes do Pedido'),
      body: o == null
          ? (vm.loadingOrder ? const LoadingView() : ErrorView(message: vm.loadError ?? 'Pedido não encontrado.', onRetry: vm.load))
          : OrderDetailBody(order: o, onChanged: vm.load),
    );
  }
}

/// Corpo do detalhe (também usado pelo prestador quando abre um pedido que não é dele).
class OrderDetailBody extends StatelessWidget {
  const OrderDetailBody({super.key, required this.order, required this.onChanged});

  final OrderModel order;
  final Future<void> Function() onChanged;

  Future<void> _receipt(BuildContext context) async {
    try {
      final charge = await context.read<PaymentService>().ofOrder(order.id);
      if (!context.mounted) return;
      if (charge == null) {
        showAppSnackBar(context, 'Ainda não há pagamento neste pedido.');
        return;
      }
      final seller = context.read<SessionViewModel>().user?.role != UserRole.cliente;
      await showReceiptSheet(context, charge, seller: seller);
    } on AppException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = order;
    final user = context.read<SessionViewModel>().user;
    final isClient = user?.id == o.client.id;
    final isAdmin = user?.role == UserRole.admin;
    final other = isClient ? o.provider : o.client;
    final pay = o.payment;

    return BikoPage(
      onRefresh: onChanged,
      children: [
        const SizedBox(height: 10),
        BikoCard(
          child: Row(
            children: [
              BikoAvatar(name: other.name, photoUrl: other.photoUrl, size: 60, square: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(other.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.ink)),
                    Text(o.serviceTitle, style: TextStyle(color: c.muted, fontSize: 13.5)),
                    const SizedBox(height: 4),
                    OrderStatusTag(o, clientView: true),
                  ],
                ),
              ),
              if (!isAdmin) RoundIconButton(icon: Icons.chat_bubble_outline, tooltip: 'Conversar', onPressed: () => openChat(context, other.id)),
            ],
          ),
        ),
        if (o.delayMin > 0)
          NoticeBox(
            leading: const Text('⏰'),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Aviso de atraso:', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: ' o horário era ${o.originalTime ?? '--'} e agora é ${o.time} (+${o.delayMin} min).\nMotivo: ${o.delayReason ?? '—'}.',
                  ),
                ],
              ),
            ),
          ),
        BikoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconLine(
                Icons.schedule,
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${Fmt.fullDay(o.date)} · '),
                  TextSpan(text: '${o.time}–${o.endTime}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
              ),
              IconLine(Icons.location_on_outlined, Text(o.address)),
              if (other.phone case final p?) IconLine(Icons.phone_outlined, Text(p)),
              if (o.notes case final n? when n.isNotEmpty) ...[
                const ThinDivider(),
                Text('“$n”', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ],
          ),
        ),
        BikoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValue('Serviço', Fmt.brl(o.price)),
              KeyValue('Taxa de Proteção Biko', Fmt.brl(o.protectionFee)),
              if (pay != null && pay.status != PaymentStatus.recusado)
                KeyValue(
                  'Pagamento',
                  '',
                  valueWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pay.status == PaymentStatus.pago ? '✓ Pago' : pay.status.label,
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.ink),
                      ),
                      LinkText('Ver comprovante', onTap: () => _receipt(context)),
                    ],
                  ),
                ),
              if (o.statusReason case final r? when r.isNotEmpty) KeyValue('Motivo', r),
            ],
          ),
        ),
        if (o.review case final r?)
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle('Sua avaliação'),
                Text('${'★' * r.stars}${'☆' * (5 - r.stars)}', style: const TextStyle(color: AppColors.star, fontSize: 20)),
                if (r.comment case final cm? when cm.isNotEmpty) Text(cm, style: TextStyle(color: c.muted)),
              ],
            ),
          ),
        HistoryCard(order: o),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (o.canPay && isClient) ...[
                BikoButton(
                  label: 'Pagar ${Fmt.brl(o.total)}',
                  icon: Icons.lock_outline,
                  style: BikoButtonStyle.green,
                  onPressed: () async {
                    await pushScreen<void>(context, PaymentScreen(orderId: o.id));
                    await onChanged();
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (o.canReview) ...[
                BikoButton(
                  label: '⭐ Avaliar o serviço',
                  style: BikoButtonStyle.orange,
                  onPressed: () async {
                    if (await showRateSheet(context, o)) await onChanged();
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (o.actions.contains(OrderAction.cancelar))
                BikoButton(
                  label: OrderAction.cancelar.label,
                  style: BikoButtonStyle.outline,
                  foreground: c.danger,
                  onPressed: () async {
                    if (await runOrderAction(context, o, OrderAction.cancelar) != null) await onChanged();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Histórico" do pedido: cada mudança, quem fez, quando e o motivo.
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    if (order.history.isEmpty) return const SizedBox.shrink();
    return BikoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('Histórico'),
          for (final h in order.history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: h.label, style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                              TextSpan(text: '  ${Fmt.dateTime(h.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12)),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${h.actorName ?? 'Sistema'}${h.note != null && h.note!.isNotEmpty ? ' — ${h.note}' : ''}',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Como foi o serviço?" (1 a 5 estrelas + comentário). Retorna true se enviou.
Future<bool> showRateSheet(BuildContext context, OrderModel order) async {
  final ok = await showBikoSheet<bool>(context, (_) => _RateSheet(order: order));
  return ok ?? false;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.order});

  final OrderModel order;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final _comment = TextEditingController();
  int _stars = 5;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await context.read<OrderService>().review(widget.order.id, stars: _stars, comment: _comment.text);
      if (!mounted) return;
      showAppSnackBar(context, 'Obrigado pela avaliação!');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Como foi o serviço?'),
        Text('${widget.order.serviceTitle} com ${widget.order.provider.name}', style: TextStyle(color: c.muted)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 1; n <= 5; n++)
              IconButton(
                tooltip: '$n estrela${n > 1 ? 's' : ''}',
                iconSize: 38,
                onPressed: () => setState(() => _stars = n),
                icon: Icon(Icons.star_rounded, color: n <= _stars ? AppColors.star : c.line),
              ),
          ],
        ),
        TextField(
          controller: _comment,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Conte como foi (opcional)', counterText: ''),
        ),
        const SizedBox(height: 18),
        ButtonPair(
          left: BikoButton(label: 'Agora não', style: BikoButtonStyle.light, onPressed: () => Navigator.pop(context, false)),
          right: BikoButton(label: 'Enviar avaliação', loading: _sending, onPressed: _send),
        ),
      ],
    );
  }
}
