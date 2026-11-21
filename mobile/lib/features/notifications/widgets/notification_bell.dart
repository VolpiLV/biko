import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../viewmodels/notifications_view_model.dart';
import '../views/notifications_sheet.dart';

/// Sino da barra superior com o número de notificações não lidas.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsViewModel, int>((vm) => vm.unread);
    return IconButton(
      tooltip: unread > 0 ? 'Notificações ($unread não lidas)' : 'Notificações',
      onPressed: () => showNotificationsSheet(context),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.brandOrange,
        textColor: Colors.white,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_outlined),
      ),
    );
  }
}
