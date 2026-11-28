import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/views/account_tab.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../../home/viewmodels/dashboard_view_model.dart';
import '../../home/viewmodels/home_navigation.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../search/viewmodels/search_view_model.dart';

/// Início do cliente (tela "Usua 2"): busca, "Serviço rápido", avisos e categorias.
class ClientHomeTab extends StatefulWidget {
  const ClientHomeTab({super.key});

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  final _query = TextEditingController();
  String _chip = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DashboardViewModel>().load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search({String query = '', String category = ''}) {
    context.read<SearchViewModel>().startWith(query: query, category: category);
    context.read<HomeNavigation>().goTo(AppTab.search);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final user = context.select<SessionViewModel, UserModel?>((s) => s.user);
    final c = context.bikoColors;
    if (user == null) return const SizedBox.shrink();
    final desc = {for (final cat in vm.categories) cat.name: cat.description};
    final list = CategoryStyle.all.where((s) => _chip.isEmpty || s.name == _chip);

    return BikoPage(
      onRefresh: vm.load,
      children: [
        _Hero(user: user, controller: _query, onSearch: (q) => _search(query: q)),
        _Promo(onTap: () => _search(category: 'Telhado & Reparador')),
        if (vm.notices.isNotEmpty) ...[
          const SectionHeader('Avisos'),
          for (final o in vm.notices)
            NoticeBox(
              leading: const Text('⏰'),
              onTap: () => openOrder(context, o.id),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${o.provider.name} avisou um atraso', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' em "${o.serviceTitle}": era ${o.originalTime ?? '--'} e agora é '),
                    TextSpan(text: o.time, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' (${Fmt.dayLabel(o.date)}).\nMotivo: ${o.delayReason ?? '—'}.'),
                  ],
                ),
              ),
            ),
        ],
        SectionHeader('Categorias Populares', action: 'Ver todas', onAction: () => _search()),
        ChipRow(
          children: [
            BikoChip(label: 'Todos', selected: _chip.isEmpty, onTap: () => setState(() => _chip = '')),
            for (final s in CategoryStyle.all.take(5))
              BikoChip(label: s.chip, selected: _chip == s.name, onTap: () => setState(() => _chip = s.name)),
          ],
        ),
        const SizedBox(height: 14),
        if (vm.loading && vm.categories.isEmpty)
          const SizedBox(height: 120, child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.categories.isEmpty)
          ErrorView(message: msg, onRetry: vm.load),
        for (final s in list)
          BikoCard(
            onTap: () => _search(category: s.name),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? c.neutralSoft : s.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: TextStyle(color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                      if (desc[s.name] case final d?) Text(d, style: TextStyle(color: c.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: c.neutralSoft, shape: BoxShape.circle),
                  child: Icon(Icons.chevron_right, color: c.muted, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.user, required this.controller, required this.onSearch});

  final UserModel user;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, MediaQuery.paddingOf(context).top + 22, AppSpacing.page, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A84FF), Color(0xFF0A7AF0)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Minha conta',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => pushScreen<void>(context, const AccountScreen()),
                  child: user.photoUrl != null
                      ? BikoAvatar(name: user.name, photoUrl: user.photoUrl, size: 42, square: true)
                      : const BikoLogoMark(size: 42, shadow: false, bordered: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Olá, ${user.firstName} 👋', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      'O que precisa arrumar hoje?',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const NotificationBell(onLight: false),
            ],
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: TextField(
              controller: controller,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
              style: TextStyle(color: c.text),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Busque ex: Arrumar telha, encanador...',
                fillColor: c.card,
                prefixIcon: Icon(Icons.search, color: c.blue),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promo extends StatelessWidget {
  const _Promo({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(AppSpacing.page, 22, AppSpacing.page, 0),
        padding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFA31A), Color(0xFFFF8A00)]),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Transform.rotate(
                angle: -0.35,
                child: Icon(Icons.handyman, size: 74, color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x4D783C00), borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'SERVIÇO RÁPIDO',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Goteiras ou Telhas Quebradas?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const SizedBox(
                  width: 230,
                  child: Text(
                    'Profissionais qualificados com atendimento hoje.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
                const SizedBox(height: 14),
                BikoButton(label: 'Encontrar Mão de Obra', style: BikoButtonStyle.white, small: true, expand: false, onPressed: onTap),
              ],
            ),
          ],
        ),
      );
}
