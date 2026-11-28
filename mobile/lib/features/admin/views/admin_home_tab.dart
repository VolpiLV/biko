import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/viewmodels/dashboard_view_model.dart';
import '../../notifications/widgets/notification_bell.dart';

/// Início do admin (não existe no Figma: usa o mesmo visual).
class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DashboardViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final user = context.select<SessionViewModel, UserModel?>((s) => s.user);
    final c = context.bikoColors;
    if (user == null) return const SizedBox.shrink();
    final s = vm.summary;

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink)),
                Text(label, style: TextStyle(color: c.muted, fontSize: 11)),
              ],
            ),
          ),
        );
    Widget row(List<Widget> items) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 10), items[i]]]),
        );

    return BikoPage(
      onRefresh: vm.load,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, MediaQuery.paddingOf(context).top + 22, AppSpacing.page, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A84FF), Color(0xFF0A7AF0)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(
            children: [
              BikoAvatar(name: user.name, photoUrl: user.photoUrl, onHero: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Olá, ${user.firstName} 👋', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const Text('Painel administrativo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const NotificationBell(onLight: false),
            ],
          ),
        ),
        if (s == null)
          vm.loading
              ? const SizedBox(height: 200, child: LoadingView())
              : SizedBox(height: 240, child: ErrorView(message: vm.errorMessage ?? 'Não foi possível carregar.', onRetry: vm.load))
        else ...[
          row([stat('${s.clients}', 'Clientes'), stat('${s.providers}', 'Prestadores'), stat('${s.disabled}', 'Desativados')]),
          row([stat('${s.orders}', 'Pedidos'), stat('${s.pending}', 'Pendentes'), stat('${s.completed}', 'Concluídos')]),
          const EmptyText(
            'Use a aba Usuários para gerenciar contas, Pedidos para acompanhar os agendamentos e Vendas para ver os pagamentos.',
          ),
        ],
      ],
    );
  }
}
