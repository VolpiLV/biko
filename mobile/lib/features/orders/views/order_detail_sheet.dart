import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../viewmodels/orders_view_model.dart';

/// Abre o detalhe do pedido. Retorna true se o status mudou (a lista recarrega).
Future<bool> showOrderDetail(BuildContext context, int orderId) async {
  final service = context.read<OrderService>();
  final changed = await showAppSheet<bool>(
    context,
    (_) => ChangeNotifierProvider(
      create: (_) => OrderDetailViewModel(service, orderId)..load(),
      child: const _OrderDetail(),
    ),
  );
  return changed ?? false;
}

class _OrderDetail extends StatefulWidget {
  const _OrderDetail();

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  final _reason = TextEditingController();

  /// Ação esperando o motivo (recusar/cancelar). null = mostrando os botões.
  OrderAction? _pending;
  String? _reasonError;

  /// Minutos escolhidos em "Preciso de mais tempo" ou "Avisar atraso".
  int _extraMin = 15;
  static const _extraSteps = [15, 30, 45, 60];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send(OrderAction action) async {
    final vm = context.read<OrderDetailViewModel>();
    final userId = context.read<SessionViewModel>().user?.id ?? 0;
    if (vm.asksReason(action) && _pending == null) {
      setState(() {
        _pending = action;
        _reasonError = null;
      });
      return;
    }
    final reason = _reason.text.trim();
    if (_pending != null && vm.reasonRequired(action, userId) && reason.length < 3) {
      setState(() => _reasonError = 'Informe o motivo (mín. 3 caracteres).');
      return;
    }
    final ok = await vm.run(
      action,
      reason: reason,
      minutes: _isTimed(action) ? _extraMin : null,
    );
    if (!mounted) return;
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text(action.doneMessage)));
    } else {
      final fieldError = vm.fieldError('reason') ?? vm.fieldError('minutes');
      if (fieldError != null && _pending != null) {
        setState(() => _reasonError = fieldError);
      } else if (vm.errorMessage case final msg?) {
        showAppSnackBar(context, msg, error: true);
      }
    }
  }

  static bool _isTimed(OrderAction a) => a == OrderAction.estender || a == OrderAction.atrasar;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderDetailViewModel>();
    final order = vm.order;
    if (vm.loadingOrder) {
      return const SizedBox(height: 240, child: LoadingView(message: 'Carregando pedido...'));
    }
    if (order == null) {
      return SizedBox(
        height: 280,
        child: ErrorView(message: vm.loadError ?? 'Pedido não encontrado.', onRetry: vm.load),
      );
    }
    final theme = Theme.of(context);
    final userId = context.read<SessionViewModel>().user?.id ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: order.serviceTitle,
          trailing: order.inProgress
              ? Pill(
                  label: 'Em andamento',
                  background: context.bikoColors.highlight,
                  foreground: context.bikoColors.onHighlight,
                )
              : StatusBadge(status: order.status),
        ),
        InfoRow(
          label: 'Quando',
          value: '${Fmt.dateBR(order.date)} · ${order.time}–${order.endTime}',
          extra: Fmt.duration(order.durationMin),
        ),
        if (order.delayMin > 0)
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Aviso de atraso: o horário era ${order.originalTime ?? '--'} e agora é ${order.time} '
              '(+${order.delayMin} min).\nMotivo: ${order.delayReason ?? 'imprevisto'}.'
              '${order.status == OrderStatus.confirmado || order.status == OrderStatus.pendente ? ' O cliente pode cancelar sem custo.' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        if (order.startedTime case final started?)
          InfoRow(
            label: 'Início real',
            value: started,
            extra: order.extendedMin > 0
                ? 'Previsto até ${order.plannedEndTime}, prorrogado +${Fmt.duration(order.extendedMin)}'
                : null,
          ),
        if (order.realDurationMin case final real?) InfoRow(label: 'Tempo real', value: Fmt.duration(real)),
        InfoRow(label: 'Valor', value: Fmt.brl(order.price)),
        InfoRow(label: 'Endereço', value: order.address),
        if (order.notes case final notes? when notes.isNotEmpty) InfoRow(label: 'Observações', value: notes),
        InfoRow(label: 'Cliente', value: order.client.name, extra: order.client.phone),
        InfoRow(label: 'Prestador', value: order.provider.name, extra: order.provider.phone),
        if (order.statusReason case final reason? when reason.isNotEmpty) InfoRow(label: 'Motivo', value: reason),
        if (order.client.phone == null && order.status == OrderStatus.pendente)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Os telefones aparecem depois que o pedido for confirmado.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Histórico', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        for (final event in order.history) _HistoryItem(event: event),
        const SizedBox(height: AppSpacing.md),
        if (_pending case final action?) ...[
          if (_isTimed(action)) ...[
            Text(
              action == OrderAction.atrasar
                  ? 'Quanto vai atrasar? (hoje o horário é ${order.time})'
                  : 'Quanto tempo a mais?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in _extraSteps)
                  ChoiceChip(
                    label: Text('+$m min'),
                    selected: _extraMin == m,
                    onSelected: vm.loading ? null : (_) => setState(() => _extraMin = m),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                action == OrderAction.atrasar
                    ? 'O cliente vê o aviso com o motivo e o novo horário, e pode cancelar sem custo. '
                        'Os próximos clientes afetados também são remarcados.'
                    : 'Os próximos clientes afetados são remarcados automaticamente e podem cancelar sem custo.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          TextField(
            controller: _reason,
            maxLength: 200,
            maxLines: 2,
            autofocus: true,
            enabled: !vm.loading,
            onChanged: (_) {
              if (_reasonError != null) setState(() => _reasonError = null);
            },
            decoration: InputDecoration(
              labelText: _isTimed(action)
                  ? 'O que aconteceu? (ex.: acabou a energia, equipamento quebrado)'
                  : vm.reasonRequired(action, userId)
                      ? 'Motivo'
                      : 'Motivo (opcional)',
              errorText: _reasonError,
            ),
          ),
          FormActions(
            cancelLabel: 'Voltar',
            submitLabel: 'Confirmar',
            loading: vm.loading,
            onSubmit: () => _send(action),
          ),
        ] else ...[
          for (final action in order.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: action.destructive
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      onPressed: vm.loading ? null : () => _send(action),
                      child: Text(action.label),
                    )
                  : AppButton(label: action.label, loading: vm.loading, onPressed: () => _send(action)),
            ),
          AppButton(
            label: 'Fechar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.event});

  final OrderEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final who = event.actorName ?? 'Sistema';
    final note = event.note;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
            child: Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: event.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '  ${Fmt.dateTime(event.createdAt)}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  note == null || note.isEmpty ? who : '$who — $note',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
