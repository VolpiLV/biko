import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/biko_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order_model.dart';
import '../../data/remote/order_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/biko_ui.dart';
import '../auth/viewmodels/session_view_model.dart';
import '../notifications/viewmodels/notifications_view_model.dart';

/// Executa uma ação do pedido. Pede o motivo (e os minutos, para atraso/prorrogação)
/// quando precisa e confirma a antecipação do atendimento. Devolve o pedido
/// atualizado, ou null se a pessoa desistiu ou deu erro (o erro aparece no rodapé).
Future<OrderModel?> runOrderAction(BuildContext context, OrderModel order, OrderAction action) async {
  final service = context.read<OrderService>();
  final userId = context.read<SessionViewModel>().user?.id;
  final notifications = context.read<NotificationsViewModel?>();
  String? reason;
  int? minutes;

  const needsReason = {OrderAction.recusar, OrderAction.cancelar, OrderAction.atrasar, OrderAction.estender};
  if (needsReason.contains(action)) {
    final r = await showBikoSheet<_Reason>(
      context,
      (_) => _ReasonSheet(order: order, action: action, optional: action == OrderAction.cancelar && userId == order.client.id),
    );
    if (r == null) return null;
    reason = r.text;
    minutes = r.minutes;
  }

  if (action == OrderAction.iniciar && order.isEarlyStart(DateTime.now())) {
    if (!context.mounted) return null;
    final ok = await confirmSheet(
      context,
      title: 'Antecipar o atendimento?',
      message: 'Está marcado para ${Fmt.dateBR(order.date)} às ${order.time}. Se iniciar agora, o pedido passa a '
          'começar neste momento (${Fmt.duration(order.durationMin)} de serviço), o horário antigo fica livre '
          'na agenda e o cliente é avisado.',
      confirmLabel: 'Iniciar agora',
    );
    if (!ok) return null;
  }

  try {
    final updated = await service.changeStatus(order.id, action, reason: reason, minutes: minutes);
    if (context.mounted) showAppSnackBar(context, action.doneMessage);
    if (notifications != null) unawaited(notifications.refreshCount());
    return updated;
  } on AppException catch (e) {
    if (context.mounted) showAppSnackBar(context, e.message, error: true);
    return null;
  }
}

/// Folha de confirmação com "Voltar" e a ação. Retorna true se confirmou.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showBikoSheet<bool>(
    context,
    (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(title),
        Text(message, style: TextStyle(color: sheet.bikoColors.muted, height: 1.5)),
        const SizedBox(height: 18),
        ButtonPair(
          left: BikoButton(label: 'Voltar', style: BikoButtonStyle.light, onPressed: () => Navigator.pop(sheet, false)),
          right: BikoButton(
            label: confirmLabel,
            style: destructive ? BikoButtonStyle.danger : BikoButtonStyle.primary,
            onPressed: () => Navigator.pop(sheet, true),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _Reason {
  const _Reason(this.text, this.minutes);

  final String text;
  final int? minutes;
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.order, required this.action, required this.optional});

  final OrderModel order;
  final OrderAction action;
  final bool optional;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _text = TextEditingController();
  int _minutes = 15;
  String? _error;

  bool get _timed => widget.action == OrderAction.atrasar || widget.action == OrderAction.estender;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _ok() {
    final t = _text.text.trim();
    if (!widget.optional && t.length < 3) {
      setState(() => _error = 'Informe o motivo (mín. 3 caracteres).');
      return;
    }
    Navigator.pop(context, _Reason(t, _timed ? _minutes : null));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final a = widget.action;
    final title = switch (a) {
      OrderAction.recusar => 'Recusar pedido',
      OrderAction.cancelar => 'Cancelar pedido',
      OrderAction.atrasar => 'Avisar atraso / imprevisto',
      _ => 'Preciso de mais tempo',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(title),
        if (_timed) ...[
          FieldLabel(a == OrderAction.atrasar ? 'Quanto vai atrasar? (hoje o horário é ${widget.order.time})' : 'Quanto tempo a mais?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [15, 30, 45, 60])
                BikoChip(label: '+$m min', selected: _minutes == m, onTap: () => setState(() => _minutes = m)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a == OrderAction.atrasar
                ? 'O cliente vê o aviso com o motivo e o novo horário, e pode cancelar sem custo.'
                : 'Os próximos clientes afetados são remarcados automaticamente.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
        ],
        FieldLabel(_timed ? 'O que aconteceu? (ex.: acabou a energia)' : widget.optional ? 'Motivo (opcional)' : 'Motivo'),
        TextField(
          controller: _text,
          maxLines: 2,
          maxLength: 200,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(errorText: _error, counterText: ''),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 18),
        ButtonPair(
          left: BikoButton(label: 'Voltar', style: BikoButtonStyle.light, onPressed: () => Navigator.pop(context)),
          right: BikoButton(
            label: 'Confirmar',
            style: _timed ? BikoButtonStyle.primary : BikoButtonStyle.danger,
            onPressed: _ok,
          ),
        ),
      ],
    );
  }
}

/// Selo do status do pedido no visual do Figma.
class OrderStatusTag extends StatelessWidget {
  const OrderStatusTag(this.order, {super.key, this.clientView = false});

  final OrderModel order;

  /// Para o cliente, pendente aparece como "Aguardando o profissional".
  final bool clientView;

  @override
  Widget build(BuildContext context) {
    if (order.inProgress) return const Tag('Em andamento');
    return switch (order.status) {
      OrderStatus.pendente => Tag(clientView ? 'Aguardando o profissional' : 'Pendente', tone: TagTone.orange),
      OrderStatus.confirmado => const Tag('Confirmado', tone: TagTone.green),
      OrderStatus.concluido => const Tag('Concluído'),
      OrderStatus.recusado => const Tag('Recusado', tone: TagTone.red),
      OrderStatus.cancelado => const Tag('Cancelado', tone: TagTone.red),
    };
  }
}
