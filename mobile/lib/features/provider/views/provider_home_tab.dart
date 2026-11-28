import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/remote/provider_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../../home/viewmodels/dashboard_view_model.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../orders/order_actions.dart';
import 'provider_orders_screen.dart';
import 'service_progress_screen.dart';

/// Início do prestador (tela "Prest 3"): Online/Offline, ganhos da semana e solicitações.
class ProviderHomeTab extends StatefulWidget {
  const ProviderHomeTab({super.key});

  @override
  State<ProviderHomeTab> createState() => _ProviderHomeTabState();
}

class _ProviderHomeTabState extends State<ProviderHomeTab> {
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DashboardViewModel>().load());
  }

  Future<void> _toggleOnline(UserModel user) async {
    if (_switching) return;
    setState(() => _switching = true);
    final session = context.read<SessionViewModel>();
    try {
      final r = await context.read<ProviderService>().update(online: !user.online);
      session.updateUser(r.user);
      if (mounted) {
        showAppSnackBar(context, r.user.online ? 'Você está online.' : 'Você está offline: não aparece na busca.');
      }
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final user = context.select<SessionViewModel, UserModel?>((s) => s.user);
    final c = context.bikoColors;
    if (user == null) return const SizedBox.shrink();
    final panel = vm.panel;

    return BikoPage(
      onRefresh: vm.load,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, MediaQuery.paddingOf(context).top + 22, AppSpacing.page, 6),
          child: Row(
            children: [
              BikoAvatar(name: user.name, photoUrl: user.photoUrl, size: 52, ring: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bem-vindo,', style: TextStyle(color: c.muted, fontSize: 13)),
                    Text(
                      '${user.name} 👋',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.ink, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              _OnlinePill(online: user.online, busy: _switching, onTap: () => _toggleOnline(user)),
              const SizedBox(width: 8),
              const NotificationBell(),
            ],
          ),
        ),
        if (panel == null)
          vm.loading
              ? const SizedBox(height: 300, child: LoadingView())
              : SizedBox(height: 300, child: ErrorView(message: vm.errorMessage ?? 'Não foi possível carregar.', onRetry: vm.load))
        else ...[
          _EarningsCard(week: panel.weekEarnings, services: panel.weekServices, rating: panel.rating),
          if (user.online)
            NoticeBox(
              leading: Icon(Icons.bolt, color: c.orangeText, size: 20),
              child: const Text.rich(TextSpan(children: [
                TextSpan(text: 'Modo Rápido Ativo:', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' Recebendo chamados de clientes próximos a você.'),
              ])),
            )
          else
            const NoticeBox(
              tone: NoticeTone.off,
              leading: Text('⏸'),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Você está offline:', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' seus serviços não aparecem na busca dos clientes.'),
              ])),
            ),
          SectionHeader(
            'Solicitações Próximas (${panel.pending.length})',
            action: 'Ver todas',
            onAction: () => pushScreen<void>(context, const ProviderOrdersScreen()),
          ),
          if (panel.pending.isEmpty)
            const EmptyText('Nenhuma solicitação nova agora.')
          else
            for (final o in panel.pending.take(5)) RequestCard(order: o, onChanged: vm.load),
          if (panel.upcoming.isNotEmpty) ...[
            const SectionHeader('Próximos atendimentos'),
            for (final o in panel.upcoming) RequestCard(order: o, onChanged: vm.load),
          ],
        ],
      ],
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.online, required this.busy, required this.onTap});

  final bool online;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      toggled: online,
      label: online ? 'Online. Toque para ficar offline' : 'Offline. Toque para ficar online',
      excludeSemantics: true,
      child: Material(
        color: online ? (dark ? c.blueSoft : const Color(0xFFE3F2FF)) : c.neutralSoft,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: online ? AppColors.online : c.muted2, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: online ? (dark ? c.blue : const Color(0xFF0B4A8F)) : c.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.week, required this.services, required this.rating});

  final double week;
  final int services;
  final double? rating;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A84FF), Color(0xFF0057D9)]),
          boxShadow: [BoxShadow(color: const Color(0xFF0A64E6).withValues(alpha: 0.28), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ganhos desta semana', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5)),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(Fmt.brl(week), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 17),
                    const SizedBox(width: 6),
                    Expanded(child: Text('$services Serviço${services == 1 ? '' : 's'} feito${services == 1 ? '' : 's'}')),
                    Text('⭐ ${rating == null ? '—' : Fmt.rating(rating!)} Avaliação'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// Cartão de solicitação (`.req`): selo de quando, preço, serviço, cliente e as ações rápidas.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.order, required this.onChanged});

  final OrderModel order;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = order;
    final today = Fmt.dayLabel(o.date) == 'Hoje';
    final day = Fmt.dayLabel(o.date).toUpperCase();
    final badge = o.status == OrderStatus.pendente
        ? Tag(today ? 'CHEGADA HOJE ${o.time}' : 'NOVO · $day ${o.time}', tone: TagTone.orange)
        : Tag('AGENDADO ($day ${o.time})');

    Future<void> act(OrderAction a) async {
      if (await runOrderAction(context, o, a) != null) await onChanged();
    }

    return BikoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(child: badge),
              const Spacer(),
              Text(Fmt.brl(o.price), style: TextStyle(color: c.blue, fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await openOrder(context, o.id);
              await onChanged();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.serviceTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: c.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${o.client.name} • ${o.address}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (o.status == OrderStatus.pendente)
            ButtonPair(
              left: BikoButton(label: 'Recusar', style: BikoButtonStyle.outline, onPressed: () => act(OrderAction.recusar)),
              right: BikoButton(label: 'Aceitar', onPressed: () => act(OrderAction.confirmar)),
            )
          else
            ButtonPair(
              left: BikoButton(
                label: 'Chat',
                icon: Icons.chat_bubble_outline,
                style: BikoButtonStyle.light,
                onPressed: () => openChat(context, o.client.id),
              ),
              right: BikoButton(
                label: 'Atendimento',
                onPressed: () async {
                  await pushScreen<void>(context, ServiceProgressScreen(orderId: o.id));
                  await onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}
