import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
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
    final ok = await vm.run(action, reason: reason);
    if (!mounted) return;
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text(action.doneMessage)));
    } else {
      final fieldError = vm.fieldError('reason');
      if (fieldError != null && _pending != null) {
        setState(() => _reasonError = fieldError);
      } else if (vm.errorMessage case final msg?) {
        showAppSnackBar(context, msg, error: true);
      }
    }
  }

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
        SheetHeader(title: order.serviceTitle, trailing: StatusBadge(status: order.status)),
        InfoRow(
          label: 'Quando',
          value: '${Fmt.dateBR(order.date)} · ${order.time}–${order.endTime}',
          extra: Fmt.duration(order.durationMin),
        ),
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
              labelText: vm.reasonRequired(action, userId) ? 'Motivo' : 'Motivo (opcional)',
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
                      TextSpan(text: event.status.label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
