import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/notifications/system_notifications.dart';
import '../../../data/remote/notification_service.dart';
import '../../home/app_navigator.dart';
import '../../home/viewmodels/dashboard_view_model.dart';
import '../../provider/viewmodels/provider_view_models.dart';
import '../viewmodels/notifications_view_model.dart';
import '../views/notifications_sheet.dart';

/// Liga os pop-ups do celular à área logada:
/// - pede a permissão de notificações (Android 13+) na primeira vez;
/// - manda o token do aparelho para o servidor (push com o app fechado, se o Firebase estiver ligado);
/// - tocar num pop-up abre o pedido (ou o sino) e marca a notificação como lida;
/// - push chegando com o app aberto atualiza o número do sino na hora.
class NotificationPopups extends StatefulWidget {
  const NotificationPopups({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationPopups> createState() => _NotificationPopupsState();
}

class _NotificationPopupsState extends State<NotificationPopups> {
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    final push = context.read<PushNotifications>();
    final vm = context.read<NotificationsViewModel>();
    final service = context.read<NotificationService>();

    _subs
      ..add(push.taps.listen(_open))
      ..add(push.received.listen((_) => vm.refreshCount()))
      // Pedido novo/mudou: a Início e a agenda mostram na hora, sem puxar para atualizar.
      ..add(vm.arrivals.listen((_) => _reloadScreens()))
      ..add(push.onTokenRefresh.listen((t) => _register(service, t)));
    if (push.takePendingTap() case final tap?) _open(tap);

    await push.requestPermission();
    if (await push.deviceToken() case final token?) await _register(service, token);
  }

  Future<void> _register(NotificationService service, String token) async {
    try {
      await service.registerDevice(token);
    } on AppException {
      // servidor/microsserviço fora do ar: tenta de novo na próxima abertura do app
    }
  }

  void _reloadScreens() {
    if (!mounted) return;
    unawaited(context.read<DashboardViewModel>().load());
    unawaited(context.read<OrdersAgendaViewModel>().load());
  }

  void _open(NotificationTap tap) {
    if (!mounted) return;
    final vm = context.read<NotificationsViewModel>();
    if (tap.notificationId case final id?) unawaited(vm.markReadById(id));
    // Fecha o que estiver aberto por cima e mostra o pedido a partir das abas.
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (tap.orderId case final orderId?) {
      unawaited(openOrder(context, orderId));
    } else {
      unawaited(showNotificationsSheet(context));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
