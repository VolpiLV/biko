import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../viewmodels/chat_view_models.dart';

/// Aba "Conversas" (tela "Usua 7"): uma linha por pessoa, com a última mensagem.
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ChatsViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatsViewModel>();
    final role = context.select<SessionViewModel, UserRole?>((s) => s.user?.role);
    final c = context.bikoColors;
    final empty = role == UserRole.cliente
        ? 'Nenhuma conversa ainda.\nNa busca, toque em Conversar para falar com um profissional.'
        : 'Nenhuma conversa ainda.\nQuando um cliente mandar mensagem, ela aparece aqui.';
    return BikoPage(
      onRefresh: vm.load,
      children: [
        const PageTitle('Conversas', trailing: NotificationBell()),
        if (vm.loading && !vm.loaded)
          const SizedBox(height: 260, child: LoadingView())
        else if (vm.error case final msg? when !vm.loaded)
          SizedBox(height: 300, child: ErrorView(message: msg, onRetry: vm.load))
        else if (vm.items.isEmpty)
          EmptyText(empty)
        else
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Column(children: [for (final conv in vm.items) _ConversationRow(conv)]),
          ),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow(this.conv);

  final Conversation conv;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final p = conv.person;
    final day = Fmt.dayOf(conv.lastAt);
    return Material(
      color: c.card,
      child: InkWell(
        onTap: () async {
          await openChat(context, p.id);
          if (context.mounted) await context.read<ChatsViewModel>().load(quiet: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              BikoAvatar(name: p.name, photoUrl: p.photoUrl, size: 54, onlineDot: p.isProvider && p.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TextStyle(color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      '${conv.lastMine ? 'Você: ' : ''}${conv.lastText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(day == 'Hoje' ? Fmt.time(conv.lastAt) : day, style: TextStyle(color: c.muted, fontSize: 11.5)),
                  if (conv.unread > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(10)),
                      child: Text('${conv.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
