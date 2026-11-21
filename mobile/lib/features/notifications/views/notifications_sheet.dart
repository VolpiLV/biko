import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/notification_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/viewmodels/orders_view_model.dart';
import '../../orders/views/order_detail_sheet.dart';
import '../viewmodels/notifications_view_model.dart';

/// Abre o histórico de notificações. Tocar numa notificação abre o pedido dela.
Future<void> showNotificationsSheet(BuildContext context) async {
  final vm = context.read<NotificationsViewModel>();
  final orders = context.read<OrdersViewModel>();
  unawaited(vm.load());
  final orderId = await showAppSheet<int>(
    context,
    (_) => ChangeNotifierProvider.value(value: vm, child: const _NotificationsList()),
  );
  if (orderId == null || !context.mounted) return;
  final changed = await showOrderDetail(context, orderId);
  if (changed) {
    await orders.refresh();
    await vm.refreshCount();
  }
}

/// Ícone de cada ação (o título já é o nome da ação).
IconData notificationIcon(String action) => switch (action) {
      'pendente' => Icons.fiber_new_outlined,
      'confirmado' => Icons.check_circle_outline,
      'recusado' => Icons.block,
      'cancelado' => Icons.cancel_outlined,
      'concluido' => Icons.flag_outlined,
      'atrasado' => Icons.alarm,
      'iniciado' => Icons.play_circle_outline,
      'prorrogado' => Icons.more_time,
      'remarcado' => Icons.event_repeat,
      'pago' => Icons.payments_outlined,
      'estornado' => Icons.undo,
      _ => Icons.notifications_outlined,
    };

class _NotificationsList extends StatelessWidget {
  const _NotificationsList();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: 'Notificações',
          trailing: vm.unread > 0
              ? TextButton(onPressed: vm.markAllRead, child: const Text('Marcar todas como lidas'))
              : null,
        ),
        if (vm.loading && vm.items.isEmpty)
          const SizedBox(height: 200, child: LoadingView())
        else if (vm.error case final msg? when vm.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ErrorBanner(message: msg),
          )
        else if (vm.items.isEmpty)
          const EmptyView(icon: Icons.notifications_none, message: 'Nenhuma notificação por enquanto.')
        else ...[
          if (vm.error case final msg?)
            Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: ErrorBanner(message: msg)),
          for (final n in vm.items)
            _NotificationTile(
              notification: n,
              onTap: () {
                vm.markRead(n);
                if (n.orderId case final id?) Navigator.of(context).pop(id);
              },
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Fechar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !notification.read;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: unread ? scheme.primaryContainer.withValues(alpha: 0.55) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md - 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(notificationIcon(notification.action), color: scheme.primary),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Nome da ação em destaque (sem data, como no site)
                        Flexible(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          const DecoratedBox(
                            decoration: BoxDecoration(color: AppColors.brandOrange, shape: BoxShape.circle),
                            child: SizedBox.square(dimension: 8),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(notification.message, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
