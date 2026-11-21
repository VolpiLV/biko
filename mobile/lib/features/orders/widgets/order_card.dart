import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../payments/widgets/payment_widgets.dart';

/// Cartão de pedido na lista. Mostra "a outra pessoa" conforme o perfil.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.viewerRole, required this.onTap});

  final OrderModel order;
  final UserRole viewerRole;
  final VoidCallback onTap;

  String get _counterpart => switch (viewerRole) {
        UserRole.cliente => 'Prestador: ${order.provider.name}',
        UserRole.prestador => 'Cliente: ${order.client.name}',
        UserRole.admin => '${order.client.name} → ${order.provider.name}',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.serviceTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_counterpart, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${Fmt.dateBR(order.date)} · ${order.time}–${order.endTime}'
                            '${order.delayMin > 0 ? ' (atraso +${order.delayMin} min)' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (order.inProgress)
                    Pill(
                      label: 'Em andamento',
                      background: context.bikoColors.highlight,
                      foreground: context.bikoColors.onHighlight,
                    )
                  else
                    StatusBadge(status: order.status),
                  const SizedBox(height: AppSpacing.sm),
                  Text(Fmt.brl(order.price), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (order.payment case final p? when p.status != PaymentStatus.recusado) ...[
                    const SizedBox(height: AppSpacing.xs),
                    PaymentPill(status: p.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
