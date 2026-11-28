import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../viewmodels/notifications_view_model.dart';
import '../views/notifications_sheet.dart';

/// Sino redondo com o número de não lidas (`.bell`). [onLight]: branco com borda,
/// para fundos claros; senão translúcido, para o topo azul.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.onLight = true});

  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsViewModel, int>((vm) => vm.unread);
    final c = context.bikoColors;
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notificações ($unread não lidas)' : 'Notificações',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: onLight ? c.card : Colors.white.withValues(alpha: 0.2),
              shape: CircleBorder(side: onLight ? BorderSide(color: c.line) : BorderSide.none),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showNotificationsSheet(context),
                child: Center(child: Icon(Icons.notifications_none_rounded, color: onLight ? c.text : Colors.white, size: 23)),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.brandOrange, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
